// Presentation only: Documenter remains responsible for search, themes and page routing.
// Start with the requested light palette; keep any theme explicitly chosen by the reader.
try {
  if (localStorage.getItem('documenter-theme') === null) {
    localStorage.setItem('documenter-theme', 'documenter-light');
    if (typeof set_theme_from_local_storage === 'function') set_theme_from_local_storage();
  }
} catch (_) { /* Storage may be disabled; Documenter's own theme choice still works. */ }
document.addEventListener('DOMContentLoaded', () => {
  const root = document.querySelector('.docs-main');
  const page = document.querySelector('#documenter-page');
  if (!root || !page) return;
  const base = new URL(`${documenterBaseURL}/`, document.baseURI);
  const link = path => new URL(path, base).href;
  const links = [
    ['Guia', 'getting-started/overview.html'],
    ['Manual', 'manual/syntax.html'],
    ['Bibliotecas', 'standard-library/index.html'],
    ['Exemplos', 'examples/programs.html'],
    ['Referência', 'reference/grammar.html']
  ];
  const nav = document.createElement('nav');
  nav.className = 'abt-portal-nav';
  nav.setAttribute('aria-label', 'Navegação principal');
  const brand = document.createElement('a');
  brand.className = 'abt-portal-brand';
  brand.href = link('index.html');
  brand.setAttribute('aria-label','ABT, página inicial');
  brand.innerHTML = '<span class="abt-mark" aria-hidden="true">A</span><span>ABT</span><span class="abt-version">0.13.0</span>';
  nav.append(brand);
  const navLinks = document.createElement('div');
  navLinks.className = 'abt-portal-links';
  for (const [title, path] of links) {
    const anchor = document.createElement('a');
    anchor.textContent = title;
    anchor.href = link(path);
    navLinks.append(anchor);
  }
  nav.append(navLinks);
  const search = document.createElement('button');
  search.type = 'button';
  search.className = 'abt-portal-search abt-search-trigger';
  search.innerHTML = '<span class="abt-search-icon" aria-hidden="true">⌕</span><span>Buscar</span><span class="abt-shortcut">Ctrl /</span>';
  search.setAttribute('aria-label','Buscar na documentação');
  nav.append(search);
  const theme = document.createElement('button');
  theme.type = 'button';
  theme.className = 'abt-theme-trigger';
  theme.setAttribute('aria-label', 'Alterar aparência');
  theme.textContent = '◐';
  nav.append(theme);
  root.prepend(nav);
  const documenterSearch = document.querySelector('#documenter-search-query');
  if (documenterSearch) documenterSearch.textContent = 'Buscar na documentação (Ctrl /)';
  document.addEventListener('click', event => {
    if (event.target.closest('.abt-search-trigger')) document.querySelector('#documenter-search-query')?.click();
    if (event.target.closest('.abt-theme-trigger')) document.querySelector('#documenter-settings-button')?.click();
  });

  const token = /#[^\n]*|"(?:\\.|[^"\\])*"|\b(?:mostrar|show|se|if|senao|senão|else|para|for|cada|each|em|in|função|funcao|function|retornar|return|usar|verdadeiro|falso|true|false|e|and|ou|or|onde|where|de|of|soma|sum|media|média|average|filtrar|transformar|limitar|valor)\b|\b\d+(?:\.\d+)?\b/g;
  for (const code of page.querySelectorAll('pre code')) {
    const source = code.textContent;
    if (code.classList.contains('language-abt')) {
      const fragment = document.createDocumentFragment();
      let previous = 0;
      for (const match of source.matchAll(token)) {
        fragment.append(document.createTextNode(source.slice(previous, match.index)));
        const span = document.createElement('span');
        span.className = match[0].startsWith('#') ? 'abt-comment' : match[0].startsWith('"') ? 'abt-string' : /^\d/.test(match[0]) ? 'abt-number' : 'abt-keyword';
        span.textContent = match[0];
        fragment.append(span);
        previous = match.index + match[0].length;
      }
      fragment.append(document.createTextNode(source.slice(previous)));
      code.replaceChildren(fragment);
    }
    const pre = code.closest('pre');
    if (!pre || pre.parentElement?.classList.contains('abt-code-wrap')) continue;
    const wrap = document.createElement('div');
    wrap.className = 'abt-code-wrap';
    const bar = document.createElement('div');
    bar.className = 'abt-code-bar';
    const label = document.createElement('span');
    label.textContent = code.classList.contains('language-abt') ? 'Código ABT' : (Array.from(code.classList).find(x => x.startsWith('language-')) || 'Código').replace('language-','');
    // Documenter already supplies the accessible copy button on each code block.
    bar.append(label);
    pre.replaceWith(wrap);
    wrap.append(bar, pre);
  }
  if (page.querySelector('.abt-home-eyebrow')) page.classList.add('abt-home-page');
  else {
    const active = document.querySelector('.docs-sidebar .docs-menu li.is-active > a.tocitem');
    const section = active?.closest('ul')?.parentElement?.querySelector(':scope > span.tocitem')?.textContent?.trim();
    const title = page.querySelector('h1')?.textContent?.trim();
    if (title) {
      const crumb = document.createElement('nav');
      crumb.className = 'abt-breadcrumbs';
      crumb.setAttribute('aria-label', 'Caminho da página');
      const home = document.createElement('a'); home.href = link('index.html'); home.textContent = 'Início';
      crumb.append(home);
      if (section) { const sep = document.createElement('span'); sep.textContent = '/'; const group = document.createElement('span'); group.textContent = section; crumb.append(sep, group); }
      const sep = document.createElement('span'); sep.textContent = '/'; const current = document.createElement('span'); current.textContent = title; crumb.append(sep, current);
      page.prepend(crumb);
    }
    const sections = Array.from(page.querySelectorAll('h2[id]'));
    if (sections.length >= 2) {
      const outline = document.createElement('nav');
      outline.className = 'abt-page-toc';
      outline.setAttribute('aria-label', 'Nesta página');
      const label = document.createElement('span'); label.className = 'abt-page-toc-label'; label.textContent = 'Nesta página';
      outline.append(label);
      for (const section of sections) {
        const anchor = document.createElement('a');
        anchor.href = `#${section.id}`;
        anchor.textContent = section.querySelector('.docs-heading-anchor')?.textContent || section.textContent;
        outline.append(anchor);
      }
      root.append(outline);
    }
  }
});
