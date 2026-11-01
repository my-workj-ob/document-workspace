package billing

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrUnauthorizedWebhook = errors.New("UNAUTHORIZED_WEBHOOK: Invalid or missing authorization token")
	ErrMalformedEvent      = errors.New("MALFORMED_EVENT: Missing required event attributes")
)

// RevenueCatEvent represents the event payload sent by RevenueCat webhooks.
type RevenueCatEvent struct {
	ID                        string   `json:"id"`
	Type                      string   `json:"type"`
	AppUserID                 string   `json:"app_user_id"`
	OriginalAppUserID         string   `json:"original_app_user_id"`
	Aliases                   []string `json:"aliases"`
	ProductID                 string   `json:"product_id"`
	EntitlementID             string   `json:"entitlement_id"`
	EntitlementIDs            []string `json:"entitlement_ids"`
	PurchasedAtMs             int64    `json:"purchased_at_ms"`
	ExpirationAtMs            int64    `json:"expiration_at_ms"`
	Store                     string   `json:"store"`
	Environment               string   `json:"environment"`
	PeriodType                string   `json:"period_type"`
	OriginalTransactionID     string   `json:"original_transaction_id"`
	TransactionID             string   `json:"transaction_id"`
	Currency                  string   `json:"currency"`
	PriceInPurchasedCurrency  float64  `json:"price_in_purchased_currency"`
}

type RevenueCatWebhookPayload struct {
	APIVersion string          `json:"api_version"`
	Event      RevenueCatEvent `json:"event"`
}

// ClientSyncRequest is sent by the mobile app after purchase/restore to synchronize state immediately.
type ClientSyncRequest struct {
	OriginalTransactionID string `json:"original_transaction_id"`
	ProductID             string `json:"product_id"`
	EntitlementID         string `json:"entitlement_id"`
	IsActive              bool   `json:"is_active"`
	ExpirationDate        any    `json:"expiration_date"` // supports string (RFC3339, ISO8601), float64, or nil
	Store                 string `json:"store"`
}

func parseExpirationDate(raw any) *time.Time {
	if raw == nil {
		return nil
	}
	switch v := raw.(type) {
	case string:
		v = strings.TrimSpace(v)
		if v == "" {
			return nil
		}
		layouts := []string{
			time.RFC3339Nano,
			time.RFC3339,
			"2006-01-02T15:04:05.999999999",
			"2006-01-02T15:04:05.999999",
			"2006-01-02T15:04:05",
			"2006-01-02 15:04:05",
			"2006-01-02",
		}
		for _, layout := range layouts {
			if t, err := time.Parse(layout, v); err == nil {
				utc := t.UTC()
				return &utc
			}
		}
	case float64:
		sec := int64(v)
		if sec > 10000000000 {
			sec = sec / 1000
		}
		t := time.Unix(sec, 0).UTC()
		return &t
	}
	return nil
}

// RevenueCatHandler manages webhook processing and subscription synchronization.
type RevenueCatHandler struct {
	pool       *pgxpool.Pool
	authToken  string
	packageName string
}

func NewRevenueCatHandler(pool *pgxpool.Pool, authToken, packageName string) *RevenueCatHandler {
	if packageName == "" {
		packageName = "com.aichat.app.mobile"
	}
	return &RevenueCatHandler{
		pool:        pool,
		authToken:   strings.TrimSpace(authToken),
		packageName: packageName,
	}
}

// VerifyAuthorization verifies the incoming webhook Authorization header using constant-time comparison.
func (h *RevenueCatHandler) VerifyAuthorization(authHeader string) bool {
	if h.authToken == "" {
		log.Println("[WARN] [RevenueCat] REVENUECAT_WEBHOOK_AUTH_TOKEN is not configured; rejecting webhook request (fail-closed)")
		return false
	}

	token := strings.TrimPrefix(authHeader, "Bearer ")
	token = strings.TrimSpace(token)
	return subtle.ConstantTimeCompare([]byte(token), []byte(h.authToken)) == 1
}

