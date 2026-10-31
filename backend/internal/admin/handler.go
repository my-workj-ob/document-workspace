package admin

import (
	"context"
	"net/http"
	"strconv"
	"strings"
	"time"

	apphttp "ai-chat-backend/internal/http"
	"ai-chat-backend/internal/middleware"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const SchemaSQL = `
CREATE TABLE IF NOT EXISTS admin_users (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'analyst', 'read_only')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_user_created ON admin_audit_logs(admin_user_id, created_at DESC);
ALTER TABLE usage_ledger ADD COLUMN IF NOT EXISTS cache_read_tokens INT NOT NULL DEFAULT 0;
ALTER TABLE usage_ledger ADD COLUMN IF NOT EXISTS cache_write_tokens INT NOT NULL DEFAULT 0;
`

type Handler struct {
	pool                *pgxpool.Pool
	providerConfigured  bool
	providerName        string
}

func NewHandler(pool *pgxpool.Pool, providerConfigured bool, providerName string) *Handler {
	return &Handler{pool: pool, providerConfigured: providerConfigured, providerName: providerName}
}

func (h *Handler) Overview(w http.ResponseWriter, r *http.Request) {
	days := queryDays(r)
	var result struct {
		TotalUsers       int64     `json:"total_users"`
		NewUsers         int64     `json:"new_users"`
		ActiveUsers      int64     `json:"active_users"`
		InactiveUsers    int64     `json:"inactive_users"`
		DAU              int64     `json:"dau"`
		WAU              int64     `json:"wau"`
		MAU              int64     `json:"mau"`
		InputTokens      int64     `json:"input_tokens"`
		OutputTokens     int64     `json:"output_tokens"`
		EstimatedCostUSD float64   `json:"estimated_cost_usd"`
		UpdatedAt        time.Time `json:"updated_at"`
		DataSource       string    `json:"data_source"`
	}
	err := h.pool.QueryRow(r.Context(), `
		WITH user_activity AS (
			SELECT user_id, MAX(created_at) AS last_activity
			FROM usage_ledger
			WHERE status = 'settled'
			GROUP BY user_id
		), token_totals AS (
			SELECT
				COALESCE(SUM(input_tokens), 0)::bigint AS input_tokens,
				COALESCE(SUM(output_tokens), 0)::bigint AS output_tokens,
				COALESCE(SUM(actual_cost_usd), 0)::double precision AS estimated_cost
			FROM usage_ledger WHERE status = 'settled'
		)
		SELECT
			(SELECT COUNT(*) FROM users),
			(SELECT COUNT(*) FROM users WHERE created_at >= CURRENT_TIMESTAMP - ($1::int * INTERVAL '1 day')),
			(SELECT COUNT(*) FROM user_activity WHERE last_activity >= CURRENT_TIMESTAMP - INTERVAL '30 days'),
			(SELECT COUNT(*) FROM users) -
				(SELECT COUNT(*) FROM user_activity WHERE last_activity >= CURRENT_TIMESTAMP - INTERVAL '30 days'),
			(SELECT COUNT(DISTINCT user_id) FROM usage_ledger WHERE status = 'settled' AND created_at >= CURRENT_DATE),
			(SELECT COUNT(DISTINCT user_id) FROM usage_ledger WHERE status = 'settled' AND created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'),
			(SELECT COUNT(DISTINCT user_id) FROM usage_ledger WHERE status = 'settled' AND created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'),
			token_totals.input_tokens, token_totals.output_tokens,
			token_totals.estimated_cost, CURRENT_TIMESTAMP
		FROM token_totals
	`, days).Scan(
		&result.TotalUsers, &result.NewUsers, &result.ActiveUsers, &result.InactiveUsers,
		&result.DAU, &result.WAU, &result.MAU, &result.InputTokens, &result.OutputTokens,
		&result.EstimatedCostUSD, &result.UpdatedAt,
	)
	if err != nil {
		h.writeDBError(w, r, "Dashboard metrikalarini yuklab bo'lmadi")
		return
	}
	result.DataSource = "PostgreSQL: users, usage_ledger (settled)"
	if !h.audit(r, "read", "overview") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{
		"metrics": result,
		"cache_tokens": map[string]any{
			"status": "unavailable",
			"reason": "AI provider javoblarida caching token usage hozircha olinmaydi.",
		},
		"billing": map[string]any{
			"provider_confirmed_balance": nil,
			"provider_confirmed_spend":   nil,
			"revenue":                    nil,
			"mrr":                        nil,
			"arr":                        nil,
			"status":                     "unavailable",
			"reason":                     "Payment transaction va provider billing API integratsiyasi ulanmagan.",
			"data_source":                "RevenueCat webhook subscription metadata; confirmed payment ledger mavjud emas",
		},
		"days": days,
	})
}

