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
  const groups = [
    ['Aprender', [['Introdução','getting-started/overview.html'],['Primeiros programas','tutorials/first-program.html'],['Sintaxe','manual/syntax.html'],['Coleções','manual/collections.html'],['Funções','manual/control-flow.html'],['Pipelines','manual/collections.html']]],
    ['Documentação', [['Manual da linguagem','manual/syntax.html'],['Referência formal','reference/grammar.html'],['CLI','getting-started/install.html'],['Arquitetura','internals/architecture.html'],['Compilação','internals/compiler.html']]],
    ['Bibliotecas', [['Biblioteca padrão','standard-library/index.html'],['Estatística','standard-library/statistics.html'],['Bioestatística','tutorials/biostatistics.html'],['Bioinformática','standard-library/science.html'],['Álgebra linear','standard-library/scientific0130.html'],['Dados e tabelas','standard-library/tables.html'],['Visualização científica','tutorials/visualization.html']]],
    ['Exemplos', [['Programas completos','examples/programs.html'],['Aplicações científicas','scientific/overview.html'],['Análise de dados','tutorials/data.html'],['Interoperabilidade','manual/interop.html']]],
    ['Sobre', [['Projeto','getting-started/overview.html'],['Arquitetura','internals/architecture.html'],['Contribuição','contributing/index.html'],['GitHub','https://github.com/GustavoDMentz/ABT-Language']]]
  ];
  const nav = document.createElement('nav');
  nav.className = 'abt-portal-nav';
  nav.setAttribute('aria-label', 'Navegação principal');
  const brand = document.createElement('a');
  brand.className = 'abt-portal-brand';
  brand.href = link('index.html');
  brand.setAttribute('aria-label','ABT, página inicial');
  brand.innerHTML = '<span>ABT</span> Portal';
  nav.append(brand);
  const links = document.createElement('div');
  links.className = 'abt-portal-links';
  for (const [title, entries] of groups) {
    const details = document.createElement('details');
    const summary = document.createElement('summary');
    summary.textContent = title;
    const menu = document.createElement('div');
    menu.className = 'abt-portal-menu';
    for (const [label, path] of entries) {
      const anchor = document.createElement('a');
      anchor.textContent = label;
      anchor.href = path.startsWith('https://') ? path : link(path);
      menu.append(anchor);
    }
    details.append(summary, menu);
    links.append(details);
    details.addEventListener('toggle', () => {
      if (details.open) for (const other of links.querySelectorAll('details')) if (other !== details) other.open = false;
    });
  }
  nav.append(links);
  const search = document.createElement('button');
  search.type = 'button';
  search.className = 'abt-portal-search abt-search-trigger';
  search.textContent = '⌕  Buscar';
  search.setAttribute('aria-label','Buscar na documentação');
  nav.append(search);
  root.prepend(nav);
  document.addEventListener('click', event => {
    if (event.target.closest('.abt-search-trigger')) document.querySelector('#documenter-search-query')?.click();
    if (!event.target.closest('.abt-portal-links')) for (const details of links.querySelectorAll('details')) details.open = false;
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') for (const details of links.querySelectorAll('details')) details.open = false;
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
  if (page.querySelector('.abt-home-search')) page.classList.add('abt-home-page');
  else {
    const sections = Array.from(page.querySelectorAll('h2[id]'));
    if (sections.length >= 3) {
      const outline = document.createElement('details');
      outline.className = 'abt-page-outline';
      outline.open = true;
      const summary = document.createElement('summary'); summary.textContent = 'Nesta página';
      const list = document.createElement('ul');
      for (const section of sections) {
        const item = document.createElement('li'); const anchor = document.createElement('a');
        anchor.href = `#${section.id}`;
        anchor.textContent = section.querySelector('.docs-heading-anchor')?.textContent || section.textContent;
        item.append(anchor); list.append(item);
      }
      outline.append(summary, list);
      (page.querySelector('h1 + p') || page.querySelector('h1'))?.after(outline);
    }
  }
});
