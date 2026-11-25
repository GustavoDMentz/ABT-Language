"""Exportação da inspeção: cada arquivo é formatado a partir do pacote de dados REAL da inspeção
(`inspecao.construir_pacote`); nada é recalculado nem inventado aqui."""
import csv
import html
import io
import json
import zipfile

BOM = "﻿"
CABECALHO = "ABT IDE — inspeção do compilador (ABT %s)"


def _tabela(cab, linhas):
    cols = [cab] + [[str(c) for c in l] for l in linhas]
    larg = [max(len(l[i]) for l in cols) for i in range(len(cab))]
    fmt = lambda l: "  ".join(str(c).ljust(larg[i]) for i, c in enumerate(l)).rstrip()
    return "\n".join([fmt(cab), "  ".join("-" * w for w in larg)] + [fmt([str(c) for c in l]) for l in linhas])


def _csv(cab, linhas):
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(cab)
    w.writerows(linhas)
    return buf.getvalue()


def _cab(p, titulo):
    return "%s\n%s\nPrograma: %d linhas, SHA-256 %s\n\n" % (CABECALHO % p["versao"], titulo, len(p["codigo"].splitlines()), p["hash"][:16])


def _fmt_valor(v):
    return "" if v is None else (str(v).lower() if isinstance(v, bool) else str(v))


def tokens_simbolos_txt(p):
    lex = p["lexica"]
    toks = [t for t in lex["tokens"] if not t["eof"]]
    s = _cab(p, "Tabela de tokens e tabela de símbolos")
    s += "1. TABELA DE TOKENS (lexer real da ABT)\n"
    if lex["parcial"]:
        s += "ERRO LÉXICO: %s\n(tokens reconhecidos antes do erro)\n" % lex["erro"]
    s += _tabela(["#", "Lexema", "Token", "Padrão (expressão regular)", "Linha", "Coluna", "Valor"],
                 [[t["indice"], t["lexema"], t["tipo"], t["regra"], t["linha"], t["coluna"], _fmt_valor(t["valor"])] for t in toks])
    s += "\n\n2. TABELA DE SÍMBOLOS DEFINIDOS PELO USUÁRIO (derivada dos tokens)\n"
    sim = p["simbolos"]["usuario"]
    s += _tabela(["Nome", "Categoria", "Escopo de definição", "1ª ocorrência", "Definições", "Usos"],
                 [[x["nome"], x["categoria"], ", ".join(x["escopos_de_definicao"]) or "-", "%d:%d" % (x["primeira"]["linha"], x["primeira"]["coluna"]),
                   " ".join("%d:%d" % (o["linha"], o["coluna"]) for o in x["definicoes"]) or "-",
                   " ".join("%d:%d" % (o["linha"], o["coluna"]) for o in x["usos"]) or "-"] for x in sim])
    if p["simbolos"]["embutidos_usados"]:
        s += "\n\nEmbutidas/contextuais usadas (não são símbolos do usuário): " + ", ".join("%s (%s)" % (x["nome"], x["categoria"]) for x in p["simbolos"]["embutidos_usados"])
    s += "\n\nTipos e valores não são exibidos: o compilador não os expõe (ver painel Análise semântica).\n"
    return s


def tokens_csv(p):
    return _csv(["indice", "lexema", "tipo", "regra", "linha", "coluna", "valor", "origem"],
                [[t["indice"], t["lexema"], t["tipo"], t["regra"], t["linha"], t["coluna"], _fmt_valor(t["valor"]), "pipeline" if t["sintetico"] else "texto"]
                 for t in p["lexica"]["tokens"] if not t["eof"]])


def simbolos_csv(p):
    return _csv(["nome", "categoria", "escopos_de_definicao", "primeira_linha", "primeira_coluna", "definicoes", "usos"],
                [[x["nome"], x["categoria"], ";".join(x["escopos_de_definicao"]), x["primeira"]["linha"], x["primeira"]["coluna"],
                  ";".join("%d:%d" % (o["linha"], o["coluna"]) for o in x["definicoes"]),
                  ";".join("%d:%d" % (o["linha"], o["coluna"]) for o in x["usos"])] for x in p["simbolos"]["usuario"]])