func (h *Handler) Users(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	plan := strings.TrimSpace(r.URL.Query().Get("plan"))
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	limit := queryInt(r, "limit", 25, 100)
	offset := queryInt(r, "offset", 0, 1000000)

	rows, err := h.pool.Query(r.Context(), `
		SELECT u.id::text, u.email, u.full_name, u.status, u.plan_id, u.created_at,
			COALESCE(x.input_tokens, 0), COALESCE(x.output_tokens, 0),
			x.last_activity, COALESCE(s.status, 'none'), s.renews_at
		FROM users u
		LEFT JOIN LATERAL (
			SELECT SUM(input_tokens)::bigint AS input_tokens,
				SUM(output_tokens)::bigint AS output_tokens, MAX(created_at) AS last_activity
			FROM usage_ledger WHERE user_id = u.id AND status = 'settled'
		) x ON TRUE
		LEFT JOIN LATERAL (
			SELECT status, renews_at FROM subscriptions
			WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1
		) s ON TRUE
		WHERE ($1 = '' OR u.email ILIKE '%' || $1 || '%' OR u.full_name ILIKE '%' || $1 || '%')
			AND ($2 = '' OR u.plan_id = $2)
			AND ($3 = '' OR u.status = $3)
		ORDER BY u.created_at DESC LIMIT $4 OFFSET $5
	`, q, plan, status, limit, offset)
	if err != nil {
		h.writeDBError(w, r, "Foydalanuvchilarni yuklab bo'lmadi")
		return
	}
	defer rows.Close()
	users := make([]map[string]any, 0)
	for rows.Next() {
		var id, email, fullName, userStatus, planID, subStatus string
		var createdAt time.Time
		var inputTokens, outputTokens int64
		var lastActivity, renewsAt *time.Time
		if err := rows.Scan(&id, &email, &fullName, &userStatus, &planID, &createdAt,
			&inputTokens, &outputTokens, &lastActivity, &subStatus, &renewsAt); err != nil {
			h.writeDBError(w, r, "Foydalanuvchi ma'lumotlarini o'qib bo'lmadi")
			return
		}
		users = append(users, map[string]any{
			"id": id, "email": email, "full_name": fullName, "status": userStatus,
			"plan_id": planID, "created_at": createdAt, "input_tokens": inputTokens,
			"output_tokens": outputTokens, "last_activity": lastActivity,
			"subscription_status": subStatus, "renews_at": renewsAt,
		})
	}
	if err := rows.Err(); err != nil {
		h.writeDBError(w, r, "Foydalanuvchilar ro'yxatini o'qib bo'lmadi")
		return
	}
	if !h.audit(r, "read", "users") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{
		"users": users, "limit": limit, "offset": offset,
		"data_source": "PostgreSQL: users, usage_ledger, subscriptions",
		"updated_at": time.Now().UTC(),
	})
}

