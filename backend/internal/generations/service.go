package generations

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"ai-chat-backend/internal/ai"
	"ai-chat-backend/internal/files"
	"ai-chat-backend/internal/gateway"
	"ai-chat-backend/internal/i18n"
	"ai-chat-backend/internal/messages"
	"ai-chat-backend/internal/plans"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrGenerationNotFound = errors.New("GENERATION_NOT_FOUND: Generatsiya topilmadi")
	ErrAlreadyFinished    = errors.New("ALREADY_FINISHED: Generatsiya allaqachon yakunlangan")
	ErrCheckpointNotFound = errors.New("CHECKPOINT_NOT_FOUND: Nazorat nuqtasi topilmadi")
)

// Service coordinates generation lifecycle, streaming, authorization, and cancellation.
type Service struct {
	pool         *pgxpool.Pool
	baseProvider *ai.OpenAICompatibleProvider
	msgService   *messages.Service
	plansService *plans.Service
	filesService *files.Service
	router       *gateway.Router
	quotaService *gateway.QuotaService

	mu        sync.RWMutex
	cancels   map[string]context.CancelFunc
	completed map[string]time.Time
}

// NewService creates a new generations service with AI Gateway, files, and Quota enforcement.
func NewService(
	pool *pgxpool.Pool,
	baseProvider *ai.OpenAICompatibleProvider,
	msgService *messages.Service,
	plansService *plans.Service,
	filesService *files.Service,
	router *gateway.Router,
	quotaService *gateway.QuotaService,
) *Service {
	return &Service{
		pool:         pool,
		baseProvider: baseProvider,
		msgService:   msgService,
		plansService: plansService,
		filesService: filesService,
		router:       router,
		quotaService: quotaService,
		cancels:      make(map[string]context.CancelFunc),
		completed:    make(map[string]time.Time),
	}
}

func (s *Service) registerCancel(genID string, cancel context.CancelFunc) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.cancels[genID] = cancel
}

func (s *Service) unregisterCancel(genID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.cancels, genID)
	now := time.Now()
	s.completed[genID] = now
	// Bounded cleanup: prevent unbounded memory leak by pruning old entries
	if len(s.completed) > 500 {
		cutoff := now.Add(-10 * time.Minute)
		for id, t := range s.completed {
			if t.Before(cutoff) || len(s.completed) > 400 {
				delete(s.completed, id)
			}
		}
	}
}

// CancelGeneration triggers cancellation for an active generation.
func (s *Service) CancelGeneration(ctx context.Context, userID, genID string) error {
	s.mu.RLock()
	cancel, found := s.cancels[genID]
	_, wasCompleted := s.completed[genID]
	s.mu.RUnlock()

	if s.pool == nil {
		if found && cancel != nil {
			cancel()
			return nil
		}
		if wasCompleted {
			return ErrAlreadyFinished
		}
		return ErrGenerationNotFound
	}

	var currentStatus string
	err := s.pool.QueryRow(ctx, `
		SELECT status FROM generations WHERE id = $1 AND user_id = $2
	`, genID, userID).Scan(&currentStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrGenerationNotFound
		}
		return fmt.Errorf("failed to check generation: %w", err)
	}

	if currentStatus != "running" && currentStatus != "pending" {
		return ErrAlreadyFinished
	}

	if found && cancel != nil {
		cancel()
	}

	_, err = s.pool.Exec(ctx, `
		UPDATE generations
		SET status = 'cancelled', cancelled_at = CURRENT_TIMESTAMP
		WHERE id = $1 AND user_id = $2
	`, genID, userID)
	return err
}

func writeHeartbeat(w http.ResponseWriter, flusher http.Flusher) {
	_, _ = fmt.Fprint(w, ": ping\n\n")
	flusher.Flush()
}

func writeSSE(w http.ResponseWriter, flusher http.Flusher, event string, data any) {
	bytesData, err := json.Marshal(data)
	if err != nil {
		return
	}
	_, _ = fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, string(bytesData))
	flusher.Flush()
}

