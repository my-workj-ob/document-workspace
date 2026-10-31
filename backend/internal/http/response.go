package http

import (
	"encoding/json"
	"net/http"

	"ai-chat-backend/internal/i18n"
)

type contextKey string

const RequestIDKey contextKey = "request_id"

// SuccessResponse standard format
type SuccessResponse struct {
	Data any `json:"data"`
}

// ErrorDetail standard format
type ErrorDetail struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"request_id,omitempty"`
}

// ErrorResponse standard format
type ErrorResponse struct {
	Error ErrorDetail `json:"error"`
}

// WriteJSON writes a status code and JSON-encoded data.
func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(SuccessResponse{Data: data})
}

// WriteError writes a structured JSON error response.
func WriteError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	requestID := ""
	if r != nil {
		if id, ok := r.Context().Value(RequestIDKey).(string); ok {
			requestID = id
		}
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(ErrorResponse{
		Error: ErrorDetail{
			Code:      code,
			Message:   message,
			RequestID: requestID,
		},
	})
}

// WriteLocalizedError automatically translates the error message according to the request locale.
func WriteLocalizedError(w http.ResponseWriter, r *http.Request, status int, code, translationKey string, defaultMsg ...string) {
	locale := i18n.GetLocaleFromRequest(r)
	msg := i18n.T(locale, translationKey)
	if msg == translationKey && len(defaultMsg) > 0 {
		msg = defaultMsg[0]
	}
	WriteError(w, r, status, code, msg)
}
