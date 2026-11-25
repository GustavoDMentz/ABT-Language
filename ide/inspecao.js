/* Modo de inspeção da ABT IDE: mostra o que o compilador produziu em cada etapa.
   Tudo vem de /api/inspecionar (dados do compilador real + derivações rotuladas). Usa globais da página: $, ed, CFG, irPara, guardar, ler. */
(() => {
"use strict";
const h = (tag, props, ...kids) => {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (v === false || v == null) continue;
    if (k === "class") e.className = v;
    else if (k === "on") for (const [ev, fn] of Object.entries(v)) e.addEventListener(ev, fn);
    else e.setAttribute(k, v === true ? "" : v);
  }
  for (const c of kids.flat(9)) { if (c == null || c === false) continue; e.append(c.nodeType ? c : document.createTextNode(String(c))); }
  return e;
};
const subst = (el, ...kids) => el.replaceChildren(...kids.flat(9).filter(c => c != null && c !== false));
const btn = (txt, fn, props) => h("button", Object.assign({ on: { click: fn } }, props || {}), txt);
const pos = (l, c) => `${l}:${c}`;
const ABAS = [
  ["fonte", "Código-fonte", null], ["lexica", "Análise léxica", "lexica"], ["simbolos", "Tabela de símbolos", "lexica"],
  ["normalizado", "Código normalizado", "lexica"], ["g2", "Gramática e tabela M", null], ["sintatica", "Análise sintática", "sintatica"],
  ["ast", "AST", "sintatica"], ["ir", "IR", "ir"], ["semantica", "Análise semântica", "semantica"], ["otimizacao", "Otimizações", "otimizacao"],
  ["julia", "Código Julia", "geracao"], ["julia_o", "Julia otimizado", "geracao_otimizada"], ["saida", "Saída", null], ["desempenho", "Diagnósticos e desempenho", null],
];
// Papéis dos operandos de cada nó (lidos de lower_expr/lower_ir em src/ABT.jl).
const CAMPOS = {
  lit: ["valor"], var: ["nome"], list: ["itens"], prop: ["objeto", "campo"], unary: ["operador", "operando"], bin: ["operador", "esquerda", "direita"],
  call: ["função", "argumentos"], agg: ["agregação", "expressão", "filtro"], filter: ["origem", "predicado"], map: ["origem", "expressão"], limit: ["origem", "quantidade"],
  assign: ["nome", "expressão"], show: ["expressão"], if: ["condição", "então", "senão"], import_julia: ["módulo"], import_python: ["caminho"],
  function: ["nome", "parâmetros", "corpo"], return: ["expressão"], for: ["variável", "coleção", "corpo"],
  constant: ["valor"], load: ["nome"], field: ["objeto", "campo"], binary: ["operador", "esquerda", "direita"], aggregate: ["agregação", "expressão", "filtro"],
  store: ["nome", "expressão"], print: ["expressão"], branch: ["condição", "então", "senão"], foreach: ["variável", "coleção", "corpo"],
};
const OPERADORES = new Set(["bin", "binary", "unary"]);
let P = null, aba = "fonte", selTokens = new Set(), selInstr = null, ocupado = false, passo = 0, timer = null, velocidade = 150, instrumentar = false;
let raiz, corpo, fasesEl, abasEl, avisoEl, tituloEl;
let temas = ["auto", "claro", "escuro"], tema = "auto";

// ───────────── comunicação ─────────────
async function api(rota, dados) {
  const r = await fetch(rota, { method: "POST", headers: { "Content-Type": "application/json", "X-IDE-Token": CFG.token }, body: JSON.stringify(dados) });
  if (!r.ok) throw new Error((await r.text()) || r.status);
  const j = await r.json();
  if (j.erro_inspecao) throw new Error(j.erro_inspecao);
  return j;
}
function baixar(nome, mime, b64) {
  const bin = atob(b64), bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  const a = h("a", { href: URL.createObjectURL(new Blob([bytes], { type: mime })), download: nome });
  document.body.append(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1500);
}
async function exportar(item) {
  try { const r = await api("/api/exportar", { hash: P.hash, item }); baixar(r.nome, r.mime, r.b64); }
  catch (e) { alert("Não foi possível exportar: " + e.message); }
}
const botaoExp = (rotulo, item) => btn("⬇ " + rotulo, () => exportar(item), { title: "Exporta os dados reais desta inspeção" });
function copiar(texto, el) {
  const ok = () => { const t = el.textContent; el.textContent = "Copiado ✓"; setTimeout(() => (el.textContent = t), 1200); };
  if (navigator.clipboard && window.isSecureContext !== false) navigator.clipboard.writeText(texto).then(ok, () => alert("Não foi possível copiar."));
  else { const ta = h("textarea", { style: "position:fixed;opacity:0" }, texto); document.body.append(ta); ta.select(); try { document.execCommand("copy"); ok(); } finally { ta.remove(); } }
}

// ───────────── componentes ─────────────
function tabela(cab, linhas, opc = {}) {
  const t = h("table", {}, h("thead", {}, h("tr", {}, cab.map(c => h("th", {}, c)))));
  const tb = h("tbody");
  linhas.forEach((l, i) => {
    const tr = h("tr", { class: opc.clic ? "clic" : "" }, l.map((c, j) => h("td", { class: opc.mono && opc.mono.includes(j) ? "mono" : "" }, c)));
    if (opc.clic) tr.addEventListener("click", () => opc.clic(i, tr));
    tb.append(tr);
  });
  t.append(tb);
  return h("div", { class: "tabela" }, t);
}
const nota = (txt, cls) => h("p", { class: "nota " + (cls || "") }, txt);

function textoPre(txt) { return h("pre", {}, txt || ""); }

function viaFonte(opc = {}) {
  // Código inspecionado, com os tokens reais como elementos clicáveis. opc: sel (Set de índices), erro {linha,coluna}, onToken(i), linhas (Set)
  const linhas = P.codigo.split("\n"), por = {};
  for (const t of P.lexica.tokens) if (!t.eof) (por[t.linha] ||= []).push(t);
  const caixa = h("div", { class: "fonte" });
  linhas.forEach((txt, i) => {
    const n = i + 1, cd = h("span", { class: "cd" });
    let cur = 0;
    const gap = (de, ate) => {
      let s = txt.slice(de, ate);
      const e = opc.erro && opc.erro.linha === n ? opc.erro.coluna - 1 : -1;
      if (e >= de && e < ate) { gap0(txt.slice(de, e), cd); cd.append(h("span", { class: "errc", title: "Posição do erro léxico" }, txt.slice(e, e + 1) || " ")); gap0(txt.slice(e + 1, ate), cd); }
      else gap0(s, cd);
    };
    for (const t of (por[n] || []).filter(x => !x.sintetico).sort((a, b) => a.coluna - b.coluna)) {
      const ini = t.coluna - 1;
      if (ini < cur) continue;
      if (ini > cur) gap(cur, ini);
      const cls = "tk " + ({ NUMBER: "nu", STRING: "st" }[t.tipo] || (/^[A-Z]+$/.test(t.tipo) && t.tipo !== "IDENT" ? "kw" : (t.tipo === "IDENT" ? "" : "op"))) + (opc.sel && opc.sel.has(t.indice) ? " s" : "");
      const el = h("span", { class: cls, title: `#${t.indice} ${t.tipo} @${pos(t.linha, t.coluna)}`, "data-i": t.indice }, txt.slice(ini, ini + t.comprimento));
      if (opc.onToken) el.addEventListener("click", () => opc.onToken(t.indice));
      cd.append(el); cur = ini + t.comprimento;
    }
    if (cur < txt.length) gap(cur, txt.length);
    caixa.append(h("div", { class: "fl" + (opc.linhas && opc.linhas.has(n) ? " destaque" : "") }, h("span", { class: "ln" }, n), cd));
  });
  return caixa;
}
function gap0(s, cd) {
  const k = s.indexOf("#");
  if (k < 0) { if (s) cd.append(s); return; }
  if (k > 0) cd.append(s.slice(0, k));
  cd.append(h("span", { class: "cm" }, s.slice(k)));
}
function rolarPara(caixa) { const s = caixa.querySelector(".tk.s, .errc"); if (s) s.scrollIntoView({ block: "center", inline: "nearest" }); }

function conv(x, campo) {
  if ("n" in x) {
    const nomes = CAMPOS[x.n] || [];
    let args = x.a.map((y, i) => [y, nomes[i]]);
    let op = null;
    if (OPERADORES.has(x.n) && x.a[0] && "v" in x.a[0]) { op = x.a[0].v; args = args.slice(1); }
    return { campo, rotulo: x.n, op, kids: args.map(([y, c]) => conv(y, c)) };
  }
  if ("l" in x) return { campo, rotulo: "lista", kids: x.l.map((y, i) => conv(y, "[" + (i + 1) + "]")), lista: true };
  return { campo, folha: true, valor: x.v === null ? "∅" : JSON.stringify(x.v), tipo: x.t };
}
function convDeriv(n) {
  return { campo: null, rotulo: n.s, prod: n.p, lexema: n.lexema, folha: !n.f, kids: (n.f || []).map(convDeriv) };
}
function noArvore(n, nivel, aberto, extra) {
  const rotulo = [
    n.campo ? h("span", { class: "campo" }, n.campo + ":") : null,
    n.folha && !n.rotulo ? [h("span", {}, n.valor), " ", h("span", { class: "tipo" }, n.tipo)] : h("span", { class: "nome" }, n.rotulo),
    n.op != null ? h("span", { class: "op", title: "operador" }, n.op) : null,
    n.prod ? h("span", { class: "prod", title: "produção de G2 aplicada" }, "p" + n.prod) : null,
    n.lexema != null && n.folha ? h("span", { class: "op" }, n.lexema) : null,
    extra || null,
  ];
  if (!n.kids || !n.kids.length) return h("div", { class: "folha" }, rotulo);
  const d = h("details", { open: aberto(nivel) ? true : false }, h("summary", {}, rotulo));
  n.kids.forEach(k => d.append(noArvore(k, nivel + 1, aberto)));
  return d;
}
function arvore(raizes, opc = {}) {
  const aberto = nivel => nivel < (opc.nivel ?? 3);
  const cx = h("div", { class: "arv" });
  raizes.forEach((r, i) => cx.append(noArvore(r, 0, aberto, opc.extra ? opc.extra(i) : null)));
  const bar = h("div", { class: "acoes" }, btn("Expandir tudo", () => cx.querySelectorAll("details").forEach(d => (d.open = true))), btn("Recolher tudo", () => cx.querySelectorAll("details").forEach(d => (d.open = false))));
  return h("div", {}, bar, cx);
}
const extraInstr = () => i => {
  const c = P.correspondencia[i];
  return c ? h("span", { class: "tipo" }, `  ← instrução ${c.instrucao}, linhas ${c.linhas[0]}–${c.linhas[1]}, tokens ${c.tokens[0]}–${c.tokens[1]}`) : null;
};
function tabelaCorrespondencia() {
  if (!P.correspondencia.length) return nota("Correspondência entre código, AST e IR indisponível (precisa de AST e IR geradas e conferidas).");
  return h("div", {}, h("h3", {}, "Correspondência código ↔ AST ↔ IR (instruções de nível superior)"),
    nota("Os intervalos de tokens vêm do próprio parser da ABT (mesmo laço de parse_program, conferido contra a AST real). A AST não guarda posições; instruções aninhadas não têm posição própria.", ""),
    tabela(["#", "Linhas", "Tokens", "AST", "IR"], P.correspondencia.map(c => [c.instrucao, c.linhas[0] === c.linhas[1] ? c.linhas[0] : `${c.linhas[0]}–${c.linhas[1]}`, `${c.tokens[0]}–${c.tokens[1]}`, c.ast, c.ir]),
      { clic: (i) => { const c = P.correspondencia[i]; selTokens = new Set(); for (let t = c.tokens[0]; t <= c.tokens[1]; t++) selTokens.add(t); selInstr = i; trocar("fonte"); } }));
}

function matrizM(g, onCelula) {
  const mapa = new Map(g.tabela_m.map(c => [c.nt + "|" + c.terminal, c]));
  const t = h("table", {}, h("thead", {}, h("tr", {}, h("th", {}, "M"), g.colunas.map(c => h("th", {}, c)))));
  const tb = h("tbody"), celulas = new Map();
  g.nao_terminais.forEach(nt => {
    const tr = h("tr", {}, h("td", {}, nt));
    g.colunas.forEach(col => {
      const c = mapa.get(nt + "|" + col);
      const td = h("td", { class: c ? (c.producoes.length > 1 ? "conf" : "pre") : "", title: c ? `M[${nt}, ${col}] = ${c.producoes.join(", ")} (origem: ${c.origem.join(", ")})` : "" }, c ? c.producoes.join(",") : "");
      if (c && onCelula) td.addEventListener("click", () => onCelula(c));
      celulas.set(nt + "|" + col, td); tr.append(td);
    });
    tb.append(tr);
  });
  t.append(tb);
  return { el: h("div", { class: "m" }, t), celulas };
}
function infoCelula(g, c) {
  if (!c) return nota("Clique numa célula preenchida da tabela M para ver a produção e a origem.");
  return h("div", { class: "cartao" }, h("b", {}, `M[${c.nt}, ${c.terminal}] = ${c.producoes.join(", ")}`), " — ", c.producoes.map(p => g.producoes[p - 1].texto).join(" | "),
    h("div", { class: "nota" }, c.origem.map(o => o === "FIRST" ? `origem: ${c.terminal} ∈ FIRST do lado direito da produção` : `origem: lado direito anulável e ${c.terminal} ∈ FOLLOW(${c.nt})`).join("; ")));
}

function codigoComNumeros(txt) {
  const caixa = h("div", { class: "fonte" });
  (txt || "").replace(/\n$/, "").split("\n").forEach((l, i) => caixa.append(h("div", { class: "fl" }, h("span", { class: "ln" }, i + 1), h("span", { class: "cd" }, l))));
  return caixa;
}
function diffView(linhas) {
  return h("div", { class: "fonte df" }, linhas.map(([m, t]) => h("div", { class: m === "+" ? "mais" : m === "-" ? "menos" : "" }, (m === "=" ? "  " : m + " ") + t)));
}
function lado(a, b, rotA, rotB) {
  return h("div", { class: "col2" }, h("div", {}, h("h3", {}, rotA), a), h("div", {}, h("h3", {}, rotB), b));
}

// ───────────── painéis ─────────────
const PAINEIS = {
  fonte() {
    const cx = viaFonte({ sel: selTokens, erro: P.lexica.posicao, onToken: i => { selTokens = new Set([i]); trocar("lexica"); } });
    setTimeout(() => rolarPara(cx));
    return h("div", {}, h("h3", {}, "Código-fonte inspecionado"), nota(`Esta é a versão exata que o compilador processou (SHA-256 ${P.hash.slice(0, 16)}…). Clique num token para localizá-lo na análise léxica.`),
      h("div", { class: "acoes" }, btn("✎ Editar este código", () => fechar(true)), btn("↻ Inspecionar de novo", () => inspecionar())), cx);
  },
  lexica() {
    const lex = P.lexica, toks = lex.tokens.filter(t => !t.eof);
    const cx = viaFonte({ sel: selTokens, erro: lex.posicao, onToken: i => { selTokens = new Set([i]); atualizar(); } });
    const tab = tabela(["#", "Lexema", "Token", "Padrão (regra do lexer)", "Linha", "Col.", "Valor", "Origem"], toks.map(t => [t.indice, t.lexema, t.tipo, t.regra, t.linha, t.coluna, t.valor === null ? "" : String(t.valor), t.sintetico ? "pipeline" : "texto"]),
      { mono: [1, 2, 3], clic: (i) => { selTokens = new Set([toks[i].indice]); atualizar(); } });
    tab.querySelectorAll("tbody tr").forEach((tr, i) => tr.classList.toggle("sel", selTokens.has(toks[i].indice)));
    setTimeout(() => { const s = tab.querySelector("tr.sel"); if (s) s.scrollIntoView({ block: "nearest" }); rolarPara(cx); });
    const sint = lex.sinteticos ? nota(`${lex.sinteticos} token(s) foram criados pelo próprio lexer ao reescrever pipelines indentados (expand_pipelines): o texto deles não está na posição informada, que é copiada de outro token. Aparecem na tabela com origem "pipeline" e não são marcados no código.`, "forte alerta") : null;
    const err = lex.ok ? null : h("div", { class: "cartao falhou" }, h("b", { class: "erro" }, "Erro léxico real: "), lex.erro, h("pre", {}, lex.diagnostico || ""),
      lex.posicao ? btn(`Ir para ${pos(lex.posicao.linha, lex.posicao.coluna)}`, () => fechar(true, lex.posicao)) : null,
      nota(`A tabela abaixo mostra só os ${lex.total} tokens reconhecidos antes do erro: o lexer real não devolve tokens parciais, então a IDE reaplica o lexer ao trecho anterior ao erro.`, "alerta"));
    const cat = P.lexica.reservadas;
    return h("div", {}, err, sint, h("div", { class: "acoes" }, botaoExp("Tokens e símbolos (TXT)", "tokens_simbolos"), botaoExp("Tokens (CSV)", "tokens_csv")),
      h("h3", {}, `Tokens (${lex.total})`), nota("Padrões do lexer real (tokenize): número \\d+(?:\\.\\d+)?; texto \"(?:\\\\.|[^\"\\\\])*\"; nome [^\\W\\d]\\w* (vira palavra reservada se estiver em ABT.KEYWORDS); operadores/pontuação, nesta ordem: ==|!=|>=|<=|[=+*/^><\\-{},;\\[\\]().]. Comentários (#…) e espaços são descartados."), h("div", { class: "duas" }, tab, cx),
      h("h3", {}, "Palavras reservadas e equivalência português ↔ inglês"),
      nota(`Catálogo real (ABT.KEYWORDS, ${lex.palavras_reservadas_total} lexemas): lexemas diferentes produzem o mesmo token, sem distinção de maiúsculas. A classificação por idioma é da IDE; a equivalência vem do compilador.`),
      tabela(["Token", "Português", "Inglês", "Terminal em G2"], cat.map(c => [c.token, c.portugues.join(", "), c.ingles.join(", "), c.terminal_g2 || "(fora de G2)"]), { mono: [0, 1, 2, 3] }));
  },
  simbolos() {
    const s = P.simbolos, sem = P.semantica;
    const mapaTokens = new Map(P.lexica.tokens.filter(t => !t.eof).map(t => [t.linha + ":" + t.coluna, t.indice]));
    const lista = s.usuario;
    const tab = tabela(["Nome", "Categoria", "Escopo (def.)", "1ª ocorrência", "Definições", "Usos", "Tipo"], lista.map(x => [x.nome, x.categoria, x.escopos_de_definicao.join(", ") || "—", pos(x.primeira.linha, x.primeira.coluna),
      x.definicoes.map(o => pos(o.linha, o.coluna)).join("  ") || "—", x.usos.map(o => pos(o.linha, o.coluna)).join("  ") || "—", "não exposto"]), { mono: [0], clic: (i) => {
        selTokens = new Set([...lista[i].definicoes, ...lista[i].usos].map(o => mapaTokens.get(o.linha + ":" + o.coluna))); trocar("simbolos");
      } });
    const cxs = viaFonte({ sel: selTokens });
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("Tokens e símbolos (TXT)", "tokens_simbolos"), botaoExp("Símbolos (CSV)", "simbolos_csv")),
      h("h3", {}, "Tabela de símbolos léxica (exigência acadêmica)"),
      nota("Derivada dos tokens reais: cada identificador é classificado pelo contexto (atribuição, laço, cabeçalho de função, chamada, uso). O escopo é o da função cujo bloco contém o símbolo ou 'global'. Clique numa linha para ver as ocorrências no código.", "forte"),
      h("div", { class: "duas" }, tab, cxs),
      s.embutidos_usados.length ? nota("Embutidas/contextuais usadas (não são símbolos do usuário): " + s.embutidos_usados.map(x => x.nome + " (" + x.categoria + ")").join(", ")) : null,
      h("h3", {}, "O que a análise semântica informa"),
      nota(sem.observacao_tipos, "forte alerta"),
      sem.funcoes.length ? tabela(["Função (AST real)", "Parâmetros", "Aridade"], sem.funcoes.map(f => [f.nome, f.parametros.join(", "), f.aridade]), { mono: [0, 1] }) : nota("Nenhuma função declarada no programa."),
      sem.importacoes.length ? tabela(["Importação (AST real)", "Módulo"], sem.importacoes.map(i => [i.tipo, i.modulo])) : null);
  },
  normalizado() {
    const n = P.normalizado;
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("Código normalizado (TXT)", "normalizado")),
      nota("Cada identificador vira id e cada número vira num, a partir dos tokens reconhecidos pelo lexer real (não por substituição de texto). Palavras reservadas, operadores e pontuação ficam como escritos; comentários não existem para o lexer.", "forte"),
      n.omitidos ? nota(`${n.omitidos} token(s) criados pela reescrita de pipelines não aparecem aqui: não estão no texto.`, "alerta") : null,
      lado(codigoComNumeros(P.codigo), codigoComNumeros(n.texto), "Original", "Normalizado"),
      h("h3", {}, "Lexemas substituídos"), tabela(["Linha", "Original", "Normalizado"], n.linhas.flatMap(l => l.tokens.filter(t => t.original !== t.normalizado).map(t => [l.linha, t.original, t.normalizado])), { mono: [1, 2] }));
  },
  g2() {
    const g = P.g2;
    const info = h("div", {});
    info.append(infoCelula(g, null));
    const M = matrizM(g, c => { info.replaceChildren(infoCelula(g, c)); M.celulas.forEach(td => td.classList.remove("marca")); });
    const lista = h("div", { class: "tabela" }, h("table", {}, h("tbody", {}, g.producoes.map(p => h("tr", { class: "clic", on: { click: () => {
      M.celulas.forEach(td => td.classList.remove("marca"));
      g.tabela_m.filter(c => c.producoes.includes(p.n)).forEach(c => M.celulas.get(c.nt + "|" + c.terminal).classList.add("marca"));
    } } }, h("td", { class: "mono" }, p.n), h("td", { class: "mono" }, p.texto))))));
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("Gramática, FIRST, FOLLOW e M (TXT)", "gramatica"), botaoExp("Tabela M (CSV)", "tabela_m_csv"), botaoExp("G2 (JSON)", "g2_json")),
      nota("G2 é uma gramática ACADÊMICA, um recorte da ABT. FIRST, FOLLOW e a tabela M são calculados agora, programaticamente, a partir das produções de ide/g2.txt. A ABT real não usa esta tabela: seu parser é descendente recursivo.", "forte alerta"),
      h("p", {}, `Símbolo inicial: ${g.inicial} · ${g.nao_terminais.length} não terminais · ${g.terminais.length} terminais · ${g.producoes.length} produções · ${g.celulas} células em M · conflitos: ${g.conflitos.length}.`),
      nota(g.ll1 ? "Sem conflitos: G2 é LL(1). Isto vale só para G2; a IDE não afirma que a linguagem ABT completa seja LL(1) (a ABT tem funções, textos, e/ou, pipelines etc. fora de G2)." : "HÁ CONFLITOS em M: G2 não é LL(1).", g.ll1 ? "" : "alerta"),
      h("h3", {}, "Produções (clique para marcar as células de M que a usam)"), lista,
      h("h3", {}, "Tabela M"), M.el, h("div", {}, info),
      h("h3", {}, "FIRST e FOLLOW"), tabela(["Não terminal", "Anulável", "FIRST", "FOLLOW"], g.nao_terminais.map(a => [a, g.anulaveis.includes(a) ? "sim" : "não", g.first[a].join("  "), g.follow[a].join("  ")]), { mono: [0, 2, 3] }));
  },
  sintatica() {
    const s = P.sintatica, a = s.g2, r = s.real, g = P.g2;
    const topo = h("div", {});
    subst(topo,
      nota("Duas análises DIFERENTES: (1) o parser real da ABT, descendente recursivo, que é o que o compilador usa; (2) a análise preditiva tabular de G2, didática, calculada pela IDE sobre os tokens reais.", "forte alerta"),
      h("div", { class: "grade" },
        h("div", { class: "cartao " + (r.estado === "ok" ? "ok" : r.estado === "falhou" ? "falhou" : "") }, h("b", {}, "Parser real da ABT"), h("div", {}, r.estado === "ok" ? "Aceitou o programa." : r.estado === "falhou" ? "Rejeitou: " + r.erro : "Não executado (etapa anterior falhou)."),
          r.diagnostico ? h("pre", {}, r.diagnostico) : null, r.posicao ? btn(`Ir para ${pos(r.posicao.linha, r.posicao.coluna)}`, () => fechar(true, r.posicao)) : null),
        h("div", { class: "cartao " + (a ? (a.aceita ? "ok" : "falhou") : "") }, h("b", {}, "Análise tabular de G2"),
          h("div", {}, a ? (a.aceita ? `Aceito em ${a.n_passos} passos.` : `Rejeitado no passo ${a.n_passos}: ${a.erro.mensagem}` + (a.erro.linha ? ` (linha ${a.erro.linha}, coluna ${a.erro.coluna}, lexema "${a.erro.lexema}")` : " (fim da entrada)")) : "Não realizada (erro léxico)."),
          a && !a.aceita && a.erro.linha ? btn(`Ir para ${pos(a.erro.linha, a.erro.coluna)}`, () => fechar(true, a.erro)) : null)),
      h("p", {}, h("b", {}, "Veredito: "), s.veredito.texto, " ", h("span", { class: "tipo" }, "(" + s.veredito.codigo + ")")),
      s.fora_do_recorte.length ? tabela(["Símbolo fora do recorte de G2", "Token", "Posição"], s.fora_do_recorte.map(f => [f.lexema, f.tipo, pos(f.linha, f.coluna)]), { mono: [0, 1] }) : null,
      h("div", { class: "acoes" }, botaoExp("Passo a passo (TXT)", "passos"), botaoExp("Resultado e diagnóstico (TXT)", "resultado_sintatico"), botaoExp("Passos (JSON)", "passos_json")));
    if (!a) return topo;
    const nPassos = a.passos.length;
    const pilhaEl = h("div", { class: "pilha" }), entradaEl = h("div", { class: "pilha" }), acaoEl = h("div", { class: "cartao" }), contEl = h("div", { class: "cont" }),
      range = h("input", { type: "range", min: 1, max: nPassos, value: passo + 1, "aria-label": "Passo" }), numEl = h("b", {}),
      tb = h("tbody"), M = matrizM(g), linhasEl = [];
    a.passos.forEach((p, i) => {
      const tr = h("tr", { class: "clic", on: { click: () => ir(i) } }, h("td", {}, p.n), h("td", { class: "mono" }, p.pilha.join(" ")), h("td", { class: "mono" }, p.entrada.join(" ")),
        h("td", { class: "mono" }, p.consulta ? `M[${p.consulta.nt}, ${p.consulta.terminal}]` + (p.consulta.producoes.length ? " = " + p.consulta.producoes.join(",") : " vazia") : "—"), h("td", {}, p.acao));
      linhasEl.push(tr); tb.append(tr);
    });
    const tabPassos = h("div", { class: "tabela" }, h("table", {}, h("thead", {}, h("tr", {}, ["Passo", "Pilha (topo à esquerda)", "Entrada restante", "Consulta M", "Ação"].map(c => h("th", {}, c)))), tb));
    let anterior = null;
    function ir(i, rolar = true) {
      passo = Math.max(0, Math.min(nPassos - 1, i));
      const p = a.passos[passo];
      range.value = passo + 1; numEl.textContent = `Passo ${p.n} de ${nPassos}`;
      subst(pilhaEl, h("span", { class: "nota" }, "pilha:"), ...p.pilha.map((s_, k) => h("span", { class: "cx" + (k === 0 ? " topo" : ""), title: k === 0 ? "topo da pilha" : "" }, s_)));
      subst(entradaEl, h("span", { class: "nota" }, "entrada:"), ...p.entrada.map((s_, k) => h("span", { class: "cx" + (k === 0 ? " atual" : "") + (s_ === "$" ? " fim" : ""), title: k === 0 ? "símbolo atual" : "" }, s_)));
      const c = p.consulta;
      acaoEl.className = "cartao " + (p.tipo === "erro" ? "falhou" : p.tipo === "aceita" ? "ok" : "");
      subst(acaoEl, h("div", {}, h("b", {}, "Símbolo atual: "), h("span", { class: "mono" }, p.atual), "   ", h("b", {}, "Topo: "), h("span", { class: "mono" }, p.pilha[0] || "—")),
        c ? h("div", {}, h("b", {}, "Consulta: "), h("span", { class: "mono" }, `M[${c.nt}, ${c.terminal}]`), c.producoes.length ? " = " + c.producoes.map(x => g.producoes[x - 1].texto).join(" | ") : " → célula vazia (erro sintático)") : null,
        h("div", {}, h("b", {}, "Ação: "), p.acao));
      if (anterior) anterior.classList.remove("dest");
      anterior = c ? M.celulas.get(c.nt + "|" + c.terminal) : null;
      if (anterior) { anterior.classList.add("dest"); anterior.scrollIntoView({ block: "nearest", inline: "nearest" }); }
      const feitos = a.passos.slice(0, passo + 1);
      contEl.replaceChildren(...[["Passos realizados", passo + 1], ["Produções aplicadas", feitos.filter(x => x.tipo === "producao").length], ["Tokens casados", feitos.filter(x => x.tipo === "casamento").length]].map(([k, v]) => h("span", {}, k + ": ", h("b", {}, v))));
      linhasEl.forEach((tr, k) => tr.classList.toggle("sel", k === passo));
      if (rolar) linhasEl[passo].scrollIntoView({ block: "nearest" });
    }
    const parar = () => { clearInterval(timer); timer = null; playBtn.textContent = "▶ Reproduzir"; };
    const playBtn = btn("▶ Reproduzir", () => {
      if (timer) return parar();
      if (passo >= nPassos - 1) ir(0);
      playBtn.textContent = "⏸ Pausar";
      timer = setInterval(() => { if (passo >= nPassos - 1) return parar(); ir(passo + 1); }, velocidade);
    });
    range.addEventListener("input", () => { parar(); ir(+range.value - 1); });
    const vel = h("select", { "aria-label": "Velocidade" }, [["Lenta", 500], ["Normal", 150], ["Rápida", 40]].map(([t, v]) => h("option", { value: v, selected: v === velocidade }, t)));
    vel.addEventListener("change", () => { velocidade = +vel.value; if (timer) { parar(); playBtn.click(); } });
    const ctl = h("div", { class: "ctl" }, btn("⏮ Início", () => { parar(); ir(0); }), btn("◀ Voltar", () => { parar(); ir(passo - 1); }), btn("Avançar ▶", () => { parar(); ir(passo + 1); }), btn("Fim ⏭", () => { parar(); ir(nPassos - 1); }),
      playBtn, vel, range, numEl);
    const arv = h("details", {}, h("summary", {}, `Árvore de derivação de G2 (${a.nos} nós) — não é a AST`), nota("A árvore de derivação mostra cada produção da gramática aplicada; a AST (aba AST) é a estrutura abstrata que o compilador realmente constrói."), arvore([convDeriv(a.arvore)], { nivel: 2 }));
    const out = h("div", {}, topo, h("h3", {}, "Passo a passo (análise preditiva tabular de G2)"), ctl, contEl, pilhaEl, entradaEl, acaoEl,
      h("h3", {}, "Tabela M (a célula consultada fica em destaque)"), M.el, h("h3", {}, "Todos os passos"), tabPassos, h("div", {}, arv));
    ir(Math.min(passo, nPassos - 1), false);
    return out;
  },
  ast() {
    const a = P.ast;
    if (!a.arvore) return h("div", {}, nota(a.estado === "falhou" ? "O parser real rejeitou o programa; não há AST." : "Etapa não executada (etapa anterior falhou).", "alerta"), a.estado === "falhou" ? h("p", { class: "erro" }, P.sintatica.real.erro) : null);
    const raizes = a.arvore.map(x => conv(x));
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("AST (JSON)", "ast_json"), botaoExp("AST (texto)", "ast_txt")),
      nota("AST real devolvida por parse_program. Árvore de derivação (G2) e AST são coisas diferentes: veja a aba Análise sintática para a derivação.", "forte"),
      nota(a.posicoes), arvore(raizes, { extra: extraInstr() }), tabelaCorrespondencia(), h("details", {}, h("summary", {}, "Representação textual (treeprint)"), textoPre(a.texto)));
  },
  ir() {
    const i = P.ir;
    if (!i.arvore) return h("div", {}, nota("Etapa não executada: " + (P.falha ? "uma etapa anterior falhou." : ""), "alerta"));
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("IR (JSON)", "ir_json"), botaoExp("IR (texto)", "ir_txt")),
      nota("IR real devolvida por lower_ir (antes da otimização). Instruções: store (atribuição), print, branch (condicional), foreach (repetição), function, return; expressões: constant, load, binary, call, list, aggregate, filter, map, limit.", "forte"),
      arvore(i.arvore.map(x => conv(x)), { extra: extraInstr() }), tabelaCorrespondencia(), h("details", {}, h("summary", {}, "Representação textual (treeprint)"), textoPre(i.texto)));
  },
  semantica() {
    const s = P.semantica;
    const bloq = P.etapas_nao_realizadas;
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("Análise semântica (TXT)", "semantica")),
      h("div", { class: "cartao " + (s.estado === "ok" ? "ok" : s.estado === "falhou" ? "falhou" : "") }, h("b", {}, "validate_ir: "), s.estado === "ok" ? "o programa passou na validação semântica." : s.estado === "falhou" ? "o programa foi REJEITADO." : "não executada (etapa anterior falhou)."),
      s.erro ? h("div", {}, h("h3", {}, `Diagnóstico real (código ${s.codigo})`), h("p", { class: "erro mono" }, s.erro), h("pre", {}, s.diagnostico || ""), s.posicao ? btn(`Ir para ${pos(s.posicao.linha, s.posicao.coluna)}`, () => fechar(true, s.posicao)) : nota("Este erro semântico não traz posição no código: o validador trabalha sobre a IR, que não guarda posições.")) : null,
      bloq.length ? nota("Etapas que NÃO puderam ser realizadas por causa da falha: " + bloq.join("; ") + ". Programas rejeitados não são executados pelo compilador nem pela IDE.", "forte alerta") : null,
      h("h3", {}, "Funções e importações (da AST real)"), s.funcoes.length ? tabela(["Função", "Parâmetros", "Aridade"], s.funcoes.map(f => [f.nome, f.parametros.join(", "), f.aridade]), { mono: [0, 1] }) : nota("Nenhuma função declarada."),
      h("h3", {}, "O que validate_ir verifica"), nota("Lista documentada (docs/src/internals/compiler.md e mensagens do validador), não uma medição desta execução.", ""), h("ul", {}, s.verificacoes_documentadas.map(v => h("li", {}, v))),
      nota(s.observacao_tipos, "forte alerta"));
  },
  otimizacao() {
    const o = P.otimizacao;
    if (o.estado !== "ok") return h("div", {}, nota("Otimização não realizada: " + (o.mensagem || "etapa anterior falhou."), "alerta"));
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("Otimizações (TXT)", "otimizacoes")),
      h("div", { class: "cartao " + (o.aplicada ? "ok" : "") }, h("b", {}, o.mensagem)),
      nota("O otimizador (optimize_ir) é conservador: dobra comparações entre literais numéricos e elimina ramos de condicionais com condição booleana literal. Esta tela não adiciona otimizações.", ""),
      o.mudancas.length ? h("div", {}, h("h3", {}, "Transformações identificadas"), nota("Classificação feita pela IDE ao comparar as duas IRs reais (o otimizador não registra o que fez). A prova é a diferença abaixo.", "alerta"),
        tabela(["Tipo", "Antes", "Depois", "Detalhe"], o.mudancas.map(m => [m.tipo, m.antes, m.depois, m.detalhe]), { mono: [1, 2] })) : null,
      h("h3", {}, "IR antes e depois"), lado(textoPre(o.texto_antes), textoPre(o.texto_depois), "IR validada (antes)", "IR otimizada (depois)"),
      h("h3", {}, "Diferenças"), o.aplicada ? diffView(o.diff_ir) : nota("Sem diferenças."),
      h("h3", {}, "Contagem de nós"), tabela(["Nó", "Antes", "Depois"], [...new Set([...Object.keys(o.histograma_antes), ...Object.keys(o.histograma_depois)])].sort().map(k => [k, o.histograma_antes[k] || 0, o.histograma_depois[k] || 0])));
  },
  julia() { return painelJulia("normal"); },
  julia_o() { return painelJulia("otimizado"); },
  saida() {
    const ex = P.execucoes, caminhos = [["interpretador", "Interpretador (abt run)"], ["julia", "Código Julia gerado"], ["julia_otimizado", "Código Julia otimizado"]];
    const podeJulia = !!P.gerado.normal;
    const cartoes = h("div", { class: "grade" });
    const desenhar = () => {
      cartoes.replaceChildren(...caminhos.map(([k, rot]) => {
        const r = ex[k];
        return h("div", { class: "cartao " + (r ? (r.codigo_saida === 0 ? "ok" : "falhou") : "") }, h("b", {}, rot), r ? h("div", { class: "nota" }, `código de retorno ${r.codigo_saida} · ${r.ms} ms (tempo de parede do processo: inclui inicialização${k === "interpretador" ? "" : " e compilação da Julia"}) · ${r.codigo_saida === 0 ? "sucesso" : "falha"}`) : h("div", { class: "nota" }, "não executado"),
          r ? [h("div", { class: "nota" }, "saída padrão"), textoPre(r.saida || "(vazia)"), h("div", { class: "nota" }, "erro padrão"), textoPre(r.erro || "(vazio)")] : null);
      }));
      const feitos = caminhos.filter(([k]) => ex[k]);
      cmp.replaceChildren();
      if (feitos.length >= 2) {
        const ref = ex[feitos[0][0]];
        cmp.append(h("h3", {}, "Comparação dos caminhos executados"), tabela(["Caminho", "Código", "Saída igual à do 1º?", "Erro padrão igual?", "ms"], feitos.map(([k, rot]) => [rot, ex[k].codigo_saida, ex[k].saida === ref.saida ? "sim" : "NÃO", ex[k].erro === ref.erro ? "sim" : "não", ex[k].ms])),
          nota(feitos.every(([k]) => ex[k].saida === ref.saida && ex[k].codigo_saida === ref.codigo_saida) ? "Os caminhos executados produziram a mesma saída padrão e o mesmo código de retorno." : "Há DIVERGÊNCIA entre os caminhos executados (veja a tabela).", feitos.every(([k]) => ex[k].saida === ref.saida) ? "" : "alerta"));
      }
    };
    const cmp = h("div");
    const rodar = async ks => {
      ocupar(true);
      try { for (const k of ks) { try { ex[k] = await api("/api/executar_caminho", { codigo: P.codigo, caminho: k }); } catch (e) { ex[k] = { codigo_saida: -1, saida: "", erro: e.message, ms: 0 }; } desenhar(); } }
      finally { ocupar(false); }
    };
    desenhar();
    const semExec = P.falha ? nota(`O programa foi rejeitado na etapa "${P.estados.find(x => x.id === P.falha).rotulo}": a IDE não o executa.`, "forte alerta") : null;
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("Saída (TXT)", "saida")),
      nota("A execução é uma ação explícita: nada roda automaticamente. Cada botão executa UMA vez o programa inspecionado (efeitos colaterais, como ler dados/, acontecem a cada execução). Mesmo limite de tempo e isolamento em pasta temporária da execução normal.", "forte"),
      semExec,
      h("div", { class: "acoes" }, btn("▶ Interpretador", () => rodar(["interpretador"]), { disabled: !!P.falha }), btn("▶ Julia gerado", () => rodar(["julia"]), { disabled: !podeJulia }), btn("▶ Julia otimizado", () => rodar(["julia_otimizado"]), { disabled: !podeJulia }),
        btn("▶ Executar os três", () => rodar(["interpretador", "julia", "julia_otimizado"]), { disabled: !podeJulia })), cartoes, cmp);
  },
  desempenho() {
    const d = P.desempenho, max = Math.max(1, ...d.etapas.map(e => e.ms || 0), d.ms_carga_pacote || 0);
    const falhas = P.estados.filter(e => e.estado === "falhou");
    const linhaBarra = (rot, ms, aq) => [rot, ms == null ? "—" : ms, aq == null ? "—" : aq, h("div", {}, h("div", { class: "barra", style: `width:${Math.max(1, (ms || 0) / max * 100)}%` }), aq != null ? h("div", { class: "barra aq", style: `width:${Math.max(1, aq / max * 100)}%` }) : null)];
    return h("div", {}, h("div", { class: "acoes" }, botaoExp("Desempenho (CSV)", "desempenho_csv"), botaoExp("Inspeção completa (JSON)", "inspecao_json"), botaoExp("Relatório HTML", "relatorio_html"), botaoExp("Tudo (ZIP)", "relatorio_zip")),
      h("h3", {}, "Diagnósticos"), falhas.length ? falhas.map(f => h("div", { class: "cartao falhou" }, h("b", {}, f.rotulo + " falhou"), h("pre", {}, ({ lexica: P.lexica.diagnostico, sintatica: P.sintatica.real.diagnostico, semantica: P.semantica.diagnostico }[f.id]) || "(sem diagnóstico detalhado)"))) : h("div", { class: "cartao ok" }, "Nenhuma etapa falhou."),
      P.etapas_nao_realizadas.length ? nota("Etapas não realizadas: " + P.etapas_nao_realizadas.join("; ")) : null,
      h("h3", {}, "Tempos medidos"), nota(d.nota),
      !d.instrumentado ? nota("Instrumentação desligada: só a 1ª chamada de cada etapa foi medida (inclui compilação JIT). Marque \"medir tempos\" no topo e inspecione de novo para ver também o tempo aquecido.", "") : null,
      tabela(["Etapa", "1ª chamada (ms)", "Aquecido (ms)", ""], [["Carga do pacote ABT (using ABT)", d.ms_carga_pacote, null, null], ...d.etapas.map(e => [e.rotulo, e.ms, e.ms_aquecido])].map(([r, m, a_]) => linhaBarra(r, m, a_)), {}),
      h("h3", {}, "Resumo"), tabela(["Medida", "ms"], [["Total medido dentro da Julia (carga + etapas)", d.ms_total_julia], ["Tempo de parede do processo da inspeção", d.ms_parede], ["Início do processo (parede − medido)", d.ms_inicio_processo], ["Análise tabular de G2 (IDE, didática)", d.ms_ide_g2]]),
      nota("Não medido: o tempo de execução aparece na aba Saída, por caminho. Julia: " + (P.julia || "") + " · ABT " + P.versao));
  },
};
function painelJulia(qual) {
  const g = P.gerado, outro = qual === "normal" ? "otimizado" : "normal", txt = g[qual];
  if (!txt) return h("div", {}, nota("O compilador não gerou este código: " + (P.falha ? `falha na etapa "${P.estados.find(x => x.id === P.falha).rotulo}".` : "etapa anterior falhou."), "alerta"));
  const cb = btn("📋 Copiar", () => copiar(txt, cb)), comp = h("div"), cx = codigoComNumeros(txt);
  let cmpOn = false;
  const bc = btn("⇄ Comparar com a versão " + (qual === "normal" ? "otimizada" : "normal"), () => {
    cmpOn = !cmpOn; bc.classList.toggle("on", cmpOn); comp.replaceChildren();
    if (cmpOn) comp.append(h("h3", {}, "Diferenças (normal → otimizado)"), g.iguais ? nota("As duas versões são idênticas: nenhuma otimização alterou o código gerado.") : diffView(g.diff));
  });
  return h("div", {}, h("div", { class: "acoes" }, cb, botaoExp("Baixar .jl", qual === "normal" ? "julia" : "julia_otimizado"), bc),
    nota(`Texto exato devolvido pelo gerador ${qual === "normal" ? "(IR validada, sem otimização)" : "(IR otimizada)"}, sem edição. ${g.iguais ? "É idêntico ao da outra versão." : ""} Geração: ${g["ms_" + qual]} ms (1ª chamada).`, "forte"),
    comp, h("h3", {}, qual === "normal" ? "Código Julia gerado" : "Código Julia otimizado"), cx);
}

