# Cognidoc AI Admin Panel

The admin panel is a separate Next.js application. Its API reads PostgreSQL records from the existing Go service; it never queries chat messages or conversation content.

## Local setup

1. Start the Go API as described in [development.md](./development.md). Startup creates the admin analytics schema. Apply `backend/migrations/000006_admin_analytics.up.sql` through the normal migration process when deploying a database separately.
2. Register an account through the existing Cognidoc API, then grant that account an admin role using a trusted database connection:

   ```sql
   INSERT INTO admin_users (user_id, role)
   SELECT id, 'admin'
   FROM users
   WHERE LOWER(email) = LOWER('admin@example.com')
   ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role;
   ```

   The `analyst` and `read_only` roles are also supported. All current admin API operations are read-only.
3. Configure `frontend/admin-panel/.env.local` from `.env.example` if the API is not at `http://localhost:8080`.
4. Run `npm install` and `npm run dev` from `frontend/admin-panel`.
5. Sign in with the granted account. Access tokens and refresh tokens are held only in page memory; signing out revokes the refresh session. Reloading the page requires signing in again.

## API

All endpoints require the existing bearer access token and a matching `admin_users` entry. The API checks the role against PostgreSQL on every request and records successful reads in `admin_audit_logs`.

- `GET /api/v1/admin/overview`
- `GET /api/v1/admin/users?q=&plan=&status=&limit=&offset=`
- `GET /api/v1/admin/users/{userID}`
- `GET /api/v1/admin/usage?days=`
- `GET /api/v1/admin/features?days=`
- `GET /api/v1/admin/models`
- `GET /api/v1/admin/subscriptions`
- `GET /api/v1/admin/system`
- `GET /api/v1/admin/audit`

## Data interpretation and current integrations

- User activity is based on settled usage-ledger records. DAU is the number of users with settled usage since the current UTC database day; WAU/MAU use rolling 7/30-day windows. “Active” means a settled usage record in the last 30 days.
- Current generation token counts are estimated by the backend from text length. They are not provider-reported token counts. Caching usage is not collected and is shown as unavailable.
- `usage_ledger.actual_cost_usd` is currently calculated from configured model catalog rates. The admin API exposes it as an estimated cost; it is not represented as a provider invoice or confirmed spend.
- RevenueCat webhook records confirm subscription lifecycle metadata only. There is no payment transaction/refund ledger or provider billing API in this repository, so revenue, MRR, ARR, provider balance, and provider-confirmed spend remain unavailable.
- Provider health is unknown when credentials are configured because the backend does not perform a live provider health request. Request telemetry and centralized server-log storage are not configured.
- The model and price catalog is read from the database. Catalog prices are configured values, not verified provider invoices.

These unavailable values are intentionally returned as `null` or an explicit unavailable status rather than fabricated values.

## Web site

The SEO-focused Cognidoc landing page is a separate Next.js application under `frontend/web-site`. Run it with `npm install` and `npm run dev` in that directory. The web application is kept separate from the marketing site so future authenticated product surfaces can be added without coupling them to the public landing page.
