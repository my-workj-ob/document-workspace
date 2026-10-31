package admin

import (
	"net/http"

	apphttp "ai-chat-backend/internal/http"
	"ai-chat-backend/internal/middleware"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Authorizer struct {
	pool *pgxpool.Pool
}

func NewAuthorizer(pool *pgxpool.Pool) *Authorizer {
	return &Authorizer{pool: pool}
}

func (a *Authorizer) RequireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, ok := middleware.GetUserID(r.Context())
		if !ok {
			apphttp.WriteError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Avtorizatsiyadan o'tilmagan")
			return
		}

		var role string
		err := a.pool.QueryRow(r.Context(),
			`SELECT role FROM admin_users WHERE user_id = $1::uuid`, userID,
		).Scan(&role)
		if err == pgx.ErrNoRows {
			apphttp.WriteError(w, r, http.StatusForbidden, "ADMIN_REQUIRED", "Admin ruxsati talab qilinadi")
			return
		}
		if err != nil {
			apphttp.WriteError(w, r, http.StatusInternalServerError, "AUTHORIZATION_FAILED", "Admin ruxsatini tekshirib bo'lmadi")
			return
		}

		next.ServeHTTP(w, r)
	})
}