func (h *Handler) UserDetail(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userID")
	var user map[string]any
	var id, email, name, status, planID string
	var createdAt time.Time
	err := h.pool.QueryRow(r.Context(), `
		SELECT id::text, email, full_name, status, plan_id, created_at
		FROM users WHERE id = $1::uuid
	`, userID).Scan(&id, &email, &name, &status, &planID, &createdAt)
	if err == pgx.ErrNoRows {
		apphttp.WriteError(w, r, http.StatusNotFound, "USER_NOT_FOUND", "Foydalanuvchi topilmadi")
		return
	}
	if err != nil {
		h.writeDBError(w, r, "Foydalanuvchini yuklab bo'lmadi")
		return
	}
	user = map[string]any{"id": id, "email": email, "full_name": name, "status": status, "plan_id": planID, "created_at": createdAt}

	var in, out, cachedRead, cachedWrite int64
	var estimated float64
	var generations int64
	err = h.pool.QueryRow(r.Context(), `
		SELECT COALESCE(SUM(input_tokens), 0), COALESCE(SUM(output_tokens), 0),
			COALESCE(SUM(cache_read_tokens), 0), COALESCE(SUM(cache_write_tokens), 0),
			COALESCE(SUM(actual_cost_usd), 0)::double precision, COUNT(*)
		FROM usage_ledger WHERE user_id = $1::uuid AND status = 'settled'
	`, userID).Scan(&in, &out, &cachedRead, &cachedWrite, &estimated, &generations)
	if err != nil {
		h.writeDBError(w, r, "Foydalanuvchi foydalanish metrikalarini yuklab bo'lmadi")
		return
	}
	subRows, err := h.pool.Query(r.Context(), `
		SELECT provider, product_id, plan_id, status, store, environment, renews_at, ends_at, created_at
		FROM subscriptions WHERE user_id = $1::uuid ORDER BY created_at DESC LIMIT 20
	`, userID)
	if err != nil {
		h.writeDBError(w, r, "Obunalarni yuklab bo'lmadi")
		return
	}
	defer subRows.Close()
	subs := make([]map[string]any, 0)
	for subRows.Next() {
		var provider, product, subPlan, subStatus, store, environment string
		var renewsAt, endsAt *time.Time
		var subCreatedAt time.Time
		if err := subRows.Scan(&provider, &product, &subPlan, &subStatus, &store, &environment, &renewsAt, &endsAt, &subCreatedAt); err != nil {
			h.writeDBError(w, r, "Obuna ma'lumotlarini o'qib bo'lmadi")
			return
		}
		subs = append(subs, map[string]any{
			"provider": provider, "product_id": product, "plan_id": subPlan, "status": subStatus,
			"store": store, "environment": environment, "renews_at": renewsAt,
			"ends_at": endsAt, "created_at": subCreatedAt,
		})
	}
	user["usage"] = map[string]any{
		"input_tokens": in, "output_tokens": out, "cache_read_tokens": cachedRead,
		"cache_write_tokens": cachedWrite, "estimated_cost_usd": estimated,
		"provider_confirmed_cost_usd": nil, "generation_count": generations,
		"data_source": "PostgreSQL: usage_ledger; cost is model-price estimate, not provider-confirmed",
	}
	user["subscriptions"] = subs
	user["updated_at"] = time.Now().UTC()
	if !h.audit(r, "read", "users/"+id) {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	user["usage"].(map[string]any)["cache_read_tokens"] = nil
	user["usage"].(map[string]any)["cache_write_tokens"] = nil
	user["usage"].(map[string]any)["cache_tokens_status"] = "unavailable"
	apphttp.WriteJSON(w, http.StatusOK, user)
}

func (h *Handler) Usage(w http.ResponseWriter, r *http.Request) {
	days := queryDays(r)
	rows, err := h.pool.Query(r.Context(), `
		SELECT COALESCE(m.provider, 'unknown'), l.model_id,
			COALESCE(SUM(l.input_tokens), 0)::bigint, COALESCE(SUM(l.output_tokens), 0)::bigint,
			COALESCE(SUM(l.actual_cost_usd), 0)::double precision, COUNT(*)::bigint
		FROM usage_ledger l LEFT JOIN models m ON m.id = l.model_id
		WHERE l.status = 'settled' AND l.created_at >= CURRENT_TIMESTAMP - ($1::int * INTERVAL '1 day')
		GROUP BY m.provider, l.model_id ORDER BY SUM(l.actual_cost_usd) DESC
	`, days)
	if err != nil {
		h.writeDBError(w, r, "AI foydalanish metrikalarini yuklab bo'lmadi")
		return
	}
	defer rows.Close()
	models := make([]map[string]any, 0)
	var input, output int64
	var estimated float64
	for rows.Next() {
		var provider, model string
		var i, o, count int64
		var cost float64
		if err := rows.Scan(&provider, &model, &i, &o, &cost, &count); err != nil {
			h.writeDBError(w, r, "Model metrikalarini o'qib bo'lmadi")
			return
		}
		input += i
		output += o
		estimated += cost
		models = append(models, map[string]any{
			"provider": provider, "model_id": model, "input_tokens": i, "output_tokens": o,
			"cache_read_tokens": nil, "cache_write_tokens": nil, "estimated_cost_usd": cost,
			"token_count_source": "estimated_from_text_length",
			"provider_confirmed_cost_usd": nil, "requests": count,
		})
	}
	if err := rows.Err(); err != nil {
		h.writeDBError(w, r, "Model metrikalari ro'yxatini o'qib bo'lmadi")
		return
	}
	if !h.audit(r, "read", "usage") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{
		"period_days": days,
		"totals": map[string]any{
			"input_tokens": input, "output_tokens": output,
			"cache_read_tokens": nil, "cache_write_tokens": nil,
			"token_count_source": "estimated_from_text_length",
			"estimated_cost_usd": estimated,
			"provider_confirmed_cost_usd": nil,
			"data_source": "PostgreSQL: usage_ledger + models; costs calculated using configured model prices",
		},
		"models": models, "cache_tokens_status": "unavailable", "updated_at": time.Now().UTC(),
	})
}