// ProcessWebhook processes a RevenueCat webhook event idempotently.
func (h *RevenueCatHandler) ProcessWebhook(ctx context.Context, rawBody []byte, authHeader string) error {
	if !h.VerifyAuthorization(authHeader) {
		return ErrUnauthorizedWebhook
	}

	var payload RevenueCatWebhookPayload
	if err := json.Unmarshal(rawBody, &payload); err != nil {
		return fmt.Errorf("failed to parse RevenueCat webhook JSON: %w", err)
	}

	ev := payload.Event
	if ev.ID == "" || ev.Type == "" {
		return ErrMalformedEvent
	}

	// 1. Idempotency check using webhook_events table
	res, err := h.pool.Exec(ctx, `
		INSERT INTO webhook_events (event_id, event_name, payload)
		VALUES ($1, $2, $3)
		ON CONFLICT (event_id) DO NOTHING
	`, ev.ID, ev.Type, rawBody)
	if err != nil {
		return fmt.Errorf("failed to record webhook idempotency: %w", err)
	}

	if res.RowsAffected() == 0 {
		log.Printf("[INFO] [RevenueCat] Duplicate webhook event %s (%s) ignored", ev.ID, ev.Type)
		return nil
	}

	log.Printf("[INFO] [RevenueCat] Processing webhook event: %s, ID: %s, User: %s, Product: %s",
		ev.Type, ev.ID, ev.AppUserID, ev.ProductID)

	// 2. Resolve User ID
	userID := h.resolveUserID(ctx, &ev)
	if userID == "" {
		log.Printf("[WARN] [RevenueCat] Could not resolve application user_id for app_user_id=%s, original=%s",
			ev.AppUserID, ev.OriginalAppUserID)
		return nil
	}

	// 3. Process according to event type
	switch ev.Type {
	case "INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION":
		return h.handleActiveSubscription(ctx, userID, &ev)

	case "CANCELLATION":
		return h.handleCancellation(ctx, userID, &ev)

	case "EXPIRATION":
		return h.handleExpiration(ctx, userID, &ev)

	case "BILLING_ISSUE":
		return h.handleBillingIssue(ctx, userID, &ev)

	default:
		log.Printf("[INFO] [RevenueCat] Unhandled event type: %s (recorded for audit)", ev.Type)
		return nil
	}
}

// SyncFromClient allows the authenticated mobile app to proactively sync its active entitlement.
// SyncFromClient allows the mobile app to report entitlement state and updates user plan authoritatively.
func (h *RevenueCatHandler) SyncFromClient(ctx context.Context, userID string, req ClientSyncRequest) error {
	if userID == "" {
		return errors.New("userID is required")
	}
	if h.pool == nil {
		return nil
	}

	prodLower := strings.ToLower(req.ProductID)

	// 1. If client reports inactive or resetting to free
	if !req.IsActive || prodLower == "free" {
		// Cancel all active subscriptions
		_, _ = h.pool.Exec(ctx, `
			UPDATE subscriptions 
			SET status = 'canceled', ends_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP 
			WHERE user_id = $1::uuid AND status IN ('active', 'on_trial', 'paused')
		`, userID)

		// Set user plan to free
		_, err := h.pool.Exec(ctx, `
			UPDATE users 
			SET plan_id = 'free', updated_at = CURRENT_TIMESTAMP 
			WHERE id = $1::uuid
		`, userID)
		return err
	}

	// 2. Client is activating or upgrading to Pro or Ultra
	planID := "pro"
	if strings.Contains(prodLower, "ultra") {
		planID = "ultra"
	}

	status := "active"
	origID := req.OriginalTransactionID
	if origID == "" {
		origID = fmt.Sprintf("rc_sync_%s_%d", userID, time.Now().Unix())
	}

	store := req.Store
	if store == "" {
		store = "play_store"
	}

	portalURL := fmt.Sprintf("https://play.google.com/store/account/subscriptions?package=%s", h.packageName)

	var endsAt *time.Time
	if parsed := parseExpirationDate(req.ExpirationDate); parsed != nil {
		endsAt = parsed
	} else {
		// Default 30-day or 1-year window if not provided
		t := time.Now().AddDate(0, 1, 0)
		if strings.Contains(prodLower, "yearly") {
			t = time.Now().AddDate(1, 0, 0)
		} else if strings.Contains(prodLower, "lifetime") {
			t = time.Now().AddDate(100, 0, 0)
		}
		endsAt = &t
	}

	// Cancel previous active subscriptions to avoid plan conflicts
	_, _ = h.pool.Exec(ctx, `
		UPDATE subscriptions 
		SET status = 'canceled', ends_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP 
		WHERE user_id = $1::uuid AND status IN ('active', 'on_trial', 'paused')
	`, userID)

	// Insert authoritative active subscription record
	_, err := h.pool.Exec(ctx, `
		INSERT INTO subscriptions (
			user_id, provider, original_transaction_id, revenuecat_app_user_id,
			product_id, store, plan_id, status, ends_at, customer_portal_url, updated_at
		) VALUES (
			$1::uuid, 'revenuecat', $2, $3, $4, $5, $6, $7, $8, $9, CURRENT_TIMESTAMP
		)
		ON CONFLICT (original_transaction_id) WHERE original_transaction_id IS NOT NULL DO UPDATE SET
			status = EXCLUDED.status,
			ends_at = EXCLUDED.ends_at,
			product_id = EXCLUDED.product_id,
			plan_id = EXCLUDED.plan_id,
			store = EXCLUDED.store,
			customer_portal_url = EXCLUDED.customer_portal_url,
			updated_at = CURRENT_TIMESTAMP
	`, userID, origID, userID, req.ProductID, store, planID, status, endsAt, portalURL)
	if err != nil {
		// Fallback in case table has standard unique constraint without partial WHERE index
		_, err2 := h.pool.Exec(ctx, `
			INSERT INTO subscriptions (
				user_id, provider, original_transaction_id, revenuecat_app_user_id,
				product_id, store, plan_id, status, ends_at, customer_portal_url, updated_at
			) VALUES (
				$1::uuid, 'revenuecat', $2, $3, $4, $5, $6, $7, $8, $9, CURRENT_TIMESTAMP
			)
			ON CONFLICT (original_transaction_id) DO UPDATE SET
				status = EXCLUDED.status,
				ends_at = EXCLUDED.ends_at,
				product_id = EXCLUDED.product_id,
				plan_id = EXCLUDED.plan_id,
				store = EXCLUDED.store,
				customer_portal_url = EXCLUDED.customer_portal_url,
				updated_at = CURRENT_TIMESTAMP
		`, userID, origID, userID, req.ProductID, store, planID, status, endsAt, portalURL)
		if err2 != nil {
			log.Printf("[WARN] [RevenueCat] Failed to upsert subscription row: %v (err1: %v)", err2, err)
		}
	}

	// Update user's direct plan_id in users table
	_, err = h.pool.Exec(ctx, `
		UPDATE users 
		SET plan_id = $1, updated_at = CURRENT_TIMESTAMP 
		WHERE id = $2::uuid
	`, planID, userID)
	return err
}

