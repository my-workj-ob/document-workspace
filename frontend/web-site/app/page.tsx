const featureItems = [
  {
    number: "01",
    title: "Hujjatni tushunadi",
    description: "PDF va boshqa hujjatlardagi mazmunni izlash va tahlil qilishga yordam beradi.",
    icon: "▤",
  },
  {
    number: "02",
    title: "Savollarga javob beradi",
    description: "Uzun materiallarni varaqlamasdan, kerakli savolni sodda tilda bering.",
    icon: "↗",
  },
  {
    number: "03",
    title: "Suhbatni davom ettiradi",
    description: "Bir mavzu bo‘yicha keyingi savollar va izohlar bilan fikrni chuqurlashtiring.",
    icon: "⌁",
  },
];

export default function Home() {
  return (
    <main id="top">
      <header className="nav-wrap">
        <nav className="nav container" aria-label="Asosiy navigatsiya">
          <a className="brand" href="#" aria-label="Cognidoc AI bosh sahifa">
            <span className="brand-symbol">c</span>
            <span>cognidoc<span className="brand-ai">.ai</span></span>
          </a>
          <div className="nav-links">
            <a href="#features">Imkoniyatlar</a>
            <a href="#how">Qanday ishlaydi</a>
            <a className="nav-cta" href="#get-started">Boshlash <span>↗</span></a>
          </div>
        </nav>
      </header>

      <section className="hero container">
        <div className="hero-copy">
          <div className="announcement"><span /> Hujjatlar bilan ishlashning yangi usuli <b>↗</b></div>
          <h1>Hujjatlaringizni<br />tushunadigan <span>AI.</span></h1>
          <p className="hero-description">
            Kerakli javobni sahifalar orasidan qidirmang. Hujjatingizni yuklang, savolingizni bering —
            Cognidoc AI mazmunni tushunishga yordam beradi.
          </p>
          <div className="hero-actions">
            <a className="button-primary" href="#get-started">Cognidoc AI’ni kashf eting <span>↗</span></a>
            <a className="button-secondary" href="#features">Imkoniyatlarni ko‘rish <span>↓</span></a>
          </div>
          <div className="trust-line"><span className="avatar-stack"><i>C</i><i>A</i><i>+</i></span><span>O‘qish va izlanish uchun yordamchi</span></div>
        </div>

        <div className="hero-visual" aria-label="Cognidoc AI hujjat yordamchisi tasviri">
          <div className="orbit orbit-one" /><div className="orbit orbit-two" />
          <div className="glow" />
          <div className="doc-card">
            <div className="doc-top"><span className="file-icon">PDF</span><span className="doc-name">Tadqiqot_hisoboti.pdf</span><span className="more">···</span></div>
            <div className="doc-body"><small>HUJJAT TAHLILI</small><div className="doc-title-line" /><div className="doc-text-line wide" /><div className="doc-text-line" /><div className="doc-text-line short" /><div className="highlight-line" /><div className="doc-text-line wide" /><div className="doc-text-line short" /></div>
            <div className="doc-footer"><span className="sparkle">✳</span> 12 sahifa tahlil qilindi <span className="check">✓</span></div>
          </div>
          <div className="answer-card">
            <div className="answer-brand"><span className="mini-mark">c</span> Cognidoc AI <span className="online">●</span></div>
            <p className="question">Asosiy xulosalar qanday?</p>
            <p className="answer">Hisobotda uchta muhim yo‘nalish ajratilgan. Birinchisi — resurslardan samarali foydalanish…</p>
            <div className="answer-source"><span>▤</span> Manba: 4–5-sahifalar</div>
          </div>
          <div className="floating-tag"><span>✳</span> Mazmun bo‘yicha javob</div>
        </div>
      </section>

      <section className="proof container">
        <span>MA’LUMOTNI TUSHUNISHNI SODDALASHTIRADI</span>
        <div className="proof-rule" />
        <span className="proof-note">Sizning hujjatingiz. Sizning savolingiz. Yaxshiroq tushuncha.</span>
      </section>

      <section className="feature-section" id="features">
        <div className="container">
          <div className="section-heading">
            <p className="kicker">IMKONIYATLAR</p>
            <h2>Kamroq qidirish.<br /><span>Ko‘proq tushunish.</span></h2>
            <p>Murakkab hujjatlar bilan ishlash jarayonini sodda va ravon qiling.</p>
          </div>
          <div className="feature-grid">
            {featureItems.map((feature) => (
              <article className="feature-card" key={feature.number}>
                <div className="feature-card-top"><span>{feature.number}</span><b>{feature.icon}</b></div>
                <h3>{feature.title}</h3>
                <p>{feature.description}</p>
                <span className="feature-arrow">↗</span>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="how-section container" id="how">
        <div className="how-copy"><p className="kicker">QANDAY ISHLAYDI</p><h2>Fikrlaringizga<br />mos <span>ish jarayoni.</span></h2><p>O‘qish, izlanish va hujjatlarni ko‘rib chiqish uchun bitta qulay yordamchi.</p></div>
        <div className="steps">
          <div className="step"><span>1</span><div><h3>Hujjatni tanlang</h3><p>Tahlil qilmoqchi bo‘lgan materialingizdan boshlang.</p></div></div>
          <div className="step"><span>2</span><div><h3>Savol bering</h3><p>O‘zingizga kerakli ma’lumotni oddiy so‘zlar bilan so‘rang.</p></div></div>
          <div className="step"><span>3</span><div><h3>Javobni o‘rganing</h3><p>Javobni tekshiring va hujjat bilan ishlashni davom ettiring.</p></div></div>
        </div>
      </section>

      <section className="cta-section container" id="get-started">
        <div><p className="kicker">COGNIDOC AI</p><h2>Hujjatlaringiz bilan<br />yangicha ishlang.</h2><p>Bugun boshlang — muhim ma’lumot doim qo‘lingizda bo‘lsin.</p></div>
        <a className="button-primary" href="#features">Imkoniyatlarni o‘rganish <span>↗</span></a>
        <div className="cta-decoration">c</div>
      </section>

      <footer className="footer container">
        <a className="brand" href="#"><span className="brand-symbol">c</span><span>cognidoc<span className="brand-ai">.ai</span></span></a>
        <span>© {new Date().getFullYear()} Cognidoc AI. Barcha huquqlar himoyalangan.</span>
        <a href="#top">Yuqoriga ↑</a>
      </footer>
    </main>
  );
}