def normalizado_txt(p):
    return _cab(p, "Código normalizado (identificadores → id, números → num)") + p["normalizado"]["texto"]


def passos_txt(p):
    a = p["sintatica"]["g2"]
    s = _cab(p, "Análise sintática preditiva tabular de G2 (NÃO é o parser real da ABT)")
    if a is None:
        return s + "Não realizada: erro léxico.\n"
    s += _tabela(["Passo", "Pilha (topo à esquerda)", "Entrada restante", "Consulta M", "Ação"],
                 [[x["n"], " ".join(x["pilha"]), " ".join(x["entrada"]),
                   ("M[%s, %s] = %s" % (x["consulta"]["nt"], x["consulta"]["terminal"], ", ".join(map(str, x["consulta"]["producoes"])) or "vazia")) if x["consulta"] else "-",
                   x["acao"]] for x in a["passos"]])
    s += "\n\nPassos: %d | produções aplicadas: %d | tokens casados: %d\n" % (a["n_passos"], a["producoes_aplicadas"], a["tokens_casados"])
    return s


def resultado_sintatico_txt(p):
    sint = p["sintatica"]
    s = _cab(p, "Resultado e diagnóstico sintático")
    a = sint["g2"]
    s += "Análise de G2 (gramática acadêmica):\n"
    if a is None:
        s += "  não realizada (erro léxico)\n"
    elif a["aceita"]:
        s += "  ACEITO em %d passos (%d produções, %d tokens casados)\n" % (a["n_passos"], a["producoes_aplicadas"], a["tokens_casados"])
    else:
        e = a["erro"]
        s += "  REJEITADO no passo %d. Primeiro erro: %s\n" % (a["n_passos"], e["mensagem"])
        if "linha" in e:
            s += "  Posição: linha %d, coluna %d, lexema %r\n" % (e["linha"], e["coluna"], e["lexema"])
        else:
            s += "  Posição: fim da entrada\n"
    s += "\nParser real da ABT (descendente recursivo, src/ABT.jl):\n"
    r = sint["real"]
    if r["estado"] == "ok":
        s += "  aceito\n"
    elif r["estado"] == "nao_executada":
        s += "  não executado (etapa anterior falhou)\n"
    else:
        s += "  REJEITADO: %s\n  Diagnóstico: %s\n" % (r["erro"], (r.get("diagnostico") or "").replace("\n", " "))
    s += "\nVeredito: %s\n" % sint["veredito"]["texto"]
    if sint["fora_do_recorte"]:
        s += "\nSímbolos fora do recorte de G2:\n" + "\n".join("  %d:%d  %s (%s)" % (f["linha"], f["coluna"], f["lexema"], f["tipo"]) for f in sint["fora_do_recorte"]) + "\n"
    return s


def gramatica_txt(p):
    g = p["g2"]
    s = _cab(p, "Gramática G2: produções, FIRST, FOLLOW e tabela M (calculados programaticamente)")
    s += "Símbolo inicial: %s\nNão terminais (%d): %s\nTerminais (%d): %s\n\n" % (
        g["inicial"], len(g["nao_terminais"]), " ".join(g["nao_terminais"]), len(g["terminais"]), " ".join(g["terminais"]))
    s += "PRODUÇÕES\n" + "\n".join("%3d: %s" % (x["n"], x["texto"]) for x in g["producoes"])
    s += "\n\nFIRST\n" + "\n".join("%-11s { %s }" % (a, ", ".join(v)) for a, v in g["first"].items())
    s += "\n\nFOLLOW\n" + "\n".join("%-11s { %s }" % (a, ", ".join(v)) for a, v in g["follow"].items())
    s += "\n\nTABELA M (%d células preenchidas; conflitos: %d)\n" % (g["celulas"], len(g["conflitos"]))
    s += _tabela(["M[A, t]", "Produção", "Origem"], [["M[%s, %s]" % (c["nt"], c["terminal"]), ",".join(map(str, c["producoes"])),
                                                       ",".join(c["origem"])] for c in g["tabela_m"]])
    s += "\n\nG2 é LL(1)? %s. Isto vale só para G2, que é um recorte da ABT; não afirma que a linguagem ABT completa seja LL(1).\n" % ("sim (sem conflitos em M)" if g["ll1"] else "NÃO")
    return s