// ───────────── casca ─────────────
function ocupar(v) { ocupado = v; raiz.querySelectorAll("button").forEach(b => { if (v) b.dataset.d = b.disabled ? "1" : "0"; b.disabled = v ? true : b.dataset.d === "1"; }); }
function trocar(nova) { aba = nova; atualizar(); }
function atualizar() {
  if (timer) { clearInterval(timer); timer = null; }
  subst(abasEl, ...ABAS.map(([id, rot, etapa]) => {
    const est = etapa && P ? (P.estados.find(x => x.id === etapa) || {}).estado : null;
    return h("button", { class: "aba" + (id === aba ? " ativa" : ""), on: { click: () => trocar(id) } }, est ? h("span", { class: "pt " + (est === "ok" ? "ok" : est === "falhou" ? "falhou" : "") }) : null, rot);
  }));
  subst(fasesEl, h("b", {}, "Pipeline: "), ...P.estados.flatMap((e, i) => [i ? h("span", { class: "seta" }, "→") : null, h("span", { class: "fase " + e.estado, title: e.estado === "ok" ? "concluída" : e.estado === "falhou" ? "falhou" : "não executada", on: { click: () => trocar(({ lexica: "lexica", sintatica: "sintatica", ir: "ir", semantica: "semantica", otimizacao: "otimizacao", geracao: "julia", geracao_otimizada: "julia_o" })[e.id]) } }, e.rotulo.replace("Geração de código Julia otimizado", "Julia otimizado").replace("Geração de código Julia", "Julia").replace("Análise sintática (parser real)", "Sintática"))]));
  subst(corpo, PAINEIS[aba]());
  verObsoleto();
}
function verObsoleto() {
  const velho = P && ed.value !== P.codigo;
  avisoEl.hidden = !velho;
}
function ativarTema() { if (tema === "auto") document.documentElement.removeAttribute("data-tema"); else document.documentElement.setAttribute("data-tema", tema); }
function abrir() { raiz.hidden = false; document.body.classList.add("insp-aberto"); }
function fechar(irEditor, p) { raiz.hidden = true; document.body.classList.remove("insp-aberto"); if (timer) { clearInterval(timer); timer = null; } if (irEditor) { ed.focus(); if (p) irPara(p.linha, p.coluna); } }
async function inspecionar(codigo) {
  if (ocupado) return;
  const cod = codigo ?? ed.value;
  abrir();
  subst(corpo, h("div", { class: "carregando" }, "Compilando… A primeira inspeção carrega a Julia e a ABT e pode levar alguns segundos."));
  ocupar(true);
  try {
    P = await api("/api/inspecionar", { codigo: cod, instrumentar });
    selTokens = new Set(); passo = 0;
    tituloEl.textContent = `Inspeção · ABT ${P.versao.replace(/^ABT\s*/, "")}`;
    const alvo = P.falha ? ({ lexica: "lexica", sintatica: "sintatica", ir: "ir", semantica: "semantica" })[P.falha] : null;
    if (alvo && aba === "fonte") aba = alvo;
    ocupar(false); atualizar();
  } catch (e) {
    ocupar(false);
    subst(corpo, h("div", { class: "cartao falhou" }, h("b", { class: "erro" }, "Não foi possível inspecionar: "), String(e.message || e)));
    P = P || null;
  }
}
function montar() {
  tituloEl = h("h2", {}, "Inspeção");
  const medir = h("input", { type: "checkbox", id: "insp-medir" }); medir.addEventListener("change", () => (instrumentar = medir.checked));
  const temaBtn = btn("Tema: auto", () => { tema = temas[(temas.indexOf(tema) + 1) % 3]; temaBtn.textContent = "Tema: " + tema; ativarTema(); guardar("abt-ide-tema", tema); });
  const fonte = (d) => () => { const v = Math.max(10, Math.min(30, (parseFloat(getComputedStyle(raiz).getPropertyValue("--insp-fs")) || 14) + d)); raiz.style.setProperty("--insp-fs", v); guardar("abt-ide-fonte", String(v)); };
  const exp = h("select", { "aria-label": "Exportar" }, h("option", { value: "" }, "Exportar…"), [["relatorio_html", "Relatório HTML"], ["relatorio_zip", "Tudo (ZIP)"], ["inspecao_json", "Inspeção completa (JSON)"], ["tokens_simbolos", "Tokens e símbolos (TXT)"], ["normalizado", "Código normalizado (TXT)"], ["passos", "Passo a passo sintático (TXT)"], ["resultado_sintatico", "Resultado sintático (TXT)"], ["gramatica", "Gramática G2 (TXT)"], ["ast_json", "AST (JSON)"], ["ir_json", "IR (JSON)"], ["julia", "Julia (.jl)"], ["julia_otimizado", "Julia otimizado (.jl)"]].map(([v, t]) => h("option", { value: v }, t)));
  exp.addEventListener("change", () => { if (exp.value && P) exportar(exp.value); exp.value = ""; });
  const ref = btn("Programa de referência", () => { if (!ed.value.trim() || ed.value === CFG.referencia || confirm("Substituir o código atual pelo programa de referência (média da turma)?")) { definir(CFG.referencia, "referência (média da turma)"); inspecionar(); } }, { title: "Carrega e inspeciona o programa acadêmico de referência" });
  avisoEl = h("div", { class: "aviso", hidden: true }, "O código no editor mudou: estes resultados estão DESATUALIZADOS (refletem a versão inspecionada).", btn("Inspecionar a versão atual", () => inspecionar()));
  fasesEl = h("div", { class: "fases" }); abasEl = h("div", { class: "abas" }); corpo = h("div", { class: "corpo" });
  raiz = h("div", { class: "insp", hidden: true, role: "dialog", "aria-label": "Inspeção do compilador" },
    h("div", { class: "topo" }, tituloEl, btn("← Voltar ao editor", () => fechar(true)), btn("↻ Inspecionar de novo", () => inspecionar(), { class: "principal" }), ref,
      h("label", { title: "Repete cada etapa 5 vezes para medir também o tempo sem compilação JIT" }, medir, "medir tempos"),
      h("span", { class: "esp" }), btn("A−", fonte(-1), { title: "Diminuir a fonte" }), btn("A+", fonte(1), { title: "Aumentar a fonte" }), temaBtn,
      btn("⛶ Tela cheia", () => { if (document.fullscreenElement) document.exitFullscreen(); else document.documentElement.requestFullscreen && document.documentElement.requestFullscreen(); }), exp),
    avisoEl, fasesEl, abasEl, corpo);
  document.body.append(raiz);
  const t = ler("abt-ide-tema"); if (temas.includes(t)) { tema = t; temaBtn.textContent = "Tema: " + tema; ativarTema(); }
  const f = parseFloat(ler("abt-ide-fonte")); if (f >= 10 && f <= 30) raiz.style.setProperty("--insp-fs", f);
  ed.addEventListener("input", () => { if (P) verObsoleto(); });
  document.addEventListener("keydown", e => {
    if (e.key === "Escape" && !raiz.hidden) { e.preventDefault(); fechar(true); }
    else if ((e.key === "i" || e.key === "I") && (e.ctrlKey || e.metaKey) && !e.shiftKey) { e.preventDefault(); inspecionar(); }
  });
  const b = h("button", { id: "inspecionar", title: "Ctrl+I — mostra o que o compilador faz em cada etapa", on: { click: () => inspecionar() } }, "🔍 Inspecionar");
  $("verificar").after(b);
  window.ABT_INSP = { inspecionar, estado: () => P };
}
montar();
})();