func (h *RevenueCatHandler) handleActiveSubscription(ctx context.Context, userID string, ev *RevenueCatEvent) error {
	status := "active"
	if strings.ToUpper(ev.PeriodType) == "TRIAL" {
		status = "on_trial"
	}

	var endsAt *time.Time
	if ev.ExpirationAtMs > 0 {
		t := time.UnixMilli(ev.ExpirationAtMs)
		endsAt = &t
	}

	var renewsAt *time.Time
	if ev.PurchasedAtMs > 0 {
		t := time.UnixMilli(ev.PurchasedAtMs)
		renewsAt = &t
	}

	origTransID := ev.OriginalTransactionID
	if origTransID == "" {
		origTransID = ev.TransactionID
	}
	if origTransID == "" {
		origTransID = "rc_" + ev.ID
	}

	portalURL := fmt.Sprintf("https://play.google.com/store/account/subscriptions?package=%s", h.packageName)
	testMode := strings.ToUpper(ev.Environment) == "SANDBOX"

	planID := "pro"
	if strings.Contains(strings.ToLower(ev.ProductID), "ultra") {
		planID = "ultra"
	}

	_, err := h.pool.Exec(ctx, `
		INSERT INTO subscriptions (
			user_id, provider, original_transaction_id, revenuecat_app_user_id,
			product_id, store, environment, plan_id, status, renews_at, ends_at,
			customer_portal_url, test_mode, updated_at
		) VALUES (
			$1::uuid, 'revenuecat', $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, CURRENT_TIMESTAMP
		)
		ON CONFLICT (original_transaction_id) WHERE original_transaction_id IS NOT NULL DO UPDATE SET
			status = EXCLUDED.status,
			renews_at = EXCLUDED.renews_at,
			ends_at = EXCLUDED.ends_at,
			product_id = EXCLUDED.product_id,
			plan_id = EXCLUDED.plan_id,
			environment = EXCLUDED.environment,
			customer_portal_url = COALESCE(EXCLUDED.customer_portal_url, subscriptions.customer_portal_url),
			updated_at = CURRENT_TIMESTAMP
	`, userID, origTransID, ev.AppUserID, ev.ProductID, ev.Store, ev.Environment,
		planID, status, renewsAt, endsAt, portalURL, testMode)
	if err != nil {
		return fmt.Errorf("failed to upsert RevenueCat subscription: %w", err)
	}

	// Upgrade user to PRO or ULTRA
	_, err = h.pool.Exec(ctx, `UPDATE users SET plan_id = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`, planID, userID)
	log.Printf("[INFO] [RevenueCat] User %s granted %s plan (status=%s, origID=%s)", userID, strings.ToUpper(planID), status, origTransID)
	return err
}