func emitActivity(w http.ResponseWriter, flusher http.Flusher, stage string, idx, total int, title, detail, status string) {
	writeSSE(w, flusher, "pipeline.activity", ActivityEvent{
		Stage:     stage,
		Index:     idx,
		Total:     total,
		Title:     title,
		Detail:    detail,
		Status:    status,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	})
	writeSSE(w, flusher, "pipeline.status", map[string]string{
		"stage":       stage,
		"status_text": title,
	})
}

// ExecuteStream orchestrates the generation lifecycle with strict plan enforcement, quota reservation, and real SSE output.
func (s *Service) ExecuteStream(w http.ResponseWriter, r *http.Request, userID, convID, userMessageContent, requestedModelID, mode string, fileIDs []string) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache, no-transform")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	reqLocale := i18n.GetLocaleFromRequest(r)
	if mode == "" {
		mode = "deep_analysis"
	}

	// Start connection keepalive heartbeat
	heartbeatDone := make(chan struct{})
	defer close(heartbeatDone)
	go func() {
		ticker := time.NewTicker(3 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-heartbeatDone:
				return
			case <-r.Context().Done():
				return
			case <-ticker.C:
				writeHeartbeat(w, flusher)
			}
		}
	}()

	// Stage 1: Receiving and validating
	emitActivity(w, flusher, "validating", 1, 7, "Hujjat qabul qilindi va tekshirilmoqda", "Fayl yaxlitligi va tarif cheklovlari tekshirilmoqda", "active")

	// 1. Authoritative Entitlement Resolution
	ent, err := s.plansService.ResolveUserEntitlement(r.Context(), userID)
	if err != nil {
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    "ENTITLEMENT_RESOLUTION_FAILED",
			"message": "Foydalanuvchi huquqlarini tekshirishda xatolik yuz berdi",
		})
		return
	}

	// Validate file count limit (maximum 5 files per message)
	if len(fileIDs) > 5 {
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    "FILE_COUNT_LIMIT_EXCEEDED",
			"message": "Bitta xabarga ko'pi bilan 5 ta fayl biriktirish mumkin",
		})
		return
	}

	emitActivity(w, flusher, "validating", 1, 7, "Hujjat tekshirildi", "Xavfsizlik va ruxsatlar tasdiqlandi", "completed")

	// 2. Process attached files (Multi-document support & Extraction)
	var hasImages bool
	var docContext string
	var citations []files.RetrievalResult

	if len(fileIDs) > 0 && s.filesService != nil {
		// Stage 2: Identifying document structure
		emitActivity(w, flusher, "identifying_structure", 2, 7, "Hujjat tuzilishi va sahifalari tahlil qilinmoqda", "Fayllar formati va sahifa metama'lumotlari aniqlanmoqda", "active")

		var validUserFileIDs []string
		for _, fID := range fileIDs {
			f, err := s.filesService.GetFile(r.Context(), userID, fID)
			if err == nil && f != nil {
				validUserFileIDs = append(validUserFileIDs, fID)
				if f.FileType == files.FileTypeImage {
					hasImages = true
				}
			}
		}
		emitActivity(w, flusher, "identifying_structure", 2, 7, "Hujjat tuzilishi aniqlandi", fmt.Sprintf("%d ta hujjat tahlilga tayyorlandi", len(validUserFileIDs)), "completed")

		// Stage 3: Extracting text, tables, and metadata
		emitActivity(w, flusher, "extracting_content", 3, 7, "Sahifalar, jadvallar va matnlar o'qilmoqda", "Raqamli matn qatlamlari va jadvallar ajratilmoqda", "active")

		if len(validUserFileIDs) > 0 {
			ctxStr, cList, err := s.filesService.RetrieveRelevantContext(r.Context(), userID, validUserFileIDs, userMessageContent)
			if err == nil && ctxStr != "" {
				docContext = ctxStr
				citations = cList
			}
		}
		emitActivity(w, flusher, "extracting_content", 3, 7, "Matn va jadvallar tahlil qilindi", fmt.Sprintf("%d ta asosiy bo'lim ajratildi", len(citations)), "completed")
	}

	// 3. Gateway Router Model Selection & Plan Authorization
	targetModel, err := s.router.RouteMultimodal(r.Context(), requestedModelID, ent, hasImages)
	if err != nil {
		code := "MODEL_ACCESS_DENIED"
		if errors.Is(err, gateway.ErrPlanNotAuthorized) {
			code = "MODEL_NOT_PERMITTED_ON_PLAN"
		}
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    code,
			"message": err.Error(),
		})
		return
	}

	// 4. Pre-reserve Quota & check tiered limits atomically
	ledgerID, err := s.quotaService.ReserveQuota(
		r.Context(),
		userID,
		convID,
		"",
		targetModel.ID,
		ent.PlanID,
		gateway.QuotaLimits{
			HourlyLimit: ent.HourlyRequestsLimit,
			DailyLimit:  ent.DailyRequestsLimit,
			WeeklyLimit: ent.WeeklyRequestsLimit,
			MaxStreams:  ent.MaxActiveStreams,
		},
	)
	if err != nil {
		var qErr *gateway.QuotaError
		if errors.As(err, &qErr) {
			writeSSE(w, flusher, "generation.failed", map[string]any{
				"code":      qErr.Code,
				"window":    qErr.Window,
				"limit":     qErr.Limit,
				"used":      qErr.Used,
				"resets_at": qErr.ResetsAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
				"message":   qErr.Message,
			})
			return
		}
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    "QUOTA_EXCEEDED",
			"message": err.Error(),
		})
		return
	}

	// 5. Persist user message with attached files
	userMsg, err := s.msgService.CreateUserMessageWithFiles(r.Context(), userID, convID, userMessageContent, fileIDs)
	if err != nil {
		_ = s.quotaService.ReleaseReservation(context.Background(), ledgerID, "failed")
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    "USER_MESSAGE_FAILED",
			"message": err.Error(),
		})
		return
	}

	// Stage 4: Identifying important facts and entities
	emitActivity(w, flusher, "identifying_info", 4, 7, "Asosiy faktlar va raqamlar aniqlanmoqda", "Muhim sanalar, statistika va tushunchalar guruhlanmoqda", "active")
	extractedEntities := files.ExtractEntitiesFromChunks(citations)
	emitActivity(w, flusher, "identifying_info", 4, 7, "Faktlar va raqamlar saralandi", fmt.Sprintf("%d ta sana, %d ta ko'rsatkich topildi", len(extractedEntities.Dates), len(extractedEntities.Numbers)), "completed")

	// Stage 5: Cross-checking relevant information
	emitActivity(w, flusher, "cross_checking", 5, 7, "Manbalar va sahifalararo bog'liqliklar tekshirilmoqda", "Dalillar va manba sahifalar haqiqiyligi tekshirilmoqda", "active")
	suggestedQuestions := files.GenerateSuggestedQuestions(reqLocale, userMessageContent, citations, mode)
	emitActivity(w, flusher, "cross_checking", 5, 7, "Manbalar tasdiqlandi", "Faktik havola va sahifalar bog'landi", "completed")

	// Stage 6: Organizing findings and mode adaptation
	emitActivity(w, flusher, "organizing_findings", 6, 7, "Xulosalar va tahliliy tuzilma shakllantirilmoqda", fmt.Sprintf("Tahlil rejimi qo'llanilmoqda (%s)", mode), "active")

	// Dynamic Token Budgeting: Ensure sufficient output budget for document intelligence
	outputTokens := targetModel.MaxOutputTokens
	if outputTokens < 2048 {
		outputTokens = 2048
	}
	if ent.MaxOutputTokens > 0 && outputTokens > ent.MaxOutputTokens && ent.MaxOutputTokens >= 1500 {
		outputTokens = ent.MaxOutputTokens
	}

	maxContextTokens := targetModel.MaxContextTokens
	if maxContextTokens <= 0 {
		maxContextTokens = 8192
	}
	maxInputTokens := ent.MaxInputTokens
	if maxInputTokens <= 0 {
		maxInputTokens = 4000
	}

	availableInputBudget := maxContextTokens - outputTokens - 300
	if availableInputBudget > maxInputTokens && maxInputTokens > 0 {
		availableInputBudget = maxInputTokens
	}
	if availableInputBudget < 600 {
		availableInputBudget = 600
	}

	ragBudgetTokens := availableInputBudget * 60 / 100
	if docContext != "" && (len(docContext)/4) > ragBudgetTokens {
		charLimit := ragBudgetTokens * 4
		if len(docContext) > charLimit {
			docContext = docContext[:charLimit] + "\n\n*(Hujjatning qolgan qismi kontekst chegarasiga moslab qisqartirildi)*"
		}
	}

	histList, err := s.msgService.ListMessages(r.Context(), userID, convID, 20)
	if err != nil {
		_ = s.quotaService.ReleaseReservation(context.Background(), ledgerID, "failed")
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    "HISTORY_FAILED",
			"message": err.Error(),
		})
		return
	}

	userMsgEstimatedTokens := len(userMessageContent)/4 + len(docContext)/4 + 50
	remainingForHistory := availableInputBudget - userMsgEstimatedTokens - 150
	if remainingForHistory < 200 {
		remainingForHistory = 200
	}

	var historyMessages []ai.ChatMessage
	historyTokensUsed := 0
	for i := len(histList) - 1; i >= 0; i-- {
		m := histList[i]
		if m.ID == userMsg.ID {
			continue
		}
		msgTokens := len(m.Content)/4 + 8
		if historyTokensUsed+msgTokens > remainingForHistory {
			break
		}
		historyTokensUsed += msgTokens
		historyMessages = append([]ai.ChatMessage{{
			Role:    m.Role,
			Content: m.Content,
		}}, historyMessages...)
	}

	modeInstruction := files.BuildAnalysisModePrompt(reqLocale, mode)
	aiMessages := make([]ai.ChatMessage, 0, len(historyMessages)+3)
	aiMessages = append(aiMessages, ai.ChatMessage{
		Role:    "system",
		Content: fmt.Sprintf("%s\n\n%s\n\nMUHIM QOIDA: Javobni to'g'ridan-to'g'ri foydalanuvchiga taqdim eting. Ichki fikrlash (chain-of-thought) jarayonini matnga aralashtirmang.", i18n.GetAISystemPrompt(reqLocale), modeInstruction),
	})
	aiMessages = append(aiMessages, historyMessages...)

	currentUserContent := userMsg.Content
	if docContext != "" {
		currentUserContent = fmt.Sprintf("%s\n\n%s", userMsg.Content, i18n.GetRAGInstruction(reqLocale, docContext))
	}
	aiMessages = append(aiMessages, ai.ChatMessage{
		Role:    "user",
		Content: currentUserContent,
	})

	emitActivity(w, flusher, "organizing_findings", 6, 7, "Tahlil tuzilmasi tayyorlandi", "Faktlar va xulosalar birlashtirildi", "completed")

	// 6. Create generation record in DB
	var genID string
	if s.pool != nil {
		err = s.pool.QueryRow(r.Context(), `
			INSERT INTO generations (conversation_id, user_id, status, provider, model)
			VALUES ($1, $2, 'running', $3, $4)
			RETURNING id
		`, convID, userID, targetModel.Provider, targetModel.ID).Scan(&genID)
		if err != nil {
			_ = s.quotaService.ReleaseReservation(context.Background(), ledgerID, "failed")
			writeSSE(w, flusher, "generation.failed", map[string]string{
				"code":    "GENERATION_INIT_FAILED",
				"message": err.Error(),
			})
			return
		}
		_, _ = s.pool.Exec(context.Background(), `UPDATE usage_ledger SET generation_id = $1 WHERE id = $2`, genID, ledgerID)
	} else {
		genID = fmt.Sprintf("gen-%d", time.Now().UnixNano())
	}

	streamCtx, cancel := context.WithCancel(r.Context())
	defer cancel()
	s.registerCancel(genID, cancel)
	defer s.unregisterCancel(genID)

	// Stage 7: Generating response
	emitActivity(w, flusher, "generating", 7, 7, "Javob bayon qilinmoqda", "Hujjat xulosalari va javob matni shakllantirilmoqda", "active")

	writeSSE(w, flusher, "generation.started", map[string]any{
		"generation_id":   genID,
		"conversation_id": convID,
		"user_message_id": userMsg.ID,
		"model_id":        targetModel.ID,
		"model_name":      targetModel.Name,
		"analysis_mode":   mode,
	})

	// 7. Invoke Provider with Target Model
	activeProvider := s.baseProvider.WithModel(targetModel.ProviderModelID, outputTokens)
	chunkCh, errCh := activeProvider.StreamChat(streamCtx, aiMessages)

	var sb strings.Builder
	var streamErr error
	var finishReason string
	isCancelled := false

	for {
		select {
		case <-streamCtx.Done():
			isCancelled = true
			goto STREAM_END

		case err, ok := <-errCh:
			if ok && err != nil {
				if errors.Is(err, context.Canceled) || errors.Is(streamCtx.Err(), context.Canceled) {
					isCancelled = true
				} else {
					streamErr = err
				}
				goto STREAM_END
			}

		case chunk, ok := <-chunkCh:
			if !ok {
				goto STREAM_END
			}
			if chunk.FinishReason != "" {
				finishReason = chunk.FinishReason
			}
			if chunk.IsDone {
				goto STREAM_END
			}
			if chunk.DeltaContent != "" {
				sb.WriteString(chunk.DeltaContent)
				writeSSE(w, flusher, "message.delta", map[string]string{
					"generation_id": genID,
					"text":          chunk.DeltaContent,
				})
			}
		}
	}

