package generations

import "time"

// Generation represents an AI streaming generation job.
type Generation struct {
	ID                 string     `json:"id"`
	ConversationID     string     `json:"conversation_id"`
	UserID             string     `json:"user_id"`
	AssistantMessageID *string    `json:"assistant_message_id,omitempty"`
	Status             string     `json:"status"`
	Provider           string     `json:"provider"`
	Model              string     `json:"model"`
	PromptTokens       int        `json:"prompt_tokens"`
	CompletionTokens   int        `json:"completion_tokens"`
	TotalTokens        int        `json:"total_tokens"`
	ErrorCode          *string    `json:"error_code,omitempty"`
	ErrorMessage       *string    `json:"error_message,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	CompletedAt        *time.Time `json:"completed_at,omitempty"`
	CancelledAt        *time.Time `json:"cancelled_at,omitempty"`
}

// GenerateRequest payload when user initiates chat generation.
type GenerateRequest struct {
	Message string   `json:"message"`
	ModelID string   `json:"model_id,omitempty"`
	FileIDs []string `json:"file_ids,omitempty"`
	Mode    string   `json:"mode,omitempty"` // quick_summary, deep_analysis, critical_review, academic, legal, financial, comparison
}

// ContinueRequest payload when resuming an interrupted analysis.
type ContinueRequest struct {
	CheckpointID string `json:"checkpoint_id"`
	ModelID      string `json:"model_id,omitempty"`
}

// ActivityEvent represents real-time activity steps during backend processing.
type ActivityEvent struct {
	Stage     string `json:"stage"`
	Index     int    `json:"index"`
	Total     int    `json:"total"`
	Title     string `json:"title"`
	Detail    string `json:"detail,omitempty"`
	Status    string `json:"status"` // active, completed, failed
	Timestamp string `json:"timestamp"`
}

// AnalysisCheckpoint represents saved state for idempotent continuation.
type AnalysisCheckpoint struct {
	ID                 string    `json:"id"`
	GenerationID       string    `json:"generation_id"`
	ConversationID     string    `json:"conversation_id"`
	UserID             string    `json:"user_id"`
	Mode               string    `json:"mode"`
	CompletedSections  []string  `json:"completed_sections"`
	RemainingSections  []string  `json:"remaining_sections"`
	AccumulatedContent string    `json:"accumulated_content"`
	LastSectionTitle   string    `json:"last_section_title"`
	Status             string    `json:"status"`
	CreatedAt          time.Time `json:"created_at"`
	UpdatedAt          time.Time `json:"updated_at"`
}