func (h *RevenueCatHandler) handleCancellation(ctx context.Context, userID string, ev *RevenueCatEvent) error {
	origTransID := ev.OriginalTransactionID
	if origTransID == "" {
		origTransID = ev.TransactionID
	}

	var endsAt *time.Time
	if ev.ExpirationAtMs > 0 {
		t := time.UnixMilli(ev.ExpirationAtMs)
		endsAt = &t
	}

	// In RevenueCat, cancellation means auto-renew is off, but Pro access remains active until ends_at!
	_, err := h.pool.Exec(ctx, `
		UPDATE subscriptions 
		SET status = 'cancelled', ends_at = COALESCE($1, ends_at), updated_at = CURRENT_TIMESTAMP
		WHERE original_transaction_id = $2 OR (user_id = $3 AND provider = 'revenuecat')
	`, endsAt, origTransID, userID)

	log.Printf("[INFO] [RevenueCat] Subscription %s cancelled for user %s (valid until %v)", origTransID, userID, endsAt)
	return err
}

func (h *RevenueCatHandler) handleExpiration(ctx context.Context, userID string, ev *RevenueCatEvent) error {
	origTransID := ev.OriginalTransactionID
	if origTransID == "" {
		origTransID = ev.TransactionID
	}

	_, err := h.pool.Exec(ctx, `
		UPDATE subscriptions 
		SET status = 'expired', updated_at = CURRENT_TIMESTAMP
		WHERE original_transaction_id = $1 OR (user_id = $2 AND provider = 'revenuecat')
	`, origTransID, userID)

	// Demote user to free plan
	_, _ = h.pool.Exec(ctx, `UPDATE users SET plan_id = 'free', updated_at = CURRENT_TIMESTAMP WHERE id = $1`, userID)
	log.Printf("[INFO] [RevenueCat] Subscription expired for user %s. Reverted to FREE plan", userID)
	return err
}

func (h *RevenueCatHandler) handleBillingIssue(ctx context.Context, userID string, ev *RevenueCatEvent) error {
	origTransID := ev.OriginalTransactionID
	if origTransID == "" {
		origTransID = ev.TransactionID
	}

	_, err := h.pool.Exec(ctx, `
		UPDATE subscriptions 
		SET status = 'past_due', updated_at = CURRENT_TIMESTAMP
		WHERE original_transaction_id = $1 OR (user_id = $2 AND provider = 'revenuecat')
	`, origTransID, userID)
	return err
}

func (h *RevenueCatHandler) resolveUserID(ctx context.Context, ev *RevenueCatEvent) string {
	candidates := []string{ev.AppUserID, ev.OriginalAppUserID}
	candidates = append(candidates, ev.Aliases...)

	for _, c := range candidates {
		trimmed := strings.TrimSpace(c)
		if trimmed == "" {
			continue
		}

		// 1. Direct match on users.id
		var uid string
		err := h.pool.QueryRow(ctx, `SELECT id FROM users WHERE id::text = $1`, trimmed).Scan(&uid)
		if err == nil && uid != "" {
			return uid
		}

		// 2. Match on users.email if app_user_id was passed as email
		err = h.pool.QueryRow(ctx, `SELECT id FROM users WHERE LOWER(email) = LOWER($1)`, trimmed).Scan(&uid)
		if err == nil && uid != "" {
			return uid
		}
	}

	// 3. Fallback: match by existing original_transaction_id
	origID := ev.OriginalTransactionID
	if origID != "" {
		var uid string
		err := h.pool.QueryRow(ctx, `
			SELECT user_id FROM subscriptions 
			WHERE original_transaction_id = $1
		`, origID).Scan(&uid)
		if err == nil && uid != "" {
			return uid
		}
	}

	return ""
}