def tabela_m_csv(p):
    return _csv(["nao_terminal", "terminal", "producoes", "origem"],
                [[c["nt"], c["terminal"], ";".join(map(str, c["producoes"])), ";".join(c["origem"])] for c in p["g2"]["tabela_m"]])


def semantica_txt(p):
    s_ = p["semantica"]
    s = _cab(p, "Análise semântica (validate_ir)")
    s += "Estado: %s\n" % {"ok": "programa válido", "falhou": "REJEITADO", "nao_executada": "não executada (etapa anterior falhou)"}[s_["estado"]]
    if s_["erro"]:
        s += "Erro: %s\nCódigo: %s\nDiagnóstico: %s\n" % (s_["erro"], s_["codigo"], (s_["diagnostico"] or "").replace("\n", " "))
    if p["etapas_nao_realizadas"]:
        s += "Etapas não realizadas: %s\n" % "; ".join(p["etapas_nao_realizadas"])
    s += "\nFunções declaradas (da AST): %s\n" % (", ".join("%s(%s)" % (f["nome"], ", ".join(f["parametros"])) for f in s_["funcoes"]) or "nenhuma")
    s += "\n%s\n" % s_["observacao_tipos"]
    return s


def otimizacoes_txt(p):
    o = p["otimizacao"]
    s = _cab(p, "Otimizações (optimize_ir)") + o["mensagem"] + "\n"
    for m in o["mudancas"]:
        s += "- %s: %s → %s (%s)\n" % (m["tipo"], m["antes"], m["depois"], m["detalhe"])
    if o["diff_ir"]:
        s += "\nDiferença entre a IR validada e a IR otimizada:\n" + "\n".join("%s %s" % (m if m != "=" else " ", t) for m, t in o["diff_ir"]) + "\n"
    return s


def desempenho_csv(p):
    d = p["desempenho"]
    linhas = [["carga do pacote ABT (using ABT)", d["ms_carga_pacote"], ""]] + [[x["rotulo"], x["ms"], x["ms_aquecido"] if x["ms_aquecido"] is not None else ""] for x in d["etapas"]]
    linhas += [["tempo total medido na Julia", d["ms_total_julia"], ""], ["tempo de parede do processo", d["ms_parede"], ""],
               ["início do processo (parede − medido)", d["ms_inicio_processo"], ""]]
    return _csv(["etapa", "ms_primeira_chamada", "ms_aquecido"], linhas)


def saida_txt(p):
    s = _cab(p, "Saída das execuções solicitadas")
    if not p["execucoes"]:
        return s + "Nenhuma execução foi solicitada para este programa.\n"
    for caminho, r in p["execucoes"].items():
        s += "== %s: código %s, %s ms ==\n--- saída padrão ---\n%s\n--- erro padrão ---\n%s\n" % (caminho, r["codigo_saida"], r["ms"], r["saida"], r["erro"])
    return s


def _json(x):
    return json.dumps(x, ensure_ascii=False, indent=1) + "\n"


# id -> (nome do arquivo, tipo MIME, função(pacote) -> texto, tem BOM)
ITENS = {
    "tokens_simbolos": ("tokens_simbolos.txt", "text/plain", tokens_simbolos_txt),
    "tokens_csv": ("tokens.csv", "text/csv", tokens_csv),
    "simbolos_csv": ("simbolos.csv", "text/csv", simbolos_csv),
    "normalizado": ("codigo_normalizado.txt", "text/plain", normalizado_txt),
    "passos": ("passos_analise_sintatica.txt", "text/plain", passos_txt),
    "resultado_sintatico": ("resultado_sintatico.txt", "text/plain", resultado_sintatico_txt),
    "gramatica": ("gramatica_g2.txt", "text/plain", gramatica_txt),
    "tabela_m_csv": ("tabela_m.csv", "text/csv", tabela_m_csv),
    "g2_json": ("g2.json", "application/json", lambda p: _json(p["g2"])),
    "passos_json": ("passos_analise_sintatica.json", "application/json", lambda p: _json(p["sintatica"]["g2"])),
    "ast_json": ("ast.json", "application/json", lambda p: _json(p["ast"]["arvore"])),
    "ast_txt": ("ast.txt", "text/plain", lambda p: p["ast"]["texto"] or ""),
    "ir_json": ("ir.json", "application/json", lambda p: _json(p["ir"]["arvore"])),
    "ir_txt": ("ir.txt", "text/plain", lambda p: p["ir"]["texto"]),
    "semantica": ("analise_semantica.txt", "text/plain", semantica_txt),
    "otimizacoes": ("otimizacoes.txt", "text/plain", otimizacoes_txt),
    "julia": ("programa_gerado.jl", "text/plain", lambda p: p["gerado"]["normal"] or ""),
    "julia_otimizado": ("programa_gerado_otimizado.jl", "text/plain", lambda p: p["gerado"]["otimizado"] or ""),
    "desempenho_csv": ("desempenho.csv", "text/csv", desempenho_csv),
    "saida": ("saida.txt", "text/plain", saida_txt),
    "inspecao_json": ("inspecao.json", "application/json", _json),
}
SEM_BOM = (".json", ".jl")