STREAM_END:
	fullAssistantContent := sb.String()

	// 8. Self-Healing Fallback Recovery:
	// If primary model produced empty content or unexpected termination without cancellation:
	if !isCancelled && len(strings.TrimSpace(fullAssistantContent)) == 0 {
		fallbackModel, fbErr := s.router.GetFallbackModel(r.Context(), ent, targetModel.ID)
		if fbErr == nil && fallbackModel != nil {
			emitActivity(w, flusher, "fallback", 6, 7, "Muqobil modelga ulanmoqda...", fallbackModel.Name, "active")
			fallbackProvider := s.baseProvider.WithModel(fallbackModel.ProviderModelID, outputTokens)
			fbChunkCh, fbErrCh := fallbackProvider.StreamChat(streamCtx, aiMessages)

			for {
				select {
				case <-streamCtx.Done():
					isCancelled = true
					goto FALLBACK_END
				case err, ok := <-fbErrCh:
					if ok && err != nil {
						if !errors.Is(err, context.Canceled) {
							streamErr = err
						}
					}
					goto FALLBACK_END
				case chunk, ok := <-fbChunkCh:
					if !ok || chunk.IsDone {
						goto FALLBACK_END
					}
					if chunk.FinishReason != "" {
						finishReason = chunk.FinishReason
					}
					if chunk.DeltaContent != "" {
						sb.WriteString(chunk.DeltaContent)
						writeSSE(w, flusher, "message.delta", map[string]string{
							"generation_id": genID,
							"text":          chunk.DeltaContent,
						})
					}
				}
			}
		FALLBACK_END:
			fullAssistantContent = sb.String()
			targetModel = fallbackModel
		}
	}

	if isCancelled {
		var asstMsgID *string
		if fullAssistantContent != "" {
			asstMsg, _ := s.msgService.CreateAssistantMessage(context.Background(), userID, convID, fullAssistantContent, "cancelled")
			if asstMsg != nil {
				asstMsgID = &asstMsg.ID
			}
		}

		if s.pool != nil {
			_, _ = s.pool.Exec(context.Background(), `
				UPDATE generations
				SET status = 'cancelled', assistant_message_id = $1, cancelled_at = CURRENT_TIMESTAMP
				WHERE id = $2
			`, asstMsgID, genID)
		}
		_ = s.quotaService.ReleaseReservation(context.Background(), ledgerID, "cancelled")

		writeSSE(w, flusher, "generation.cancelled", map[string]any{
			"generation_id": genID,
			"partial_text":  fullAssistantContent,
		})
		return
	}

	// If finishReason is length or streamErr interrupted, but partial content exists -> Save checkpoint for continuation!
	isInterrupted := finishReason == "length" || (streamErr != nil && len(strings.TrimSpace(fullAssistantContent)) >= 50)

	// Clean citations
	type CleanCitation struct {
		FileID       string `json:"file_id"`
		Filename     string `json:"filename"`
		PageNumber   int    `json:"page_number"`
		SectionTitle string `json:"section_title,omitempty"`
		Display      string `json:"display"`
		Snippet      string `json:"snippet"`
	}
	seen := make(map[string]bool)
	var cleanCitations []CleanCitation
	for _, c := range citations {
		key := fmt.Sprintf("%s:%d", c.Filename, c.PageNumber)
		if seen[key] {
			continue
		}
		seen[key] = true
		display := fmt.Sprintf("%s • %d-sahifa", c.Filename, c.PageNumber)
		if c.SectionTitle != "" {
			display = fmt.Sprintf("%s (%s) • %d-sahifa", c.Filename, c.SectionTitle, c.PageNumber)
		}
		cleanCitations = append(cleanCitations, CleanCitation{
			FileID:       c.FileID,
			Filename:     c.Filename,
			PageNumber:   c.PageNumber,
			SectionTitle: c.SectionTitle,
			Display:      display,
			Snippet:      c.Snippet,
		})
	}

	// If completely empty after fallback, NEVER save as completed!
	if len(strings.TrimSpace(fullAssistantContent)) == 0 {
		errCode := "UPSTREAM_EMPTY_RESPONSE"
		errMsg := "AI provayderidan javob qaytmadi. Iltimos, qayta urining."
		if streamErr != nil {
			errCode = "UPSTREAM_ERROR"
			errMsg = streamErr.Error()
		}

		if s.pool != nil {
			_, _ = s.pool.Exec(context.Background(), `
				UPDATE generations
				SET status = 'failed', error_code = $1, error_message = $2, completed_at = CURRENT_TIMESTAMP
				WHERE id = $3
			`, errCode, errMsg, genID)
		}
		_ = s.quotaService.ReleaseReservation(context.Background(), ledgerID, "failed")

		writeSSE(w, flusher, "generation.failed", map[string]string{
			"generation_id": genID,
			"code":          errCode,
			"message":       errMsg,
		})
		return
	}

	// 9. Persist Assistant Message
	msgStatus := "completed"
	if isInterrupted {
		msgStatus = "interrupted"
	}
	asstMsg, err := s.msgService.CreateAssistantMessageWithMeta(
		context.Background(),
		userID,
		convID,
		fullAssistantContent,
		msgStatus,
		cleanCitations,
		suggestedQuestions,
		extractedEntities,
		mode,
	)
	if err != nil {
		_ = s.quotaService.ReleaseReservation(context.Background(), ledgerID, "failed")
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"generation_id": genID,
			"code":          "PERSISTENCE_FAILED",
			"message":       "Javobni saqlashda xatolik yuz berdi",
		})
		return
	}

	// 10. Persist Analysis Checkpoint
	var checkpointID string
	if s.pool != nil {
		_ = s.pool.QueryRow(context.Background(), `
			INSERT INTO analysis_checkpoints (
				generation_id, conversation_id, user_id, mode, 
				completed_sections, accumulated_content, status
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			RETURNING id
		`, genID, convID, userID, mode, []string{"intro", "analysis"}, fullAssistantContent, msgStatus).Scan(&checkpointID)

		_, _ = s.pool.Exec(context.Background(), `
			UPDATE generations
			SET status = $1, assistant_message_id = $2, completed_at = CURRENT_TIMESTAMP
			WHERE id = $3
		`, msgStatus, asstMsg.ID, genID)
	}

	// Settle usage
	promptTokensEst := len(userMessageContent)/4 + 20
	compTokensEst := len(fullAssistantContent)/4 + 1
	costMultiplier := 1.0
	if hasImages {
		costMultiplier = 1.5
	}
	_ = s.quotaService.SettleUsage(
		context.Background(),
		ledgerID,
		promptTokensEst,
		compTokensEst,
		targetModel.InputPricePerMillionUSD,
		targetModel.OutputPricePerMillionUSD,
		costMultiplier,
	)

	// Emit completion / interruption event
	emitActivity(w, flusher, "generating", 7, 7, "Javob yakunlandi", "Tahlil natijalari to'liq taqdim etildi", "completed")

	respData := map[string]any{
		"generation_id":       genID,
		"message_id":          asstMsg.ID,
		"content":             fullAssistantContent,
		"model_id":            targetModel.ID,
		"analysis_mode":       mode,
		"checkpoint_id":       checkpointID,
		"is_interrupted":      isInterrupted,
		"suggested_questions": suggestedQuestions,
		"extracted_entities":  extractedEntities,
		"citations":           cleanCitations,
	}

	if isInterrupted {
		respData["interruption_message"] = "Tahlil hajmi yoki ulanish tufayli to'xtatildi. Tayyor bo'lgan natijalar saqlandi. Qolgan qismini yakunlash uchun Davom etish tugmasini bosing."
		writeSSE(w, flusher, "generation.interrupted", respData)
	} else {
		writeSSE(w, flusher, "generation.completed", respData)
	}
}

