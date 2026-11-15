// ABT — comportamento do manual: realce de código, progresso de aprendizagem e navegação.
// Apenas apresentação: a semântica dos programas continua no lexer/parser do ABT (src/ABT.jl).
(() => {
  "use strict";

  /* ---------------------------------------------------------------- */
  /* Vocabulário: espelha KEYWORDS de src/ABT.jl                       */
  /* ---------------------------------------------------------------- */
  const KEYWORDS = new Set((
    "mostrar show media média average soma sum de of onde where é is maior above menor below que than " +
    "se if senao senão else para for cada each em in e and ou or função funcao function retornar return usar"
  ).split(" "));
  const CONSTANTS = new Set(["verdadeiro", "true", "falso", "false", "valor", "value"]);
  const PIPE = { filtrar: "onde", transformar: "com", limitar: "a" }; // palavras contextuais do parser
  const FUNCTION_WORDS = new Set(["função", "funcao", "function"]);

  /* Ordem de estudo usada para o progresso. Os mesmos identificadores aparecem em docs/src/trilha.md. */
  const LESSONS = [
    "getting-started/overview", "getting-started/install", "tutorials/first-program",
    "manual/syntax", "manual/expressions", "manual/control-flow", "manual/collections",
    "tutorials/data", "tutorials/statistics", "tutorials/biostatistics",
    "tutorials/bioinformatics", "tutorials/visualization", "manual/interop",
  ];
  const STORE_KEY = "abt:licoes-concluidas";

  /* ---------------------------------------------------------------- */
  /* Utilidades                                                         */
  /* ---------------------------------------------------------------- */
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const el = (tag, attrs = {}, ...children) => {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs)) {
      if (key === "class") node.className = value;
      else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
      else node.setAttribute(key, value);
    }
    node.append(...children);
    return node;
  };

  function readDone() {
    try { return new Set(JSON.parse(localStorage.getItem(STORE_KEY) || "[]")); }
    catch { return new Set(); }
  }
  function writeDone(set) {
    try { localStorage.setItem(STORE_KEY, JSON.stringify([...set])); } catch { /* armazenamento indisponível */ }
  }

  function baseURL() {
    const base = typeof documenterBaseURL === "string" ? documenterBaseURL : ".";
    return new URL(base.replace(/\/?$/, "/"), location.href);
  }
  /* Identificador de página independente de prettyurls: "tutorials/first-program". */
  function slugOf(href) {
    let url;
    try { url = new URL(href, location.href); } catch { return null; }
    if (url.origin !== location.origin) return null;
    const base = baseURL().pathname;
    if (!url.pathname.startsWith(base)) return null;
    const slug = url.pathname.slice(base.length).replace(/(^|\/)index\.html$/, "").replace(/\.html$/, "").replace(/\/$/, "");
    return slug || "index";
  }
  const currentSlug = () => slugOf(location.href);

  /* ---------------------------------------------------------------- */
  /* Realce de sintaxe ABT                                              */
  /* ---------------------------------------------------------------- */
  const TOKEN = /(#[^\n]*)|("(?:\\.|[^"\\\n])*")|(\d+(?:\.\d+)?)|([\p{L}_][\p{L}\p{N}_]*)|(==|!=|>=|<=|[-+*/^<>=])/uy;

  function highlight(source) {
    const out = document.createDocumentFragment();
    let pos = 0, plain = "", expect = null, afterFunction = false;
    const flush = () => { if (plain) { out.append(plain); plain = ""; } };
    const emit = (cls, text) => { flush(); out.append(el("span", { class: cls }, text)); };
    while (pos < source.length) {
      TOKEN.lastIndex = pos;
      const m = TOKEN.exec(source);
      if (!m) {
        if (source[pos] === "\n") { expect = null; afterFunction = false; }
        plain += source[pos++];
        continue;
      }
      const [text, comment, string, number, word, operator] = m;
      pos += text.length;
      if (comment) emit("abt-com", text);
      else if (string) emit("abt-str", text);
      else if (number) emit("abt-num", text);
      else if (operator) emit("abt-op", text);
      else if (word) {
        const lower = word.toLowerCase();
        const next = source.slice(pos).match(/^[ \t]*(.)/);
        const followsCall = next && next[1] === "(";
        const followsAssign = next && next[1] === "=" && source[pos + (next[0].length - 1) + 1] !== "=";
        if (afterFunction) { emit("abt-fn", text); afterFunction = false; }
        else if (lower in PIPE && !followsCall && !followsAssign) { emit("abt-pipe", text); expect = PIPE[lower]; }
        else if (expect && lower === expect) { emit("abt-pipe", text); expect = null; }
        else if (CONSTANTS.has(lower)) emit("abt-const", text);
        else if (KEYWORDS.has(lower) && !followsAssign) { emit("abt-kw", text); afterFunction = FUNCTION_WORDS.has(lower); }
        else if (followsCall) emit("abt-fn", text);
        else plain += text;
      }
    }
    flush();
    return out;
  }

  const LANGUAGE_LABELS = {
    abt: "ABT", bash: "Terminal", sh: "Terminal", shell: "Terminal", julia: "Julia", python: "Python",
    ebnf: "EBNF", json: "JSON", csv: "CSV", fasta: "FASTA", toml: "TOML", text: "Texto", plaintext: "Texto",
  };

  function decorateCode() {
    for (const pre of $$("article.content pre")) {
      const code = $("code", pre);
      if (!code) continue;
      const lang = ((code.className.match(/language-([\w-]+)/) || [])[1] || "").toLowerCase();
      if (lang === "abt" && !code.dataset.abtDone) {
        code.replaceChildren(highlight(code.textContent));
        code.dataset.abtDone = "1";
        code.dataset.highlighted = "yes"; // impede que o highlight.js reescreva o bloco
        pre.dataset.kind = "abt";
      }
      let label = LANGUAGE_LABELS[lang];
      if (lang === "text" || lang === "plaintext") {
        const previous = pre.previousElementSibling;
        const answersProgram = previous && previous.matches("pre") && previous.dataset.kind === "abt";
        if (answersProgram) { label = "Saída"; pre.dataset.kind = "out"; }
      }
      if (label) pre.dataset.lang = label;
      else if (lang) pre.dataset.lang = lang;
    }
  }

  /* ---------------------------------------------------------------- */
  /* Cabeçalho de página: tempo de leitura e posição na trilha          */
  /* ---------------------------------------------------------------- */
  function decorateHeader(article) {
    const h1 = $("h1", article);
    if (!h1 || $(".abt-meta", article)) return;
    const words = (article.textContent || "").trim().split(/\s+/).length;
    const minutes = Math.max(1, Math.round(words / 190));
    const chips = [el("span", {}, `⏱ ${minutes} min de leitura`)];
    const section = $(".docs-navbar .breadcrumb ul li:not(.is-active) a");
    if (section) chips.unshift(el("span", {}, section.textContent.trim()));
    const index = LESSONS.indexOf(currentSlug());
    if (index >= 0) chips.push(el("span", {}, `Lição ${index + 1} de ${LESSONS.length}`));
    h1.after(el("div", { class: "abt-meta" }, ...chips));
  }

  /* ---------------------------------------------------------------- */
  /* Progresso de aprendizagem                                          */
  /* ---------------------------------------------------------------- */
  function sidebarTitle(slug) {
    for (const a of $$(".docs-sidebar a.tocitem")) if (slugOf(a.href) === slug) return { title: a.textContent.trim(), href: a.href };
    return null;
  }

  function markDone() {
    const done = readDone();
    for (const a of $$(".docs-sidebar a.tocitem, .abt-path a")) {
      const slug = slugOf(a.href);
      a.classList.toggle("abt-done", !!slug && done.has(slug));
    }
    return done;
  }

  function lessonFooter(article) {
    const slug = currentSlug();
    const index = LESSONS.indexOf(slug);
    if (index < 0 || $(".abt-lesson", article)) return;
    const button = el("button", { type: "button", "aria-pressed": "false" });
    const render = () => {
      const done = readDone().has(slug);
      button.setAttribute("aria-pressed", String(done));
      button.textContent = done ? "✓ Lição concluída" : "Marcar como concluída";
    };
    button.addEventListener("click", () => {
      const done = readDone();
      if (done.has(slug)) done.delete(slug); else done.add(slug);
      writeDone(done); render(); markDone(); updateSummary();
    });
    const actions = el("div", { class: "abt-lesson-actions" }, button);
    const next = LESSONS[index + 1] && sidebarTitle(LESSONS[index + 1]);
    if (next) actions.append(el("a", { class: "abt-next", href: next.href }, `Próxima lição: ${next.title} →`));
    else {
      const trail = sidebarTitle("trilha");
      if (trail) actions.append(el("a", { class: "abt-next", href: trail.href }, "Ver a trilha completa →"));
    }
    article.append(el("section", { class: "abt-lesson", "aria-label": "Progresso da lição" },
      el("div", { class: "abt-lesson-text" },
        el("strong", {}, `Lição ${index + 1} de ${LESSONS.length}`),
        el("span", {}, "O progresso fica salvo apenas neste navegador.")),
      actions));
    render();
  }

  function updateSummary() {
    const slot = $("#abt-progress");
    if (!slot) return;
    const done = [...readDone()].filter(slug => LESSONS.includes(slug)).length;
    const percent = Math.round((done / LESSONS.length) * 100);
    const reset = el("button", { type: "button" }, "Reiniciar");
    reset.addEventListener("click", () => {
      if (!confirm("Apagar o progresso salvo neste navegador?")) return;
      writeDone(new Set()); markDone(); updateSummary();
    });
    const ring = el("div", { class: "abt-ring", role: "img", "aria-label": `${percent}% concluído`, style: `--p:${percent}` }, el("span", {}, `${percent}%`));
    const message = done === 0 ? "Comece pela primeira etapa — cada lição tem um botão para marcá-la como concluída."
      : done === LESSONS.length ? "Trilha completa. Continue pela referência da biblioteca e pelos programas completos."
      : "Continue de onde parou.";
    slot.replaceChildren(el("div", { class: "abt-summary" }, ring,
      el("div", { class: "abt-summary-text" }, el("strong", {}, `${done} de ${LESSONS.length} lições concluídas`), el("span", {}, message)),
      done ? reset : ""));
  }

  /* ---------------------------------------------------------------- */
  /* "Nesta página" e barra de leitura                                  */
  /* ---------------------------------------------------------------- */
  function pageRail(article) {
    if ($(".abt-hero", article)) return;
    const headings = $$("h2[id], h3[id]", article).filter(h => !h.closest(".abt-hero, .admonition"));
    if (headings.length < 3 || headings.length > 28) return;
    const items = headings.map(h => {
      const text = ($(".docs-heading-anchor", h) || h).textContent.trim();
      return el("li", { class: h.tagName.toLowerCase(), "data-id": h.id }, el("a", { href: `#${h.id}` }, text));
    });
    const rail = el("nav", { class: "abt-rail", "aria-label": "Nesta página" }, el("h4", {}, "Nesta página"), el("ul", {}, ...items));
    document.body.append(rail);
    const byId = new Map(items.map(li => [li.dataset.id, li]));
    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) if (entry.isIntersecting) {
        for (const li of items) li.classList.remove("on");
        byId.get(entry.target.id)?.classList.add("on");
      }
    }, { rootMargin: "-12% 0px -75% 0px" });
    headings.forEach(h => observer.observe(h));
  }

  function readingProgress() {
    const bar = el("div", { class: "abt-progress", role: "presentation" });
    document.body.append(bar);
    let queued = false;
    const update = () => {
      queued = false;
      const max = document.documentElement.scrollHeight - innerHeight;
      bar.style.width = max > 0 ? `${Math.min(100, (scrollY / max) * 100)}%` : "0";
    };
    addEventListener("scroll", () => { if (!queued) { queued = true; requestAnimationFrame(update); } }, { passive: true });
    update();
  }

  /* ---------------------------------------------------------------- */
  /* Idioma da interface (textos fixos do Documenter) e atalhos         */
  /* ---------------------------------------------------------------- */
  const TRANSLATIONS = new Map([
    ["Search docs (Ctrl + /)", "Buscar no manual (Ctrl + K)"],
    ["Search docs", "Buscar no manual"],
    ["Search", "Buscar"],
    ["Settings", "Configurações"],
    ["Theme", "Tema"],
    ["Automatic (OS)", "Automático (sistema)"],
    ["documenter-light", "Claro"],
    ["documenter-dark", "Escuro"],
    ["Version", "Versão"],
    ["Type something to get started!", "Digite algo para começar!"],
    ["Close", "Fechar"],
    ["Cancel", "Cancelar"],
    ["Filters:", "Filtros:"],
    ["to search", "para buscar"],
    ["to close", "para fechar"],
    ["to navigate", "para navegar"],
    ["to select", "para abrir"],
  ]);
  const SEARCH_BADGES = new Map([["section", "seção"], ["page", "página"]]);
  const PATTERNS = [
    [/^(\d+) results?$/, (_, n) => (n === "1" ? "1 resultado" : `${n} resultados`)],
    [/^No results?\b.*$/i, () => "Nenhum resultado encontrado"],
  ];
  function translateInterface() {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const trimmed = node.nodeValue.trim();
      const parent = node.parentElement;
      if (!parent || parent.closest("article.content, script, style, pre, code")) continue;
      if (TRANSLATIONS.has(trimmed)) node.nodeValue = node.nodeValue.replace(trimmed, TRANSLATIONS.get(trimmed));
      else if (SEARCH_BADGES.has(trimmed) && parent.closest(".property-search-result-badge, .search-filter")) node.nodeValue = node.nodeValue.replace(trimmed, SEARCH_BADGES.get(trimmed));
      else for (const [pattern, replacement] of PATTERNS) if (pattern.test(trimmed) && parent.closest("#search-modal")) {
        node.nodeValue = node.nodeValue.replace(trimmed, trimmed.replace(pattern, replacement)); break;
      }
    }
    for (const input of $$("input[placeholder]")) {
      const text = input.getAttribute("placeholder");
      if (TRANSLATIONS.has(text)) input.setAttribute("placeholder", TRANSLATIONS.get(text));
    }
    for (const a of $$(".docs-navbar-link[title]")) {
      const title = a.getAttribute("title");
      if (title === "View the repository on GitHub") a.setAttribute("title", "Ver o repositório no GitHub");
      else if (title === "Edit source on GitHub") a.setAttribute("title", "Editar esta página no GitHub");
      else if (title === "Settings") a.setAttribute("title", "Configurações");
      else if (title === "Collapse all docstrings") a.setAttribute("title", "Recolher tudo");
    }
  }

  function shortcuts() {
    addEventListener("keydown", event => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        const search = $("#documenter-search-query");
        if (search) { event.preventDefault(); search.click(); }
      }
    });
  }

  function favicon() {
    const logo = $(".docs-sidebar .docs-logo img");
    const href = logo ? logo.src : new URL("assets/logo.svg", baseURL()).href;
    if (!$("link[rel~=icon]")) document.head.append(el("link", { rel: "icon", type: "image/svg+xml", href }));
  }

  /* ---------------------------------------------------------------- */
  document.addEventListener("DOMContentLoaded", () => {
    const article = $("article.content");
    decorateCode();
    translateInterface();
    shortcuts();
    favicon();
    readingProgress();
    markDone();
    updateSummary();
    if (article) { decorateHeader(article); lessonFooter(article); pageRail(article); }
    // O Documenter monta a busca e o menu depois do carregamento; traduz de novo quando mudarem.
    new MutationObserver(() => translateInterface()).observe(document.body, { childList: true, subtree: true });
  });
})();