func (h *Handler) Models(w http.ResponseWriter, r *http.Request) {
	rows, err := h.pool.Query(r.Context(), `
		SELECT id, name, provider, provider_model_id, is_enabled,
			input_price_per_million_usd::double precision,
			output_price_per_million_usd::double precision,
			is_free_tier, created_at
		FROM models ORDER BY provider, name
	`)
	if err != nil {
		h.writeDBError(w, r, "Model katalogini yuklab bo'lmadi")
		return
	}
	defer rows.Close()
	models := make([]map[string]any, 0)
	for rows.Next() {
		var id, name, provider, providerModelID string
		var enabled, freeTier bool
		var inputPrice, outputPrice float64
		var createdAt time.Time
		if err := rows.Scan(&id, &name, &provider, &providerModelID, &enabled,
			&inputPrice, &outputPrice, &freeTier, &createdAt); err != nil {
			h.writeDBError(w, r, "Model ma'lumotlarini o'qib bo'lmadi")
			return
		}
		models = append(models, map[string]any{
			"id": id, "name": name, "provider": provider, "provider_model_id": providerModelID,
			"is_enabled": enabled, "input_price_per_million_usd": inputPrice,
			"output_price_per_million_usd": outputPrice, "is_free_tier": freeTier,
			"created_at": createdAt,
		})
	}
	if err := rows.Err(); err != nil {
		h.writeDBError(w, r, "Model ro'yxatini o'qib bo'lmadi")
		return
	}
	if !h.audit(r, "read", "models") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{
		"models": models,
		"pricing_source": "PostgreSQL: models pricing catalog; prices are configured values, not provider invoices",
		"updated_at": time.Now().UTC(),
	})
}

