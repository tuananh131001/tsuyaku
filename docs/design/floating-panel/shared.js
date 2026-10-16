// Shared behaviour for the three mockups: draws the fake meeting and the
// state toolbar, and drives the panel's states (notice, reading back,
// Japanese on/off, click-through, text size, streaming text).

(() => {
  const body = document.body;
  const panel = document.getElementById("panel");
  const history = document.getElementById("history");
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;

  body.insertAdjacentHTML("afterbegin", `
    <div class="meeting" aria-hidden="true">
      <div class="tile slide">
        <h2>Sprint 42 review</h2>
        <ul>
          <li>Release: Friday afternoon</li>
          <li>Print-order API latency −38%</li>
          <li>Payments tests: in progress</li>
          <li>Next: search speed (mobile)</li>
        </ul>
        <div class="bar"><i style="height:90%"></i><i style="height:72%"></i><i style="height:60%"></i><i style="height:41%"></i><i style="height:35%"></i></div>
      </div>
      <div class="tile"><div class="avatar" style="background:#8e6bd8">Y</div><span class="name">Yamada</span></div>
      <div class="tile"><div class="avatar" style="background:#1e8e6e">S</div><span class="name">Sato</span></div>
    </div>
    <nav class="toolbar" aria-label="Panel states">
      <span class="title">${body.dataset.design}<small>${body.dataset.tagline}</small></span>
      <button data-state="notice" aria-pressed="false">Notice</button>
      <button data-state="readback" aria-pressed="false">Reading back</button>
      <button data-state="no-ja" aria-pressed="false">Hide Japanese</button>
      <button data-state="click-through" aria-pressed="false">Click-through</button>
      <span class="sep"></span>
      <button data-size="0.85" aria-pressed="false">S</button>
      <button data-size="1" aria-pressed="true">M</button>
      <button data-size="1.25" aria-pressed="false">L</button>
      <button data-size="1.5" aria-pressed="false">XL</button>
      <span class="spacer"></span>
      <button data-notes aria-pressed="true">Notes</button>
      <a href="index.html">All designs</a>
    </nav>
  `);

  const label = panel.querySelector("[data-label]");
  const buttons = {};
  document.querySelectorAll("[data-state]").forEach(b => { buttons[b.dataset.state] = b; });

  function set(state, on) {
    panel.classList.toggle(state, on);
    if (buttons[state]) buttons[state].setAttribute("aria-pressed", on);
    if (state === "notice" && label) {
      label.textContent = on ? label.dataset.notice : label.dataset.normal;
    }
    if (state === "readback" && history) {
      history.scrollTo({ top: on ? 0 : history.scrollHeight, behavior: reduceMotion ? "auto" : "smooth" });
    }
  }

  Object.entries(buttons).forEach(([state, b]) => {
    b.addEventListener("click", () => set(state, !panel.classList.contains(state)));
  });

  document.querySelectorAll("[data-size]").forEach(b => {
    b.addEventListener("click", () => {
      panel.style.setProperty("--scale", b.dataset.size);
      document.querySelectorAll("[data-size]").forEach(o => o.setAttribute("aria-pressed", o === b));
      if (!panel.classList.contains("readback") && history) history.scrollTop = history.scrollHeight;
    });
  });

  const notes = document.querySelector(".notes");
  document.querySelector("[data-notes]").addEventListener("click", e => {
    const hidden = notes.classList.toggle("hidden");
    e.currentTarget.setAttribute("aria-pressed", !hidden);
  });

  // The "N new" pill and the reveal chevrons.
  panel.querySelectorAll("[data-pill]").forEach(p => p.addEventListener("click", () => set("readback", false)));
  panel.querySelectorAll("[data-reveal]").forEach(btn => {
    btn.addEventListener("click", () => {
      const row = btn.closest("[data-row]");
      const open = row.classList.toggle("open");
      btn.setAttribute("aria-expanded", open);
      btn.title = open ? "Hide original English" : "Show original English";
    });
  });

  // Scrolling up by hand is reading back, as in the real panel.
  if (history) {
    history.scrollTop = history.scrollHeight;
    history.addEventListener("wheel", () => {
      requestAnimationFrame(() => {
        const atBottom = history.scrollHeight - history.clientHeight - history.scrollTop <= 24;
        if (panel.classList.contains("readback") === atBottom) {
          panel.classList.toggle("readback", !atBottom);
          buttons.readback.setAttribute("aria-pressed", !atBottom);
        }
      });
    }, { passive: true });
  }

  // The live English streams in, holds, and starts again.
  document.querySelectorAll("[data-stream]").forEach(el => {
    const text = el.dataset.stream;
    if (reduceMotion) { el.textContent = text; return; }
    let i = 0;
    const tick = () => {
      i += 1 + Math.floor(Math.random() * 3);
      el.textContent = text.slice(0, i);
      if (i < text.length) setTimeout(tick, 55 + Math.random() * 70);
      else setTimeout(() => { i = 0; tick(); }, 3200);
    };
    tick();
  });
})();
