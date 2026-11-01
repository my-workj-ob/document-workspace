package messages

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrConversationNotFound = errors.New("CONVERSATION_NOT_FOUND: Suhbat topilmadi yoki ruxsat yo'q")
	ErrEmptyContent         = errors.New("EMPTY_CONTENT: Xabar matni bo'sh bo'lishi mumkin emas")
	ErrMessageNotFound      = errors.New("MESSAGE_NOT_FOUND: Xabar topilmadi")
)

// Service handles message operations with conversation ownership checks.
type Service struct {
	pool *pgxpool.Pool
}

// NewService creates a new messages service.
func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

// CreateUserMessage persists a user message and auto-titles conversation if needed.
func (s *Service) CreateUserMessage(ctx context.Context, userID, convID, content string) (*Message, error) {
	return s.CreateUserMessageWithFiles(ctx, userID, convID, content, nil)
}

// CreateUserMessageWithFiles persists a user message with attached file IDs and auto-titles conversation if needed.
func (s *Service) CreateUserMessageWithFiles(ctx context.Context, userID, convID, content string, fileIDs []string) (*Message, error) {
	trimmed := strings.TrimSpace(content)
	if trimmed == "" {
		return nil, ErrEmptyContent
	}

	if len(fileIDs) > 5 {
		return nil, errors.New("FILE_COUNT_LIMIT_EXCEEDED: Bitta xabarga ko'pi bilan 5 ta fayl biriktirish mumkin")
	}

	if s.pool == nil {
		if fileIDs == nil {
			fileIDs = []string{}
		}
		now := time.Now().UTC()
		return &Message{
			ID:              "msg-user-" + fmt.Sprintf("%d", now.UnixNano()),
			ConversationID:  convID,
			UserID:          userID,
			Role:            "user",
			Content:         trimmed,
			Status:          "completed",
			AttachedFileIDs: fileIDs,
			CreatedAt:       now,
			UpdatedAt:       now,
		}, nil
	}

	// Verify conversation ownership
	var currentTitle string
	err := s.pool.QueryRow(ctx, `
		SELECT title FROM conversations WHERE id = $1 AND user_id = $2
	`, convID, userID).Scan(&currentTitle)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrConversationNotFound
		}
		return nil, fmt.Errorf("failed to verify conversation: %w", err)
	}

	// Auto-title conversation if still default
	if currentTitle == "Yangi suhbat" || currentTitle == "New Chat" {
		newTitle := trimmed
		if len([]rune(newTitle)) > 40 {
			newTitle = string([]rune(newTitle)[:40]) + "..."
		}
		_, _ = s.pool.Exec(ctx, `
			UPDATE conversations SET title = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2
		`, newTitle, convID)
	}

	if fileIDs == nil {
		fileIDs = []string{}
	}

	var msg Message
	err = s.pool.QueryRow(ctx, `
		INSERT INTO messages (conversation_id, user_id, role, content, status, attached_file_ids)
		VALUES ($1, $2, 'user', $3, 'completed', $4)
		RETURNING id, conversation_id, user_id, role, content, status, COALESCE(attached_file_ids, '{}'), created_at, updated_at
	`, convID, userID, trimmed, fileIDs).Scan(
		&msg.ID, &msg.ConversationID, &msg.UserID, &msg.Role, &msg.Content, &msg.Status, &msg.AttachedFileIDs, &msg.CreatedAt, &msg.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to save user message: %w", err)
	}

	return &msg, nil
}

// CreateAssistantMessage persists an assistant response (initial or final).
func (s *Service) CreateAssistantMessage(ctx context.Context, userID, convID, content, status string) (*Message, error) {
	return s.CreateAssistantMessageWithMeta(ctx, userID, convID, content, status, nil, nil, nil, "deep_analysis")
}

// CreateAssistantMessageWithMeta persists an assistant response with structured intelligence metadata.
func (s *Service) CreateAssistantMessageWithMeta(
	ctx context.Context,
	userID, convID, content, status string,
	citations any,
	suggestedQuestions any,
	extractedEntities any,
	mode string,
) (*Message, error) {
	if status == "" {
		status = "completed"
	}
	if mode == "" {
		mode = "deep_analysis"
	}

	if s.pool == nil {
		now := time.Now().UTC()
		return &Message{
			ID:                 "msg-asst-" + fmt.Sprintf("%d", now.UnixNano()),
			ConversationID:     convID,
			UserID:             userID,
			Role:               "assistant",
			Content:            content,
			Status:             status,
			AttachedFileIDs:    []string{},
			Citations:          citations,
			SuggestedQuestions: []string{},
			ExtractedEntities:  extractedEntities,
			AnalysisMode:       mode,
			CreatedAt:          now,
			UpdatedAt:          now,
		}, nil
	}

	var msg Message
	err := s.pool.QueryRow(ctx, `
		INSERT INTO messages (conversation_id, user_id, role, content, status, citations, suggested_questions, extracted_entities, analysis_mode)
		VALUES ($1, $2, 'assistant', $3, $4, COALESCE($5, '[]'::jsonb), COALESCE($6, '[]'::jsonb), COALESCE($7, '{}'::jsonb), $8)
		RETURNING id, conversation_id, user_id, role, content, status, created_at, updated_at
	`, convID, userID, content, status, citations, suggestedQuestions, extractedEntities, mode).Scan(
		&msg.ID, &msg.ConversationID, &msg.UserID, &msg.Role, &msg.Content, &msg.Status, &msg.CreatedAt, &msg.UpdatedAt,
	)
	if err != nil {
		// Fallback without extended columns if migration is running
		err = s.pool.QueryRow(ctx, `
			INSERT INTO messages (conversation_id, user_id, role, content, status)
			VALUES ($1, $2, 'assistant', $3, $4)
			RETURNING id, conversation_id, user_id, role, content, status, created_at, updated_at
		`, convID, userID, content, status).Scan(
			&msg.ID, &msg.ConversationID, &msg.UserID, &msg.Role, &msg.Content, &msg.Status, &msg.CreatedAt, &msg.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to save assistant message: %w", err)
		}
	}

	msg.Citations = citations
	msg.ExtractedEntities = extractedEntities
	msg.AnalysisMode = mode
	return &msg, nil
}