func (h *Handler) Features(w http.ResponseWriter, r *http.Request) {
	days := queryDays(r)
	rows, err := h.pool.Query(r.Context(), `
		SELECT COALESCE(NULLIF(c.category, ''), 'uncategorized') AS category,
			COUNT(DISTINCT l.generation_id)::bigint AS generations,
			COUNT(DISTINCT l.user_id)::bigint AS users
		FROM usage_ledger l
		JOIN conversations c ON c.id = l.conversation_id
		WHERE l.status = 'settled'
			AND l.created_at >= CURRENT_TIMESTAMP - ($1::int * INTERVAL '1 day')
		GROUP BY category ORDER BY generations DESC
	`, days)
	if err != nil {
		h.writeDBError(w, r, "Funksiya foydalanish metrikalarini yuklab bo'lmadi")
		return
	}
	defer rows.Close()
	features := make([]map[string]any, 0)
	for rows.Next() {
		var category string
		var generations, users int64
		if err := rows.Scan(&category, &generations, &users); err != nil {
			h.writeDBError(w, r, "Funksiya metrikalarini o'qib bo'lmadi")
			return
		}
		features = append(features, map[string]any{
			"category": category, "generations": generations, "users": users,
		})
	}
	if err := rows.Err(); err != nil {
		h.writeDBError(w, r, "Funksiya metrikalari ro'yxatini o'qib bo'lmadi")
		return
	}
	if !h.audit(r, "read", "features") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{
		"features": features, "period_days": days,
		"data_source": "PostgreSQL: conversations.category + settled usage_ledger; no chat content",
		"updated_at": time.Now().UTC(),
	})
}

func (h *Handler) Subscriptions(w http.ResponseWriter, r *http.Request) {
	rows, err := h.pool.Query(r.Context(), `
		SELECT s.id::text, s.user_id::text, u.email, s.provider, s.product_id, s.plan_id,
			s.status, s.store, s.environment, s.renews_at, s.ends_at, s.created_at
		FROM subscriptions s JOIN users u ON u.id = s.user_id
		ORDER BY s.created_at DESC LIMIT 500
	`)
	if err != nil {
		h.writeDBError(w, r, "Obunalarni yuklab bo'lmadi")
		return
	}
	defer rows.Close()
	list := make([]map[string]any, 0)
	for rows.Next() {
		var id, userID, email, provider, product, plan, status, store, environment string
		var renewsAt, endsAt *time.Time
		var createdAt time.Time
		if err := rows.Scan(&id, &userID, &email, &provider, &product, &plan, &status, &store, &environment, &renewsAt, &endsAt, &createdAt); err != nil {
			h.writeDBError(w, r, "Obuna ma'lumotlarini o'qib bo'lmadi")
			return
		}
		list = append(list, map[string]any{
			"id": id, "user_id": userID, "email": email, "provider": provider,
			"product_id": product, "plan_id": plan, "status": status, "store": store,
			"environment": environment, "renews_at": renewsAt, "ends_at": endsAt,
			"created_at": createdAt,
		})
	}
	if err := rows.Err(); err != nil {
		h.writeDBError(w, r, "Obunalar ro'yxatini o'qib bo'lmadi")
		return
	}
	if !h.audit(r, "read", "subscriptions") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{
		"subscriptions": list,
		"payments": map[string]any{
			"status": "unavailable", "transactions": nil, "refunds": nil,
			"reason": "Payment provider transaction va refund API ulanmagan; RevenueCat ma'lumotlari obunani tasdiqlaydi, to'lovni emas.",
		},
		"revenue_usd": nil, "mrr_usd": nil, "arr_usd": nil,
		"data_source": "PostgreSQL: subscriptions (RevenueCat metadata only)",
		"updated_at": time.Now().UTC(),
	})
}