def _bytes(nome, texto):
    if not nome.endswith(SEM_BOM):
        texto = BOM + texto
    return texto.encode("utf-8")


# ───────────── relatório HTML autossuficiente ─────────────
def relatorio_html(p):
    e = html.escape
    th = lambda cab: "<tr>" + "".join("<th>%s</th>" % e(str(c)) for c in cab) + "</tr>"
    td = lambda l: "<tr>" + "".join("<td>%s</td>" % e(str(c)) for c in l) + "</tr>"
    tab = lambda cab, linhas: "<div class=r><table>%s%s</table></div>" % (th(cab), "".join(td(l) for l in linhas))
    pre = lambda t: "<pre>%s</pre>" % e(t or "")
    toks = [t for t in p["lexica"]["tokens"] if not t["eof"]]
    estados = "".join("<li class=%s>%s <b>%s</b>%s</li>" % (x["estado"], e(x["rotulo"]), {"ok": "ok", "falhou": "falhou", "nao_executada": "não executada"}[x["estado"]],
                                                           (" · %s ms" % x["ms"]) if x["ms"] is not None and x["estado"] != "nao_executada" else "") for x in p["estados"])
    sec = []
    sec.append("<h2 id=src>Código-fonte</h2>" + pre(p["codigo"]))
    sec.append("<h2 id=lex>Análise léxica</h2>" + (("<p class=falhou>Erro léxico: %s</p>" % e(p["lexica"]["erro"])) if p["lexica"]["parcial"] else "") +
               tab(["#", "Lexema", "Token", "Padrão", "Linha", "Coluna", "Valor"], [[t["indice"], t["lexema"], t["tipo"], t["regra"], t["linha"], t["coluna"], _fmt_valor(t["valor"])] for t in toks]))
    sec.append("<h2 id=sim>Tabela de símbolos</h2>" + tab(["Nome", "Categoria", "Escopo", "1ª ocorrência", "Definições", "Usos"],
               [[x["nome"], x["categoria"], ", ".join(x["escopos_de_definicao"]) or "-", "%d:%d" % (x["primeira"]["linha"], x["primeira"]["coluna"]),
                 " ".join("%d:%d" % (o["linha"], o["coluna"]) for o in x["definicoes"]), " ".join("%d:%d" % (o["linha"], o["coluna"]) for o in x["usos"])] for x in p["simbolos"]["usuario"]]))
    sec.append("<h2 id=norm>Código normalizado</h2>" + pre(p["normalizado"]["texto"]))
    g = p["g2"]
    sec.append("<h2 id=g2>Gramática G2, FIRST, FOLLOW e tabela M</h2><p>Tabela calculada programaticamente a partir das produções. G2 é um recorte da ABT; "
               "a ABT real usa análise descendente recursiva.</p>" + pre("\n".join(x["texto"] for x in g["producoes"])) +
               tab(["Não terminal", "FIRST", "FOLLOW"], [[a, " ".join(g["first"][a]), " ".join(g["follow"][a])] for a in g["nao_terminais"]]) +
               tab(["M[A, t]", "Produção", "Origem"], [["%s, %s" % (c["nt"], c["terminal"]), ",".join(map(str, c["producoes"])), ",".join(c["origem"])] for c in g["tabela_m"]]))
    a = p["sintatica"]["g2"]
    sec.append("<h2 id=sint>Análise sintática</h2><p><b>%s</b></p>" % e(p["sintatica"]["veredito"]["texto"]) +
               ("" if a is None else tab(["Passo", "Pilha", "Entrada", "Ação"], [[x["n"], " ".join(x["pilha"]), " ".join(x["entrada"]), x["acao"]] for x in a["passos"]])))
    sec.append("<h2 id=ast>AST</h2>" + pre(p["ast"]["texto"]) + "<p>%s</p>" % e(p["ast"]["posicoes"]))
    sec.append("<h2 id=ir>IR</h2>" + pre(p["ir"]["texto"]))
    sec.append("<h2 id=sem>Análise semântica</h2>" + pre(semantica_txt(p)))
    o = p["otimizacao"]
    sec.append("<h2 id=opt>Otimizações</h2><p>%s</p>" % e(o["mensagem"]) + "".join("<p>%s</p>" % e("%s: %s → %s" % (m["tipo"], m["antes"], m["depois"])) for m in o["mudancas"]) +
               pre("\n".join("%s %s" % (m if m != "=" else " ", t) for m, t in o["diff_ir"])))
    sec.append("<h2 id=jl>Código Julia gerado</h2>" + pre(p["gerado"]["normal"]) + "<h2 id=jlo>Código Julia otimizado</h2>" +
               ("<p>Idêntico ao código normal.</p>" if p["gerado"]["iguais"] else pre(p["gerado"]["otimizado"])))
    sec.append("<h2 id=out>Saída</h2>" + pre(saida_txt(p)))
    d = p["desempenho"]
    sec.append("<h2 id=perf>Desempenho</h2>" + tab(["Etapa", "ms (1ª chamada)", "ms (aquecido)"], [[x["rotulo"], x["ms"], x["ms_aquecido"] if x["ms_aquecido"] is not None else "-"] for x in d["etapas"]]) + "<p>%s</p>" % e(d["nota"]))
    css = ("body{font:15px/1.5 system-ui,sans-serif;max-width:1100px;margin:24px auto;padding:0 16px;color:#1f2328;background:#fff}"
           "pre{background:#f4f3ee;padding:12px;overflow:auto;border-radius:6px;font:13px/1.45 ui-monospace,Consolas,monospace}"
           "table{border-collapse:collapse;font-size:13px}th,td{border:1px solid #d9d7d0;padding:3px 8px;text-align:left;vertical-align:top}th{background:#f0efe9}"
           ".r{overflow:auto;max-height:520px;margin:8px 0}li.ok b{color:#0b6b57}li.falhou b,.falhou{color:#b42318}li.nao_executada{color:#6b7075}"
           "h2{border-bottom:1px solid #d9d7d0;padding-bottom:4px;margin-top:32px}"
           "@media (prefers-color-scheme:dark){body{background:#16181a;color:#e6e6e3}pre{background:#1e2124}th{background:#26292c}th,td{border-color:#383c40}}")
    return ("<!doctype html><html lang=pt-BR><head><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>"
            "<title>Inspeção ABT</title><style>%s</style></head><body><h1>Inspeção do compilador ABT</h1><p>%s · SHA-256 %s</p><ol>%s</ol>%s</body></html>" %
            (css, e(CABECALHO % p["versao"]), e(p["hash"][:16]), estados, "".join(sec)))


def exportar(p, item):
    """(nome, mime, bytes). `item` ∈ ITENS, 'relatorio_html' ou 'relatorio_zip'."""
    if item == "relatorio_html":
        return "relatorio_inspecao.html", "text/html", relatorio_html(p).encode("utf-8")
    if item == "relatorio_zip":
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
            for nome, _, fn in ITENS.values():
                z.writestr(nome, _bytes(nome, fn(p)))
            z.writestr("relatorio_inspecao.html", relatorio_html(p).encode("utf-8"))
            z.writestr("programa.abt", p["codigo"].encode("utf-8"))
        return "inspecao_abt.zip", "application/zip", buf.getvalue()
    if item not in ITENS:
        raise KeyError(item)
    nome, mime, fn = ITENS[item]
    return nome, mime, _bytes(nome, fn(p))
