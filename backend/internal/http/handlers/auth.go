package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"ai-chat-backend/internal/auth"
	apphttp "ai-chat-backend/internal/http"
	"ai-chat-backend/internal/i18n"
	"ai-chat-backend/internal/middleware"
)

type AuthHandler struct {
	authService *auth.Service
}

func NewAuthHandler(authService *auth.Service) *AuthHandler {
	return &AuthHandler{authService: authService}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req auth.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apphttp.WriteLocalizedError(w, r, http.StatusBadRequest, "MALFORMED_JSON", "ERR_MALFORMED_JSON")
		return
	}

	userAgent := r.UserAgent()
	ip := r.RemoteAddr

	resp, err := h.authService.Register(r.Context(), req, userAgent, ip)
	if err != nil {
		if errors.Is(err, auth.ErrEmailExists) {
			apphttp.WriteLocalizedError(w, r, http.StatusConflict, "EMAIL_EXISTS", "ERR_EMAIL_EXISTS")
			return
		}
		if errors.Is(err, auth.ErrValidation) {
			apphttp.WriteError(w, r, http.StatusUnprocessableEntity, "VALIDATION_ERROR", err.Error())
			return
		}
		apphttp.WriteLocalizedError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "ERR_INTERNAL")
		return
	}

	apphttp.WriteJSON(w, http.StatusCreated, resp)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req auth.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apphttp.WriteLocalizedError(w, r, http.StatusBadRequest, "MALFORMED_JSON", "ERR_MALFORMED_JSON")
		return
	}

	userAgent := r.UserAgent()
	ip := r.RemoteAddr

	resp, err := h.authService.Login(r.Context(), req, userAgent, ip)
	if err != nil {
		if errors.Is(err, auth.ErrInvalidCredentials) {
			apphttp.WriteLocalizedError(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "ERR_INVALID_CREDENTIALS")
			return
		}
		apphttp.WriteLocalizedError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "ERR_INTERNAL")
		return
	}

	apphttp.WriteJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req auth.RefreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apphttp.WriteLocalizedError(w, r, http.StatusBadRequest, "MALFORMED_JSON", "ERR_MALFORMED_JSON")
		return
	}

	userAgent := r.UserAgent()
	ip := r.RemoteAddr

	resp, err := h.authService.RefreshToken(r.Context(), req.RefreshToken, userAgent, ip)
	if err != nil {
		apphttp.WriteLocalizedError(w, r, http.StatusUnauthorized, "INVALID_TOKEN", "ERR_INVALID_TOKEN")
		return
	}

	apphttp.WriteJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var req auth.RefreshRequest
	_ = json.NewDecoder(r.Body).Decode(&req)

	if req.RefreshToken != "" {
		_ = h.authService.Logout(r.Context(), req.RefreshToken)
	}

	locale := i18n.GetLocaleFromRequest(r)
	apphttp.WriteJSON(w, http.StatusOK, map[string]string{
		"message": i18n.T(locale, "SUCCESS_LOGOUT"),
	})
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		apphttp.WriteLocalizedError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "ERR_UNAUTHORIZED")
		return
	}

	user, err := h.authService.GetUserByID(r.Context(), userID)
	if err != nil {
		apphttp.WriteLocalizedError(w, r, http.StatusNotFound, "USER_NOT_FOUND", "ERR_NOT_FOUND")
		return
	}

	apphttp.WriteJSON(w, http.StatusOK, auth.UserPublic{
		ID:        user.ID,
		Email:     user.Email,
		FullName:  user.FullName,
		Locale:    user.Locale,
		CreatedAt: user.CreatedAt,
	})
}

// UpdateLocale allows the authenticated user to persist their app language choice in their profile.
func (h *AuthHandler) UpdateLocale(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		apphttp.WriteLocalizedError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "ERR_UNAUTHORIZED")
		return
	}

	var req auth.UpdateLocaleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Locale == "" {
		apphttp.WriteLocalizedError(w, r, http.StatusBadRequest, "MALFORMED_JSON", "ERR_MALFORMED_JSON")
		return
	}

	if err := h.authService.UpdateLocale(r.Context(), userID, req.Locale); err != nil {
		apphttp.WriteLocalizedError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "ERR_INTERNAL")
		return
	}

	cleanLocale := i18n.ParseLocale(req.Locale)
	apphttp.WriteJSON(w, http.StatusOK, map[string]string{
		"message": i18n.T(cleanLocale, "SUCCESS_LOCALE_UPDATED"),
		"locale":  cleanLocale,
	})
}

// DeleteAccount handles Google Play compliant account deletion.
func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		apphttp.WriteLocalizedError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "ERR_UNAUTHORIZED")
		return
	}

	if err := h.authService.DeleteUser(r.Context(), userID); err != nil {
		apphttp.WriteLocalizedError(w, r, http.StatusInternalServerError, "DELETE_FAILED", "ERR_INTERNAL")
		return
	}

	locale := i18n.GetLocaleFromRequest(r)
	apphttp.WriteJSON(w, http.StatusOK, map[string]string{
		"message": i18n.T(locale, "SUCCESS_ACCOUNT_DELETED"),
	})
}