func (h *Handler) System(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	dbStatus := "connected"
	if err := h.pool.Ping(ctx); err != nil {
		dbStatus = "unavailable"
	}
	providerStatus := "unknown"
	if !h.providerConfigured {
		providerStatus = "not_configured"
	}
	var failures int64
	if err := h.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM generations
		WHERE status = 'failed' AND created_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
	`).Scan(&failures); err != nil {
		h.writeDBError(w, r, "Tizim holatini yuklab bo'lmadi")
		return
	}
	if !h.audit(r, "read", "system") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{
		"api": map[string]any{"status": "connected", "source": "Cognidoc API"},
		"database": map[string]any{"status": dbStatus, "source": "PostgreSQL ping"},
		"ai_provider": map[string]any{
			"name": h.providerName, "status": providerStatus, "credentials_configured": h.providerConfigured,
			"source": "Backend configuration; live provider health check is not implemented",
		},
		"payments": map[string]any{"status": "unavailable", "source": "No payment transaction API configured"},
		"failed_generations_24h": failures,
		"api_request_metrics": map[string]any{"status": "unavailable", "reason": "Request telemetry is not persisted"},
		"server_logs": map[string]any{"status": "unavailable", "reason": "Centralized structured log storage is not configured"},
		"updated_at": time.Now().UTC(),
	})
}

func (h *Handler) Audit(w http.ResponseWriter, r *http.Request) {
	rows, err := h.pool.Query(r.Context(), `
		SELECT l.id, l.admin_user_id::text, u.email, l.action, l.resource, l.created_at
		FROM admin_audit_logs l LEFT JOIN users u ON u.id = l.admin_user_id
		ORDER BY l.created_at DESC LIMIT 100
	`)
	if err != nil {
		h.writeDBError(w, r, "Audit jurnalini yuklab bo'lmadi")
		return
	}
	defer rows.Close()
	entries := make([]map[string]any, 0)
	for rows.Next() {
		var id int64
		var userID, email *string
		var action, resource string
		var createdAt time.Time
		if err := rows.Scan(&id, &userID, &email, &action, &resource, &createdAt); err != nil {
			h.writeDBError(w, r, "Audit yozuvlarini o'qib bo'lmadi")
			return
		}
		entries = append(entries, map[string]any{
			"id": id, "admin_user_id": userID, "email": email, "action": action,
			"resource": resource, "created_at": createdAt,
		})
	}
	if err := rows.Err(); err != nil {
		h.writeDBError(w, r, "Audit yozuvlarini o'qib bo'lmadi")
		return
	}
	if !h.audit(r, "read", "audit") {
		h.writeDBError(w, r, "Audit yozuvini saqlab bo'lmadi")
		return
	}
	apphttp.WriteJSON(w, http.StatusOK, map[string]any{"entries": entries, "updated_at": time.Now().UTC()})
}

func (h *Handler) audit(r *http.Request, action, resource string) bool {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		return false
	}
	if _, err := h.pool.Exec(r.Context(), `
		INSERT INTO admin_audit_logs (admin_user_id, action, resource)
		VALUES ($1::uuid, $2, $3)
	`, userID, action, resource); err != nil {
		return false
	}
	return true
}

func (h *Handler) writeDBError(w http.ResponseWriter, r *http.Request, message string) {
	apphttp.WriteError(w, r, http.StatusInternalServerError, "ADMIN_QUERY_FAILED", message)
}

func queryDays(r *http.Request) int {
	return queryInt(r, "days", 30, 365)
}

func queryInt(r *http.Request, key string, fallback, max int) int {
	value, err := strconv.Atoi(r.URL.Query().Get(key))
	if err != nil || value < 0 {
		return fallback
	}
	if value > max {
		return max
	}
	return value
}

func (h *Handler) Routes(r chi.Router) {
	r.Get("/overview", h.Overview)
	r.Get("/users", h.Users)
	r.Get("/users/{userID}", h.UserDetail)
	r.Get("/usage", h.Usage)
	r.Get("/models", h.Models)
	r.Get("/features", h.Features)
	r.Get("/subscriptions", h.Subscriptions)
	r.Get("/system", h.System)
	r.Get("/audit", h.Audit)
}
