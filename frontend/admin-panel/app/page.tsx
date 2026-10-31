"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

type Data = Record<string, unknown>;
type Section = "overview" | "users" | "usage" | "subscriptions" | "system" | "audit";

const API_BASE = (process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8080").replace(/\/$/, "");
const sections: { id: Section; label: string; icon: string }[] = [
  { id: "overview", label: "Overview", icon: "◫" },
  { id: "users", label: "Foydalanuvchilar", icon: "♙" },
  { id: "usage", label: "AI foydalanish", icon: "✳" },
  { id: "subscriptions", label: "Obunalar", icon: "▤" },
  { id: "system", label: "Tizim holati", icon: "⌘" },
  { id: "audit", label: "Audit jurnali", icon: "≡" },
];

function object(value: unknown): Data {
  return value && typeof value === "object" ? value as Data : {};
}
function list(value: unknown): Data[] {
  return Array.isArray(value) ? value.map(object) : [];
}
function text(value: unknown, fallback = "—"): string {
  return value === null || value === undefined || value === "" ? fallback : String(value);
}
function number(value: unknown): number {
  return typeof value === "number" ? value : Number(value || 0);
}
function formatNumber(value: unknown): string {
  return number(value).toLocaleString("en-US");
}
function date(value: unknown): string {
  if (!value) return "—";
  const parsed = new Date(String(value));
  return Number.isNaN(parsed.valueOf()) ? "—" : parsed.toLocaleString();
}
function apiError(body: Data, fallback: string): string {
  const err = object(body.error);
  return text(err.message, fallback);
}

export default function AdminHome() {
  const [token, setToken] = useState("");
  const [refreshToken, setRefreshToken] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loginError, setLoginError] = useState("");
  const [busy, setBusy] = useState(false);
  const [section, setSection] = useState<Section>("overview");
  const [dark, setDark] = useState(true);
  const [payload, setPayload] = useState<Data>({});
  const [error, setError] = useState("");
  const [lastUpdated, setLastUpdated] = useState("");
  const [query, setQuery] = useState("");
  const [planFilter, setPlanFilter] = useState("");
  const [selectedUser, setSelectedUser] = useState<Data | null>(null);
  const [days, setDays] = useState("30");

  const load = useCallback(async (activeToken: string, activeSection: Section, activeDays: string, q: string, plan: string) => {
    const params = new URLSearchParams();
    let path = `/api/v1/admin/${activeSection}`;
    if (activeSection === "overview" || activeSection === "usage") params.set("days", activeDays);
    if (activeSection === "users") {
      if (q) params.set("q", q);
      if (plan) params.set("plan", plan);
      params.set("limit", "100");
    }
    if (params.size) path += `?${params}`;
    setError("");
    try {
      const response = await fetch(`${API_BASE}${path}`, {
        headers: { Authorization: `Bearer ${activeToken}`, Accept: "application/json" },
        cache: "no-store",
      });
      const body = object(await response.json());
      if (!response.ok) {
        if (response.status === 401) signOut();
        throw new Error(apiError(body, `API xatosi (${response.status})`));
      }
      setPayload(object(body.data));
      setLastUpdated(new Date().toISOString());
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Server bilan bog‘lanib bo‘lmadi.");
    }
  // signOut is intentionally stable and only clears in-memory credentials.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function signOut() {
    if (refreshToken) {
      void fetch(`${API_BASE}/api/v1/auth/logout`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refreshToken }),
      }).catch(() => undefined);
    }
    setToken("");
    setRefreshToken("");
    setPayload({});
    setSelectedUser(null);
  }

  useEffect(() => {
    if (!token) return;
    void load(token, section, days, query, planFilter);
    const timer = window.setInterval(() => void load(token, section, days, query, planFilter), 60_000);
    return () => window.clearInterval(timer);
  }, [token, section, days, query, planFilter, load]);

  async function login(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setLoginError("");
    try {
      const response = await fetch(`${API_BASE}/api/v1/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const body = object(await response.json());
      if (!response.ok) throw new Error(apiError(body, "Email yoki parol noto‘g‘ri."));
      const auth = object(body.data);
      if (typeof auth.access_token !== "string") throw new Error("Autentifikatsiya javobida access token topilmadi.");
      const accessToken = auth.access_token;
      const sessionRefresh = text(auth.refresh_token, "");
      const check = await fetch(`${API_BASE}/api/v1/admin/overview`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        cache: "no-store",
      });
      if (check.status === 403) {
        if (sessionRefresh) {
          await fetch(`${API_BASE}/api/v1/auth/logout`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ refresh_token: sessionRefresh }),
          });
        }
        throw new Error("Bu hisobga admin ruxsati berilmagan.");
      }
      if (!check.ok) {
        const checkBody = object(await check.json());
        throw new Error(apiError(checkBody, "Admin sessiyasini tekshirib bo‘lmadi."));
      }
      setToken(accessToken);
      setRefreshToken(sessionRefresh);
      setPassword("");
    } catch (reason) {
      setLoginError(reason instanceof Error ? reason.message : "Kirish amalga oshmadi.");
    } finally {
      setBusy(false);
    }
  }

  async function openUser(user: Data) {
    if (!token) return;
    setSelectedUser({ ...user, loading: true });
    try {
      const response = await fetch(`${API_BASE}/api/v1/admin/users/${encodeURIComponent(text(user.id, ""))}`, {
        headers: { Authorization: `Bearer ${token}` }, cache: "no-store",
      });
      const body = object(await response.json());
      if (!response.ok) throw new Error(apiError(body, "Profil ma’lumotlari yuklanmadi."));
      setSelectedUser(object(body.data));
    } catch (reason) {
      setSelectedUser({ error: reason instanceof Error ? reason.message : "Xatolik." });
    }
  }

  if (!token) {
    return (
      <main className="login-screen">
        <form className="login-card" onSubmit={login}>
          <div className="brand-mark">c</div>
          <p className="eyebrow">COGNIDOC AI</p>
          <h1>Admin panelga kirish</h1>
          <p className="muted">Admin ruxsati biriktirilgan hisob bilan davom eting.</p>
          <label>Email<input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} /></label>
          <label>Parol<input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} /></label>
          {loginError && <p className="error-box">{loginError}</p>}
          <button className="primary full" disabled={busy}>{busy ? "Tekshirilmoqda…" : "Kirish"}</button>
          <p className="security-note">Sessiya tokeni faqat xotirada saqlanadi va sahifa yopilganda o‘chadi.</p>
        </form>
      </main>
    );
  }

  const activeSection = sections.find((item) => item.id === section)?.label ?? "Overview";
  return (
    <div className={`app-shell ${dark ? "theme-dark" : "theme-light"}`}>
      <aside className="sidebar">
        <div className="brand"><div className="brand-mark">c</div><span>Cognidoc <b>AI</b></span></div>
        <div className="workspace-label">WORKSPACE</div>
        <nav>
          {sections.map((item) => (
            <button key={item.id} className={`nav-item ${section === item.id ? "selected" : ""}`} onClick={() => setSection(item.id)}>
              <span className="nav-icon">{item.icon}</span>{item.label}
              {section === item.id && <i />}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="secure-tag"><span className="online-dot" /> Real ma’lumotlar<br /><small>Ma’lumotlar bazasidan</small></div>
          <button className="nav-item signout" onClick={signOut}><span className="nav-icon">↪</span>Chiqish</button>
          <div className="profile"><div className="avatar">{email.charAt(0).toUpperCase()}</div><div><b>{email}</b><small>Administrator</small></div><span>···</span></div>
        </div>
      </aside>

      <main className="main-area">
        <header className="topbar">
          <div className="breadcrumb"><span>Workspace</span><b>/</b><strong>{activeSection}</strong></div>
          <div className="top-actions">
            <span className="live-status"><i /> Live data</span>
            <button className="icon-button" aria-label="Rang rejimini almashtirish" onClick={() => setDark(!dark)}>{dark ? "☼" : "◐"}</button>
            <button className="icon-button" aria-label="Yangilash" onClick={() => void load(token, section, days, query, planFilter)}>↻</button>
          </div>
        </header>
        <div className="content">
          <div className="page-heading">
            <div><p className="eyebrow">COGNIDOC AI / CONTROL CENTER</p><h1>{activeSection}</h1><p className="muted">Real vaqtdagi mahsulot va foydalanish ko‘rsatkichlari.</p></div>
            {(section === "overview" || section === "usage") && <select className="select period" value={days} onChange={(e) => setDays(e.target.value)} aria-label="Davr">
              <option value="7">So‘nggi 7 kun</option><option value="30">So‘nggi 30 kun</option><option value="90">So‘nggi 90 kun</option>
            </select>}
          </div>
          {lastUpdated && <div className="freshness">Ma’lumot yangilandi: {date(lastUpdated)} <span>·</span> Manba: backend PostgreSQL</div>}
          {error && <div className="error-box page-error"><b>Ma’lumot yuklanmadi</b><br />{error}</div>}
          {!error && Object.keys(payload).length === 0 && <div className="loading-panel">Haqiqiy ma’lumotlar yuklanmoqda…</div>}
          {!error && Object.keys(payload).length > 0 && (
            <>
              {section === "overview" && <Overview data={payload} onNavigate={setSection} />}
              {section === "users" && <Users data={payload} query={query} setQuery={setQuery} plan={planFilter} setPlan={setPlanFilter} onOpen={openUser} />}
              {section === "usage" && <Usage data={payload} token={token} />}
              {section === "subscriptions" && <Subscriptions data={payload} />}
              {section === "system" && <System data={payload} />}
              {section === "audit" && <Audit data={payload} />}
            </>
          )}
        </div>
      </main>
      {selectedUser && <UserModal data={selectedUser} onClose={() => setSelectedUser(null)} />}
    </div>
  );
}

function MetricCard({ label, value, note, icon }: { label: string; value: string; note: string; icon: string }) {
  return <article className="metric-card"><div className="metric-top"><span>{label}</span><b>{icon}</b></div><strong>{value}</strong><small>{note}</small></article>;
}

function Overview({ data, onNavigate }: { data: Data; onNavigate: (s: Section) => void }) {
  const metrics = object(data.metrics);
  const billing = object(data.billing);
  return <>
    <div className="metric-grid">
      <MetricCard label="Jami foydalanuvchilar" value={formatNumber(metrics.total_users)} note={`+${formatNumber(metrics.new_users)} tanlangan davrda`} icon="♙" />
      <MetricCard label="Faol foydalanuvchilar" value={formatNumber(metrics.active_users)} note="Oxirgi 30 kunda foydalanish bo‘yicha" icon="↗" />
      <MetricCard label="DAU / WAU / MAU" value={`${formatNumber(metrics.dau)} / ${formatNumber(metrics.wau)} / ${formatNumber(metrics.mau)}`} note="Muvaffaqiyatli AI foydalanishi" icon="◷" />
      <MetricCard label="Taxminiy AI xarajati" value={`$${number(metrics.estimated_cost_usd).toFixed(4)}`} note="Model katalogidagi narx bilan hisoblangan" icon="$" />
    </div>
    <div className="two-column">
      <section className="panel">
        <PanelTitle title="Token sarfi" subtitle="Muvaffaqiyatli so‘rovlar · chat matni saqlanmaydi" />
        <div className="token-summary"><div><small>INPUT TOKENS</small><b>{formatNumber(metrics.input_tokens)}</b></div><div><small>OUTPUT TOKENS</small><b>{formatNumber(metrics.output_tokens)}</b></div></div>
        <div className="notice"><span>ⓘ</span><p>Tokenlar amaldagi hisoblash usulidan olingan. Provider tomonidan tasdiqlangan usage va cached tokenlar mavjud emas.</p></div>
        <button className="text-button" onClick={() => onNavigate("usage")}>AI usage tafsilotlari <span>→</span></button>
      </section>
      <section className="panel finance-panel">
        <PanelTitle title="Moliyaviy holat" subtitle="Faqat provider tasdiqlagan ma’lumot ko‘rsatiladi" />
        <div className="unknown-balance"><div className="unknown-icon">?</div><div><small>PROVIDER BALANSI</small><b>UNKNOWN</b></div></div>
        <p className="muted small">{text(billing.reason)}</p>
        <div className="finance-row"><span>Revenue / MRR / ARR</span><b className="unknown">Mavjud emas</b></div>
        <button className="text-button" onClick={() => onNavigate("subscriptions")}>Billing tafsilotlari <span>→</span></button>
      </section>
    </div>
    <div className="panel segment-panel">
      <PanelTitle title="Foydalanuvchilar segmenti" subtitle="Jami ro‘yxatdan o‘tgan hisoblar" />
      <div className="segment-row"><div className="segment-line"><span style={{ width: `${metrics.total_users ? Math.max(4, number(metrics.active_users) / number(metrics.total_users) * 100) : 0}%` }} /></div></div>
      <div className="segment-legend"><span><i className="green-dot" /> Faol <b>{formatNumber(metrics.active_users)}</b></span><span><i className="gray-dot" /> Faol emas <b>{formatNumber(metrics.inactive_users)}</b></span><button className="text-button" onClick={() => onNavigate("users")}>Barchasi →</button></div>
    </div>
    <p className="disclaimer">Manba: {text(metrics.data_source)} · yangilanish: {date(metrics.updated_at)}. Xarajatlar hisob-kitob, provider invoice’i emas.</p>
  </>;
}

function PanelTitle({ title, subtitle }: { title: string; subtitle: string }) {
  return <div className="panel-title"><div><h2>{title}</h2><p>{subtitle}</p></div><span className="panel-more">···</span></div>;
}

function Users({ data, query, setQuery, plan, setPlan, onOpen }: { data: Data; query: string; setQuery: (s: string) => void; plan: string; setPlan: (s: string) => void; onOpen: (user: Data) => void }) {
  const users = list(data.users);
  return <section className="panel table-panel">
    <div className="table-heading"><div><h2>Barcha foydalanuvchilar</h2><p>Email, tarif va foydalanish ko‘rsatkichlari. Chat mazmuni ko‘rsatilmaydi.</p></div><span className="count-pill">{users.length} natija</span></div>
    <div className="filters"><label className="search"><span>⌕</span><input placeholder="Ism yoki email bo‘yicha qidirish" value={query} onChange={(e) => setQuery(e.target.value)} /></label>
      <select className="select" value={plan} onChange={(e) => setPlan(e.target.value)}><option value="">Barcha tariflar</option><option value="free">Free</option><option value="pro">Pro</option><option value="ultra">Ultra</option></select>
    </div>
    <div className="table-wrap"><table><thead><tr><th>FOYDALANUVCHI</th><th>TARIF</th><th>HOLAT</th><th>INPUT / OUTPUT</th><th>SO‘NGGI FAOLLIK</th><th>RO‘YXATDAN O‘TGAN</th><th /></tr></thead>
      <tbody>{users.map((u) => <tr key={text(u.id)} onClick={() => onOpen(u)} className="clickable-row"><td><div className="user-cell"><div className="avatar">{text(u.full_name, text(u.email, "?")).charAt(0).toUpperCase()}</div><div><b>{text(u.full_name)}</b><small>{text(u.email)}</small></div></div></td><td><span className={`plan-badge ${text(u.plan_id, "free")}`}>{text(u.plan_id, "free")}</span></td><td><span className={`status ${text(u.status)}`}>{text(u.status)}</span></td><td>{formatNumber(u.input_tokens)} / {formatNumber(u.output_tokens)}</td><td>{date(u.last_activity)}</td><td>{date(u.created_at)}</td><td><span className="row-arrow">↗</span></td></tr>)}</tbody>
    </table>{users.length === 0 && <div className="empty-state">Mos foydalanuvchilar topilmadi.</div>}</div>
    <div className="table-footer">Manba: {text(data.data_source)} <span>·</span> Yangilangan: {date(data.updated_at)}</div>
  </section>;
}

function Usage({ data, token }: { data: Data; token: string }) {
  const totals = object(data.totals);
  const models = list(data.models);
  const [catalog, setCatalog] = useState<Data>({});
  const [features, setFeatures] = useState<Data>({});
  useEffect(() => {
    const headers = { Authorization: `Bearer ${token}` };
    void Promise.all([
      fetch(`${API_BASE}/api/v1/admin/models`, { headers, cache: "no-store" }).then((r) => r.json()),
      fetch(`${API_BASE}/api/v1/admin/features?days=${text(data.period_days, "30")}`, { headers, cache: "no-store" }).then((r) => r.json()),
    ]).then(([m, f]) => {
      setCatalog(object(object(m).data));
      setFeatures(object(object(f).data));
    }).catch(() => undefined);
  }, [token, data.period_days]);
  return <>
    <div className="metric-grid three">
      <MetricCard label="Input tokenlar" value={formatNumber(totals.input_tokens)} note="Taxminiy · backend ledger" icon="↓" />
      <MetricCard label="Output tokenlar" value={formatNumber(totals.output_tokens)} note="Taxminiy · backend ledger" icon="↑" />
      <MetricCard label="Hisoblangan xarajat" value={`$${number(totals.estimated_cost_usd).toFixed(4)}`} note="Model narxlari bo‘yicha taxmin" icon="$" />
    </div>
    <div className="two-column">
      <section className="panel"><PanelTitle title="Model bo‘yicha foydalanish" subtitle="Token, request va model narxidan hisoblangan qiymat" />
        <div className="table-wrap"><table><thead><tr><th>PROVIDER / MODEL</th><th>REQUEST</th><th>INPUT TOKENS</th><th>OUTPUT TOKENS</th><th>EST. COST</th></tr></thead><tbody>
          {models.map((m) => <tr key={text(m.model_id)}><td><b>{text(m.model_id)}</b><small className="sub-cell">{text(m.provider)}</small></td><td>{formatNumber(m.requests)}</td><td>{formatNumber(m.input_tokens)}</td><td>{formatNumber(m.output_tokens)}</td><td>${number(m.estimated_cost_usd).toFixed(5)}</td></tr>)}
        </tbody></table>{models.length === 0 && <div className="empty-state">Tanlangan davrda usage yozuvi yo‘q.</div>}</div>
        <div className="notice"><span>ⓘ</span><p>{text(totals.data_source)}. Provider tasdiqlagan xarajat: <b>UNKNOWN</b>; cached tokenlar kuzatilmaydi.</p></div>
      </section>
      <section className="panel"><PanelTitle title="Funksiya kategoriyalari" subtitle="Suhbat kategoriyasi bo‘yicha usage agregati" />
        <div className="feature-list">{list(features.features).map((f) => <div className="feature-row" key={text(f.category)}><span>{text(f.category)}</span><b>{formatNumber(f.generations)} foydalanish</b><small>{formatNumber(f.users)} foydalanuvchi</small></div>)}
          {list(features.features).length === 0 && <div className="empty-state">Kategoriyalar bo‘yicha usage mavjud emas.</div>}</div>
      </section>
    </div>
    <section className="panel"><PanelTitle title="Model katalogi va narxlar" subtitle={text(catalog.pricing_source)} />
      <div className="table-wrap"><table><thead><tr><th>MODEL</th><th>PROVIDER</th><th>HOLAT</th><th>INPUT / 1M</th><th>OUTPUT / 1M</th></tr></thead><tbody>
        {list(catalog.models).map((m) => <tr key={text(m.id)}><td><b>{text(m.name)}</b><small className="sub-cell">{text(m.provider_model_id)}</small></td><td>{text(m.provider)}</td><td><span className={`status ${m.is_enabled ? "active" : "inactive"}`}>{m.is_enabled ? "enabled" : "disabled"}</span></td><td>${number(m.input_price_per_million_usd).toFixed(4)}</td><td>${number(m.output_price_per_million_usd).toFixed(4)}</td></tr>)}
      </tbody></table></div><div className="table-footer">Narxlar database katalogidan olinadi; ular provider invoice’ini anglatmaydi.</div>
    </section>
  </>;
}

function Subscriptions({ data }: { data: Data }) {
  const payments = object(data.payments);
  const subs = list(data.subscriptions);
  return <>
    <div className="notice warning"><span>!</span><p><b>To‘lovlar mavjud emas.</b> {text(payments.reason)} RevenueCat holati to‘lov tranzaksiyasi yoki refund isboti hisoblanmaydi.</p></div>
    <div className="metric-grid three">
      <MetricCard label="Obunalar" value={formatNumber(subs.length)} note="Database’dagi subscription yozuvlari" icon="▤" />
      <MetricCard label="MRR / ARR" value="UNKNOWN" note="Tasdiqlangan billing ma’lumoti yo‘q" icon="$" />
      <MetricCard label="Refund / transactions" value="Mavjud emas" note="To‘lov provider API ulanmagan" icon="↺" />
    </div>
    <section className="panel table-panel"><PanelTitle title="Obunalar" subtitle={text(data.data_source)} />
      <div className="table-wrap"><table><thead><tr><th>FOYDALANUVCHI</th><th>PROVIDER</th><th>PLAN / PRODUCT</th><th>STATUS</th><th>STORE</th><th>RENEWS</th><th>CREATED</th></tr></thead><tbody>
        {subs.map((s) => <tr key={text(s.id)}><td><b>{text(s.email)}</b></td><td>{text(s.provider)}</td><td>{text(s.plan_id)}<small className="sub-cell">{text(s.product_id)}</small></td><td><span className={`status ${text(s.status)}`}>{text(s.status)}</span></td><td>{text(s.store)}</td><td>{date(s.renews_at)}</td><td>{date(s.created_at)}</td></tr>)}
      </tbody></table>{subs.length === 0 && <div className="empty-state">Obuna yozuvlari topilmadi.</div>}</div>
      <div className="table-footer">Obuna davri plan/product metama’lumotidan aniqlanmaydi va ataylab taxmin qilinmaydi.</div>
    </section>
  </>;
}

function System({ data }: { data: Data }) {
  const api = object(data.api), db = object(data.database), ai = object(data.ai_provider);
  const pay = object(data.payments), requests = object(data.api_request_metrics), logs = object(data.server_logs);
  const rows = [
    { name: "Backend API", value: api.status, detail: text(api.source) },
    { name: "PostgreSQL", value: db.status, detail: text(db.source) },
    { name: `AI provider · ${text(ai.name)}`, value: ai.status, detail: text(ai.source) },
    { name: "Payment provider", value: pay.status, detail: text(pay.source) },
    { name: "Request telemetry", value: requests.status, detail: text(requests.reason) },
    { name: "Server logs", value: logs.status, detail: text(logs.reason) },
  ];
  return <>
    <div className="metric-grid three">
      <MetricCard label="Database" value={text(db.status)} note="Live PostgreSQL ping" icon="◉" />
      <MetricCard label="AI provider" value={text(ai.status)} note={ai.credentials_configured ? "Credentials configured; live health is unknown" : "Credentials not configured"} icon="✳" />
      <MetricCard label="Failed generations · 24h" value={formatNumber(data.failed_generations_24h)} note="Generation status metrikasi" icon="!" />
    </div>
    <section className="panel"><PanelTitle title="Komponentlar" subtitle="Tekshiruv va kuzatuv holati" />
      <div className="health-list">{rows.map((row) => <div className="health-row" key={row.name}><span className={`health-indicator ${row.value === "connected" ? "ok" : row.value === "unavailable" || row.value === "not_configured" ? "off" : "unknown"}`} /><div><b>{row.name}</b><small>{row.detail}</small></div><span className={`status ${row.value}`}>{row.value}</span></div>)}</div>
    </section>
    <p className="disclaimer">AI provider uchun live request health-check yo‘q; konfiguratsiya mavjudligi provider sog‘lom ekanini tasdiqlamaydi.</p>
  </>;
}

function Audit({ data }: { data: Data }) {
  const entries = list(data.entries);
  return <section className="panel table-panel"><PanelTitle title="Admin audit jurnali" subtitle="Admin paneldagi ma’lumot o‘qish so‘rovlari · chat matni qayd etilmaydi" />
    <div className="table-wrap"><table><thead><tr><th>VAQT</th><th>ADMIN</th><th>AMAL</th><th>RESURS</th></tr></thead><tbody>
      {entries.map((e) => <tr key={text(e.id)}><td>{date(e.created_at)}</td><td>{text(e.email)}</td><td><span className="status active">{text(e.action)}</span></td><td>{text(e.resource)}</td></tr>)}
    </tbody></table>{entries.length === 0 && <div className="empty-state">Audit yozuvlari mavjud emas.</div>}</div>
  </section>;
}

function UserModal({ data, onClose }: { data: Data; onClose: () => void }) {
  const usage = object(data.usage);
  const subs = list(data.subscriptions);
  const sub = useMemo(() => subs[0] ?? {}, [subs]);
  return <div className="modal-backdrop" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
    <section className="user-modal" role="dialog" aria-modal="true" aria-label="Foydalanuvchi profili">
      <div className="modal-head"><div><p className="eyebrow">USER PROFILE</p><h2>{text(data.full_name, text(data.email, "Foydalanuvchi"))}</h2></div><button className="icon-button" onClick={onClose} aria-label="Yopish">×</button></div>
      {data.loading ? <div className="loading-panel">Profil yuklanmoqda…</div> : data.error ? <div className="error-box">{text(data.error)}</div> : <>
        <p className="muted">{text(data.email)}</p><div className="profile-facts"><span>Plan <b>{text(data.plan_id)}</b></span><span>Status <b>{text(data.status)}</b></span><span>Registered <b>{date(data.created_at)}</b></span></div>
        <h3>Foydalanish metrikalari</h3><div className="token-summary"><div><small>INPUT</small><b>{formatNumber(usage.input_tokens)}</b></div><div><small>OUTPUT</small><b>{formatNumber(usage.output_tokens)}</b></div><div><small>EST. COST</small><b>${number(usage.estimated_cost_usd).toFixed(4)}</b></div></div>
        <div className="notice"><span>ⓘ</span><p>{text(usage.data_source)}. Provider tasdiqlagan xarajat va caching tokenlari mavjud emas.</p></div>
        <h3>Obuna tarixi</h3>{subs.length ? subs.map((s, i) => <div className="subscription-item" key={`${text(s.product_id)}-${i}`}><b>{text(s.plan_id)} · {text(s.status)}</b><small>{text(s.provider)} / {text(s.product_id)} · {date(s.created_at)}</small></div>) : <p className="muted">Obuna yozuvi yo‘q.</p>}
        <div className="privacy-lock">⌑ Chatlar va xabarlar mazmuni maxfiylik sabab bu panelda mavjud emas.</div>
      </>}
    </section>
  </div>;
}
