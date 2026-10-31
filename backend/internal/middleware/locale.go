package middleware

import (
	"net/http"

	"ai-chat-backend/internal/i18n"
)

// LocaleMiddleware parses Accept-Language header and injects resolved locale into Context.
func LocaleMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		locale := i18n.ParseLocale(r.Header.Get("Accept-Language"))
		ctx := i18n.WithLocale(r.Context(), locale)
		w.Header().Set("Content-Language", locale)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