// AppendAssistantMessageContent appends streamed continuation text to an existing assistant message.
func (s *Service) AppendAssistantMessageContent(ctx context.Context, msgID, additionalContent, newStatus string) error {
	if s.pool == nil {
		return nil
	}
	_, err := s.pool.Exec(ctx, `
		UPDATE messages
		SET content = content || $1, status = $2, updated_at = CURRENT_TIMESTAMP
		WHERE id = $3
	`, additionalContent, newStatus, msgID)
	return err
}

// UpdateAssistantMessage updates content and final status for an assistant message.
func (s *Service) UpdateAssistantMessage(ctx context.Context, msgID, content, status string) error {
	if s.pool == nil {
		return nil
	}
	_, err := s.pool.Exec(ctx, `
		UPDATE messages
		SET content = $1, status = $2, updated_at = CURRENT_TIMESTAMP
		WHERE id = $3
	`, content, status, msgID)
	return err
}

// ListMessages returns messages for a conversation after verifying ownership.
func (s *Service) ListMessages(ctx context.Context, userID, convID string, limit int) ([]Message, error) {
	if s.pool == nil {
		return []Message{}, nil
	}

	// Verify conversation ownership
	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM conversations WHERE id = $1 AND user_id = $2)
	`, convID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, ErrConversationNotFound
	}

	if limit <= 0 || limit > 200 {
		limit = 100
	}

	rows, err := s.pool.Query(ctx, `
		SELECT id, conversation_id, user_id, role, content, status, COALESCE(attached_file_ids, '{}'),
		       COALESCE(citations, '[]'::jsonb), COALESCE(suggested_questions, '[]'::jsonb),
		       COALESCE(extracted_entities, '{}'::jsonb), COALESCE(analysis_mode, 'deep_analysis'),
		       created_at, updated_at
		FROM messages
		WHERE conversation_id = $1
		ORDER BY created_at ASC
		LIMIT $2
	`, convID, limit)
	if err != nil {
		// Fallback to legacy query if database hasn't applied latest columns yet
		rows, err = s.pool.Query(ctx, `
			SELECT id, conversation_id, user_id, role, content, status, COALESCE(attached_file_ids, '{}'),
			       created_at, updated_at
			FROM messages
			WHERE conversation_id = $1
			ORDER BY created_at ASC
			LIMIT $2
		`, convID, limit)
		if err != nil {
			return nil, fmt.Errorf("failed to query messages: %w", err)
		}
		defer rows.Close()

		list := make([]Message, 0)
		for rows.Next() {
			var m Message
			if err := rows.Scan(&m.ID, &m.ConversationID, &m.UserID, &m.Role, &m.Content, &m.Status, &m.AttachedFileIDs, &m.CreatedAt, &m.UpdatedAt); err != nil {
				return nil, fmt.Errorf("failed to scan message: %w", err)
			}
			list = append(list, m)
		}
		return list, nil
	}
	defer rows.Close()

	list := make([]Message, 0)
	for rows.Next() {
		var m Message
		var cit, sq, ee any
		var mode string
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.UserID, &m.Role, &m.Content, &m.Status, &m.AttachedFileIDs, &cit, &sq, &ee, &mode, &m.CreatedAt, &m.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan message: %w", err)
		}
		m.Citations = cit
		m.ExtractedEntities = ee
		m.AnalysisMode = mode
		list = append(list, m)
	}

	return list, nil
}

// ReportMessage stores user report against an AI generated response for moderation.
func (s *Service) ReportMessage(ctx context.Context, userID, messageID, reason, comment string) error {
	if s.pool == nil {
		return nil
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO message_reports (user_id, message_id, reason, comment, status)
		VALUES ($1::uuid, $2::uuid, $3, $4, 'pending')
	`, userID, messageID, reason, comment)
	return err
}