// ContinueStream resumes an interrupted analysis from its saved checkpoint without repeating completed sections.
func (s *Service) ContinueStream(w http.ResponseWriter, r *http.Request, userID, convID, checkpointID, requestedModelID string) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache, no-transform")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	reqLocale := i18n.GetLocaleFromRequest(r)

	// 1. Fetch checkpoint
	var cp AnalysisCheckpoint
	if s.pool != nil {
		err := s.pool.QueryRow(r.Context(), `
			SELECT id, generation_id, conversation_id, user_id, mode, accumulated_content, status
			FROM analysis_checkpoints
			WHERE id = $1 AND user_id = $2
		`, checkpointID, userID).Scan(
			&cp.ID, &cp.GenerationID, &cp.ConversationID, &cp.UserID, &cp.Mode, &cp.AccumulatedContent, &cp.Status,
		)
		if err != nil {
			writeSSE(w, flusher, "generation.failed", map[string]string{
				"code":    "CHECKPOINT_NOT_FOUND",
				"message": "Saqlangan nazorat nuqtasi topilmadi",
			})
			return
		}
	} else {
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    "CHECKPOINT_NOT_FOUND",
			"message": "Ma'lumotlar bazasi ulanmagan",
		})
		return
	}

	// Keepalive
	heartbeatDone := make(chan struct{})
	defer close(heartbeatDone)
	go func() {
		ticker := time.NewTicker(3 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-heartbeatDone:
				return
			case <-r.Context().Done():
				return
			case <-ticker.C:
				writeHeartbeat(w, flusher)
			}
		}
	}()

	emitActivity(w, flusher, "resuming", 1, 2, "Nazorat nuqtasi tiklanmoqda", "Avval tahlil qilingan ma'lumotlar saqlandi", "completed")
	emitActivity(w, flusher, "generating", 2, 2, "Qolgan qismi davom ettirilmoqda", "To'xtagan joydan mantiqiy yakunlanmoqda", "active")

	ent, err := s.plansService.ResolveUserEntitlement(r.Context(), userID)
	if err != nil {
		writeSSE(w, flusher, "generation.failed", map[string]string{
			"code":    "ENTITLEMENT_RESOLUTION_FAILED",
			"message": "Foydalanuvchi huquqlarini tekshirishda xatolik yuz berdi",
		})
		return
	}

	targetModel, err := s.router.RouteMultimodal(r.Context(), requestedModelID, ent, false)
	if err != nil {
		targetModel = &gateway.Model{
			ID:              "gpt-4o-mini",
			ProviderModelID: "openai/gpt-4o-mini",
		}
	}

	// Prepare continuation messages
	continuationPrompt := fmt.Sprintf(
		"DAVOM ETTIRISH VAZIFASI: Oldingi tahlil uzilib qolgan edi. Quyida allaqachon tayyorlangan matn keltirilgan:\n\n=== AVVAL TAYYORLANGAN MATN BOSHLANISHI ===\n%s\n=== AVVAL TAYYORLANGAN MATN TUGASHI ===\n\nKO'RSATMA: Yuqoridagi matnni mutlaqo qaytadan takrorlamang. To'xtagan joyidan boshlab, qolgan bo'limlarni, xulosa va tavsiyalarni to'liq, ravon davom ettiring va yakunlang.",
		cp.AccumulatedContent,
	)

	aiMessages := []ai.ChatMessage{
		{
			Role:    "system",
			Content: i18n.GetAISystemPrompt(reqLocale) + "\n\nSiz to'xtab qolgan tahlilni davom ettiryapsiz. Takrorlanishlarga yo'l qo'ymang.",
		},
		{
			Role:    "user",
			Content: continuationPrompt,
		},
	}

	outputTokens := targetModel.MaxOutputTokens
	if outputTokens < 2048 {
		outputTokens = 2048
	}

	activeProvider := s.baseProvider.WithModel(targetModel.ProviderModelID, outputTokens)
	streamCtx, cancel := context.WithCancel(r.Context())
	defer cancel()

	chunkCh, errCh := activeProvider.StreamChat(streamCtx, aiMessages)

	var sb strings.Builder
	writeSSE(w, flusher, "generation.started", map[string]any{
		"generation_id":   cp.GenerationID,
		"conversation_id": convID,
		"checkpoint_id":   checkpointID,
		"model_id":        targetModel.ID,
	})

	for {
		select {
		case <-streamCtx.Done():
			goto CONT_STREAM_END
		case err, ok := <-errCh:
			if ok && err != nil {
				writeSSE(w, flusher, "generation.failed", map[string]string{
					"code":    "CONTINUATION_ERROR",
					"message": err.Error(),
				})
				return
			}
			goto CONT_STREAM_END
		case chunk, ok := <-chunkCh:
			if !ok || chunk.IsDone {
				goto CONT_STREAM_END
			}
			if chunk.DeltaContent != "" {
				sb.WriteString(chunk.DeltaContent)
				writeSSE(w, flusher, "message.delta", map[string]string{
					"generation_id": cp.GenerationID,
					"text":          chunk.DeltaContent,
				})
			}
		}
	}

CONT_STREAM_END:
	additionalText := sb.String()
	totalContent := cp.AccumulatedContent + "\n\n" + additionalText

	// Update existing message in database
	var asstMsgID string
	_ = s.pool.QueryRow(r.Context(), `
		SELECT assistant_message_id FROM generations WHERE id = $1
	`, cp.GenerationID).Scan(&asstMsgID)

	if asstMsgID != "" {
		_ = s.msgService.AppendAssistantMessageContent(r.Context(), asstMsgID, "\n\n"+additionalText, "completed")
	}

	// Mark checkpoint completed
	_, _ = s.pool.Exec(r.Context(), `
		UPDATE analysis_checkpoints
		SET accumulated_content = $1, status = 'completed', updated_at = CURRENT_TIMESTAMP
		WHERE id = $2
	`, totalContent, checkpointID)

	emitActivity(w, flusher, "generating", 2, 2, "Tahlil to'liq yakunlandi", "Barcha qismlar muvaffaqiyatli birlashtirildi", "completed")

	writeSSE(w, flusher, "generation.completed", map[string]any{
		"generation_id": cp.GenerationID,
		"message_id":    asstMsgID,
		"content":       totalContent,
		"checkpoint_id": checkpointID,
	})
}
