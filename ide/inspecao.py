"""Inspeção do compilador ABT para a IDE.

Tudo o que o COMPILADOR produz (tokens, AST, IR, diagnósticos, otimização, código Julia, tempos) vem de
`inspecionar.jl`, que chama as funções originais da ABT. Este módulo só organiza esses dados e acrescenta o que é
claramente da IDE e fica rotulado como tal: tabelas léxica/de símbolos derivadas dos tokens reais, código
normalizado, a análise preditiva tabular de G2 (didática; não é o parser da ABT) e diferenças entre representações.
"""
import difflib
import hashlib
import json
import re
import shutil
import tempfile
import threading
import time
from pathlib import Path

import g2 as gramatica
import processos

PASTA = Path(__file__).resolve().parent
SCRIPT_JULIA = PASTA / "inspecionar.jl"
PASTA_EXEMPLOS = PASTA / "exemplos"
TEMPO_MAX = 60

ETAPAS = [  # (id no resultado da Julia, rótulo)
    ("lexica", "Análise léxica"), ("sintatica", "Análise sintática (parser real)"), ("ir", "Geração da IR"),
    ("semantica", "Validação semântica"), ("otimizacao", "Otimização"), ("geracao", "Geração de código Julia"),
    ("geracao_otimizada", "Geração de código Julia otimizado"),
]

# Regras de reconhecimento do lexer real (src/ABT.jl, função `tokenize`). Os textos abaixo são as expressões
# regulares do código-fonte da ABT; test_inspecao.py confere que continuam presentes no src/ABT.jl instalado.
REGEX_NUMERO = r"\d+(?:\.\d+)?"
REGEX_TEXTO = r'"(?:\\.|[^"\\])*"'
REGEX_NOME = r"[^\W\d]\w*"
REGEX_OPERADOR = r"==|!=|>=|<=|[=+*/^><\-{},;\[\]().]"
INGLES = {"show", "average", "sum", "of", "where", "value", "is", "above", "below", "than", "if", "else", "for",
          "each", "in", "true", "false", "and", "or", "function", "return"}


def regra_do_token(tipo, palavras):
    if tipo == "NUMBER":
        return REGEX_NUMERO
    if tipo == "STRING":
        return REGEX_TEXTO
    if tipo == "IDENT":
        return REGEX_NOME + "  (e não é palavra reservada)"
    if tipo == "EOF":
        return "fim da entrada"
    if tipo in palavras:
        return REGEX_NOME + "  com lexema ∈ {" + ", ".join(palavras[tipo]) + "}  (sem distinção de maiúsculas)"
    return re.escape(tipo)      # operador/pontuação: o lexema literal (o lexer os testa na ordem de REGEX_OPERADOR)


# ───────────── execução da Julia ─────────────
class ErroInspecao(Exception):
    pass


def _gravar_programa(pasta, codigo):
    with open(Path(pasta) / "programa.abt", "w", encoding="utf-8", newline="\n") as f:
        f.write(codigo)
    dados = PASTA_EXEMPLOS / "dados"
    if dados.is_dir():
        shutil.copytree(dados, Path(pasta) / "dados")


def rodar_julia_inspecao(codigo, instrumentar=False):
    """Roda inspecionar.jl (só compila: não executa o programa). Devolve (json_bruto, ms_de_parede)."""
    raiz = processos.raiz_da_abt()
    if raiz is None:
        raise ErroInspecao("Instalação da ABT não encontrada (src/ABT.jl). Instale a ABT ou defina ABT_RAIZ.")
    julia, env = processos.localizar_julia(raiz)
    if julia is None:
        raise ErroInspecao("Julia não encontrada. Instale a ABT (runtime embutido) ou defina ABT_JULIA.")
    pasta = tempfile.mkdtemp(prefix="abt-ide-insp-")
    try:
        _gravar_programa(pasta, codigo)
        args = ["--startup-file=no", "--compile=yes", "--project=" + str(raiz), str(SCRIPT_JULIA), "programa.abt"]
        if instrumentar:
            args.append("--instrumentar")
        inicio = time.monotonic()
        try:
            proc = processos.iniciar_exe(julia, args, pasta, env)
        except OSError as e:
            raise ErroInspecao("Não foi possível iniciar a Julia: %s" % e)
        saida, erro, cod, estourou = processos.esperar(proc, TEMPO_MAX)
        ms = int((time.monotonic() - inicio) * 1000)
    finally:
        shutil.rmtree(pasta, ignore_errors=True)
    if estourou:
        raise ErroInspecao("Tempo esgotado (%d s) na inspeção; processo interrompido." % TEMPO_MAX)
    texto = saida.decode("utf-8", errors="replace").strip()
    try:
        return json.loads(texto), ms
    except ValueError:
        raise ErroInspecao("A Julia não devolveu JSON (código %s): %s" % (cod, erro.decode("utf-8", errors="replace")[-600:]))


# ───────────── utilidades ─────────────
POS = re.compile(r"(?:at|em) (\d+):(\d+)")


def posicao_do_erro(msg):
    m = POS.search(msg or "")
    return {"linha": int(m.group(1)), "coluna": int(m.group(2))} if m else None


def valor_do_token(tipo, lexema):
    if tipo == "NUMBER":
        return float(lexema) if "." in lexema else int(lexema)
    if tipo == "STRING":
        return bytes(lexema[1:-1], "utf-8").decode("unicode_escape") if "\\" in lexema else lexema[1:-1]
    if tipo in ("TRUE", "FALSE"):
        return tipo == "TRUE"
    return None


def palavras_por_token(reservadas):
    por = {}
    for r in reservadas:
        por.setdefault(r["token"], []).append(r["lexema"])
    return {k: sorted(v) for k, v in por.items()}


def desser(x):
    """Valor serializado pela Julia -> Python (nó: (tipo, [filhos]), lista: list, folha: valor)."""
    if "n" in x:
        return (x["n"], [desser(y) for y in x["a"]])
    if "l" in x:
        return [desser(y) for y in x["l"]]
    return x["v"]


def sha(codigo):
    return hashlib.sha256(codigo.encode("utf-8")).hexdigest()


# ───────────── tabelas léxicas (derivadas dos tokens reais) ─────────────
def montar_tokens(tokens_reais, reservadas, codigo=""):
    """Tabela léxica. `sintetico`: o lexema NÃO está no texto, na posição informada. Acontece com os tokens que o
    próprio lexer cria ao reescrever pipelines indentados (expand_pipelines): eles copiam a posição de outro token."""
    palavras = palavras_por_token(reservadas)
    linhas_src = codigo.split("\n")
    out = []
    n = 0
    for t in tokens_reais:
        eof = t["tipo"] == "EOF"
        if not eof:
            n += 1
        txt = linhas_src[t["linha"] - 1] if 0 < t["linha"] <= len(linhas_src) else ""
        sintetico = (not eof) and txt[t["coluna"] - 1:t["coluna"] - 1 + len(t["lexema"])] != t["lexema"]
        out.append({"sintetico": sintetico, "indice": None if eof else n, "lexema": t["lexema"], "tipo": t["tipo"],
                    "regra": regra_do_token(t["tipo"], palavras), "linha": t["linha"], "coluna": t["coluna"],
                    "comprimento": len(t["lexema"]), "valor": valor_do_token(t["tipo"], t["lexema"]),
                    "terminal_g2": gramatica.terminal_do_token(t["tipo"]) if not eof else None, "eof": eof})
    return out


def catalogo_reservadas(reservadas):
    grupos = {}
    for r in reservadas:
        grupos.setdefault(r["token"], []).append(r["lexema"])
    cat = []
    for token, lexemas in sorted(grupos.items()):
        cat.append({"token": token, "lexemas": sorted(lexemas),
                    "ingles": sorted(l for l in lexemas if l in INGLES),
                    "portugues": sorted(l for l in lexemas if l not in INGLES),
                    "terminal_g2": gramatica.TERMINAL_DE.get(token)})
    return cat


# Palavras contextuais do parser para operações de coleção (src/ABT.jl: collection_form / expand_pipelines).
# São IDENT para o lexer; só o parser as reconhece pelo contexto.
PALAVRAS_DE_COLECAO = ("filtrar", "transformar", "limitar")
DELIMITADORES_DE_COLECAO = ("com", "a")


def tabela_simbolos(tokens, embutidos):
    """Símbolos léxicos: percorre os tokens reais e classifica cada IDENT pelo contexto imediato (token anterior e
    seguinte e cabeçalho `função nome(...)`). Escopo: 'global' ou o nome da função cujo bloco contém o token."""
    toks = [t for t in tokens if not t["eof"]]
    emb = set(embutidos)
    escopo_pilha, profundidade = [], 0           # (nome, profundidade_ao_abrir)
    cab = None                                   # None | "nome" | "abre" | "params"
    nome_func = None
    ocorrencias = []
    for i, t in enumerate(toks):
        ant = toks[i - 1]["tipo"] if i else None
        prox = toks[i + 1]["tipo"] if i + 1 < len(toks) else None
        tipo = t["tipo"]
        if tipo == "FUNCTION":
            cab = "nome"
            continue
        if cab == "nome" and tipo in ("IDENT", "SUM", "AVG"):
            nome_func = t["lexema"]
            cab = "abre"
            ocorrencias.append((t, "definição", "função", "global"))
            continue
        if cab == "abre" and tipo == "(":
            cab = "params"
            continue
        if cab == "params":
            if tipo == "IDENT":
                ocorrencias.append((t, "definição", "parâmetro", nome_func))
            elif tipo == ")":
                cab = "corpo"
            continue
        if tipo == "{":
            profundidade += 1
            if cab == "corpo":
                escopo_pilha.append((nome_func, profundidade))
                cab = None
            continue
        if tipo == "}":
            if escopo_pilha and escopo_pilha[-1][1] == profundidade:
                escopo_pilha.pop()
            profundidade -= 1
            continue
        if tipo != "IDENT":
            continue
        escopo = escopo_pilha[-1][0] if escopo_pilha else "global"
        if ant == "." or (t["lexema"] in ("Julia", "Python") and prox == "."):
            continue                            # membro de módulo externo / namespace: não é símbolo do usuário
        if ant == "EACH":
            ocorrencias.append((t, "definição", "variável de laço", escopo))
        elif prox == "=":
            ocorrencias.append((t, "definição", "variável", escopo))
        elif prox == "(":
            ocorrencias.append((t, "uso", "chamada", escopo))
        else:
            ocorrencias.append((t, "uso", "leitura", escopo))
    por_nome = {}
    for t, papel, cat, escopo in ocorrencias:
        por_nome.setdefault(t["lexema"], []).append({"linha": t["linha"], "coluna": t["coluna"], "papel": papel,
                                                      "categoria": cat, "escopo": escopo, "indice": t["indice"]})
    simbolos, nao_usuario = [], []
    usa_colecao = any(n.lower() in PALAVRAS_DE_COLECAO for n in por_nome)
    for nome, occ in por_nome.items():
        defs = [o for o in occ if o["papel"] == "definição"]
        usos = [o for o in occ if o["papel"] == "uso"]
        if defs:
            categoria = defs[0]["categoria"]
        elif nome in emb:
            categoria = "função embutida"
        elif nome.lower() in PALAVRAS_DE_COLECAO or (usa_colecao and nome.lower() in DELIMITADORES_DE_COLECAO):
            categoria = "palavra contextual de coleção"
        else:
            categoria = "sem definição no texto"
        item = {"nome": nome, "categoria": categoria, "categorias_de_definicao": sorted({d["categoria"] for d in defs}),
                "primeira": {"linha": occ[0]["linha"], "coluna": occ[0]["coluna"]},
                "definicoes": defs, "usos": usos, "ocorrencias": len(occ),
                "escopos_de_definicao": sorted({d["escopo"] for d in defs}),
                "tipo": None}
        (nao_usuario if categoria in ("função embutida", "palavra contextual de coleção") else simbolos).append(item)
    return {"usuario": simbolos, "embutidos_usados": nao_usuario}


def normalizar(tokens):
    """Código normalizado: identificadores -> id, números -> num, a partir dos TOKENS (não de substituição textual).
    Mantém uma linha de saída por linha do texto original; comentários e espaços não existem para o lexer."""
    toks = [t for t in tokens if not t["eof"]]
    ultima = max((t["linha"] for t in toks), default=0)
    por_linha = {}
    for t in toks:
        norm = {"IDENT": "id", "NUMBER": "num"}.get(t["tipo"], t["lexema"])
        por_linha.setdefault(t["linha"], []).append({"original": t["lexema"], "normalizado": norm, "indice": t["indice"],
                                                      "coluna": t["coluna"]})
    linhas = [{"linha": n, "tokens": por_linha.get(n, []),
               "texto": " ".join(x["normalizado"] for x in por_linha.get(n, []))} for n in range(1, ultima + 1)]
    return {"linhas": linhas, "texto": "\n".join(l["texto"] for l in linhas) + ("\n" if linhas else "")}


# ───────────── AST / IR / otimização ─────────────
def assinaturas(ast_json):
    """Funções declaradas (nome, parâmetros) e importações, lidas da AST real."""
    funcoes, importacoes = [], []

    def visita(n):
        if "n" in n:
            if n["n"] == "function":
                nome = n["a"][0]["v"]
                params = [p["v"] for p in n["a"][1]["l"]]
                funcoes.append({"nome": nome, "parametros": params, "aridade": len(params)})
            elif n["n"] in ("import_julia", "import_python"):
                importacoes.append({"tipo": n["n"], "modulo": n["a"][0]["v"]})
            for f in n["a"]:
                visita(f)
        elif "l" in n:
            for f in n["l"]:
                visita(f)
    for n in ast_json:
        visita(n)
    return {"funcoes": funcoes, "importacoes": importacoes}


COMPARACOES = {">": lambda a, b: a > b, "<": lambda a, b: a < b, ">=": lambda a, b: a >= b, "<=": lambda a, b: a <= b,
               "==": lambda a, b: a == b, "!=": lambda a, b: a != b}


def render_expr(n):
    if "v" in n:
        return json.dumps(n["v"], ensure_ascii=False) if n["t"] == "String" else (
            str(n["v"]).lower() if n["t"] == "Bool" else str(n["v"]))
    if "l" in n:
        return "[" + ", ".join(render_expr(x) for x in n["l"]) + "]"
    a, k = n["a"], n["n"]
    if k == "constant":
        return render_expr(a[0])
    if k == "load":
        return a[0]["v"]
    if k == "binary":
        return "(%s %s %s)" % (render_expr(a[1]), a[0]["v"], render_expr(a[2]))
    return "%s(%s)" % (k, ", ".join(render_expr(x) for x in a))


def _numero(n):
    return n["n"] == "constant" and n["a"][0]["t"] in ("Int64", "Float64") and not isinstance(n["a"][0]["v"], str)


def _dobravel(n):
    """Comparação entre dois literais numéricos: o que `optimize_ir` dobra (src/ABT.jl, optimize_ir)."""
    if "n" in n and n["n"] == "binary" and n["a"][0]["v"] in COMPARACOES:
        return _numero(n["a"][1]) and _numero(n["a"][2])
    return False


def _valor_dobrado(n):
    return COMPARACOES[n["a"][0]["v"]](n["a"][1]["a"][0]["v"], n["a"][2]["a"][0]["v"])


def classificar_mudancas(antes, depois):
    """Transformações identificadas por inspeção estrutural das duas IRs reais. É uma CLASSIFICAÇÃO feita pela IDE
    (o otimizador não registra o que fez); a prova é o diff das próprias representações, exibido ao lado."""
    mudancas = []

    def valor_const(n):
        if "n" in n and n["n"] == "constant" and n["a"][0]["t"] == "Bool":
            return n["a"][0]["v"]
        return _valor_dobrado(n) if _dobravel(n) else None

    def visita(n, caminho):
        if "l" in n:
            for i, x in enumerate(n["l"]):
                visita(x, caminho)
            return
        if "n" not in n:
            return
        if n["n"] == "branch":
            cond, sim, nao = n["a"]
            v = valor_const(cond)
            if _dobravel(cond):
                mudancas.append({"tipo": "constant folding", "antes": render_expr(cond), "depois": str(v).lower(),
                                 "detalhe": "comparação entre literais numéricos"})
            if v is not None:
                mudancas.append({"tipo": "eliminação de ramo morto", "antes": "se %s { … } senao { … }" % render_expr(cond),
                                 "depois": "somente o ramo %s" % ("verdadeiro" if v else "falso"),
                                 "detalhe": "condição constante %s" % str(v).lower()})
                visita(sim if v else nao, caminho)
            else:
                visita(cond, caminho)
                visita(sim, caminho)
                visita(nao, caminho)
            return
        if _dobravel(n):
            mudancas.append({"tipo": "constant folding", "antes": render_expr(n), "depois": str(_valor_dobrado(n)).lower(),
                             "detalhe": "comparação entre literais numéricos"})
            return
        for f in n["a"]:
            visita(f, caminho)
    for n in antes:
        visita(n, [])
    return mudancas


def histograma(ir_json):
    h = {}

    def v(n):
        if "n" in n:
            h[n["n"]] = h.get(n["n"], 0) + 1
            for f in n["a"]:
                v(f)
        elif "l" in n:
            for f in n["l"]:
                v(f)
    for n in ir_json:
        v(n)
    return dict(sorted(h.items()))


def diff_linhas(a, b):
    """Diferença linha a linha entre dois textos: lista de [marca, texto] com marca '=', '-' ou '+'."""
    la, lb = a.splitlines(), b.splitlines()
    out = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, la, lb, autojunk=False).get_opcodes():
        if tag == "equal":
            out += [["=", x] for x in la[i1:i2]]
        else:
            out += [["-", x] for x in la[i1:i2]] + [["+", x] for x in lb[j1:j2]]
    return out


VERIFICACOES_DOCUMENTADAS = [
    "forma estrutural do IR, ciclos, profundidade e operandos (abt_check_ir_shape)",
    "variáveis não definidas / lidas antes da atribuição",
    "namespaces reservados (Python, Julia) usados como valor ou nome",
    "funções duplicadas, parâmetros duplicados e colisão entre nome de função e parâmetro",
    "aridade das chamadas a funções do usuário, da biblioteca padrão e de Julia.<módulo>.<função>",
    "tipos de operandos de operações aritméticas e comparações quando conhecidos (:unknown = não provável estaticamente)",
    "módulos Julia suportados/importados e atributos externos privados",
]


# ───────────── pacote completo ─────────────
def construir_pacote(codigo, bruto, ms_parede=None, ms_ide_g2=None):
    """Organiza a saída da Julia + as derivações da IDE num único dicionário (é o que a interface e as
    exportações usam). `bruto` é o JSON de inspecionar.jl."""
    e = bruto["etapas"]
    reservadas = bruto["palavras_reservadas"]
    lex = e["lexica"]
    parcial = not lex["ok"]
    reais = lex.get("tokens") if lex["ok"] else (lex.get("tokens_antes_do_erro") or [])
    if not lex["ok"]:
        reais = [dict(t) for t in reais]
    tokens = montar_tokens(reais, reservadas, codigo)
    sem_eof = [t for t in tokens if not t["eof"]]
    # Símbolos e código normalizado usam os tokens que estão no TEXTO, em ordem de leitura (sem os criados pela
    # reescrita de pipelines, que o parser vê mas o texto não contém).
    no_texto = sorted((t for t in tokens if not t["eof"] and not t["sintetico"]), key=lambda t: (t["linha"], t["coluna"]))
    simbolos = tabela_simbolos(no_texto, bruto.get("nomes_embutidos", []))
    normal = normalizar(no_texto)
    normal["omitidos"] = len(sem_eof) - len(no_texto)

    # estado e bloqueios por etapa
    estados, falha = [], None
    for ident, rotulo in ETAPAS:
        d = e[ident]
        estado = "nao_executada" if d.get("nao_executada") else ("ok" if d["ok"] else "falhou")
        if estado == "falhou" and falha is None:
            falha = ident
        estados.append({"id": ident, "rotulo": rotulo, "estado": estado, "ms": d.get("ms"), "ms_aquecido": d.get("ms_aquecido")})
    bloqueadas = [x["rotulo"] for x in estados if x["estado"] == "nao_executada"]

    # sintaxe: parser real x G2
    sint = e["sintatica"]
    real = {"ok": sint["ok"], "estado": [x for x in estados if x["id"] == "sintatica"][0]["estado"]}
    if not sint["ok"] and not sint.get("nao_executada"):
        real.update(erro=sint["erro"], codigo=sint.get("codigo"), diagnostico=sint.get("diagnostico"),
                    posicao=posicao_do_erro(sint["erro"]))
    g = gramatica.G2()
    t0 = time.monotonic()
    fora = gramatica.fora_do_recorte(g, sem_eof) if lex["ok"] else []
    analise = gramatica.analisar(g, sem_eof) if lex["ok"] else None
    ms_g2 = (time.monotonic() - t0) * 1000 if ms_ide_g2 is None else ms_ide_g2
    veredito = veredito_g2(lex["ok"], analise, fora, sint)

    ast_json = sint.get("ast")
    ir_json = e["ir"].get("ir")
    ir_opt = e["otimizacao"].get("ir_otimizada")
    ir_txt = e["ir"].get("ir_texto", "")
    ir_opt_txt = e["otimizacao"].get("ir_otimizada_texto", "")
    codigo_j = e["geracao"].get("codigo")
    codigo_o = e["geracao_otimizada"].get("codigo")

    sem = e["semantica"]
    semantica = {"estado": [x for x in estados if x["id"] == "semantica"][0]["estado"], "ok": sem["ok"],
                 "erro": sem.get("erro"), "codigo": sem.get("codigo"), "diagnostico": sem.get("diagnostico"),
                 "posicao": posicao_do_erro(sem.get("erro", "")),
                 "verificacoes_documentadas": VERIFICACOES_DOCUMENTADAS,
                 "tipos_inferidos": None,
                 "observacao_tipos": "validate_ir infere tipos internamente, mas não os devolve: a IDE não exibe tipos "
                                     "nem escopos que o compilador não expõe.",
                 **(assinaturas(ast_json) if ast_json else {"funcoes": [], "importacoes": []})}

    ot = e["otimizacao"]
    if ir_json is not None and ir_opt is not None:
        igual = ir_txt == ir_opt_txt
        otim = {"estado": "ok", "aplicada": not igual, "mudancas": [] if igual else classificar_mudancas(ir_json, ir_opt),
                "diff_ir": diff_linhas(ir_txt, ir_opt_txt), "texto_antes": ir_txt, "texto_depois": ir_opt_txt, "histograma_antes": histograma(ir_json),
                "histograma_depois": histograma(ir_opt),
                "mensagem": "Nenhuma otimização foi aplicada: a IR otimizada é idêntica à IR validada." if igual else
                            "A IR foi alterada pelo otimizador; veja as diferenças."}
        if not igual and not otim["mudancas"]:
            otim["mensagem"] += " (alterações não classificadas pela IDE; use o diff)"
    else:
        otim = {"estado": "nao_executada" if ot.get("nao_executada") else "falhou", "aplicada": None, "mudancas": [],
                "diff_ir": [], "mensagem": ot.get("erro", "Etapa não executada."), "erro": ot.get("erro")}

    gerado = {"normal": codigo_j, "otimizado": codigo_o,
              "diff": diff_linhas(codigo_j, codigo_o) if codigo_j and codigo_o else [],
              "iguais": (codigo_j == codigo_o) if codigo_j and codigo_o else None,
              "ms_normal": e["geracao"].get("ms"), "ms_otimizado": e["geracao_otimizada"].get("ms")}

    soma_julia = sum(x["ms"] or 0 for x in estados)
    desempenho = {"etapas": estados, "ms_carga_pacote": bruto.get("ms_carga_pacote"), "ms_total_julia": round(
        (bruto.get("ms_carga_pacote") or 0) + soma_julia, 3), "ms_parede": ms_parede, "instrumentado": bruto.get("instrumentado"),
        "ms_ide_g2": round(ms_g2, 3),
        "ms_inicio_processo": None if ms_parede is None else round(ms_parede - ((bruto.get("ms_carga_pacote") or 0) + soma_julia), 1),
        "nota": "ms = 1ª chamada na Julia (inclui compilação JIT); ms_aquecido = mediana de 5 repetições (só com instrumentação). "
                "ms_inicio_processo = tempo de parede menos o medido dentro do script (inicialização da Julia, leitura de "
                "arquivos). Tempos do lexer e do parser são muito pequenos porque o núcleo já vem pré-compilado."}

    correspondencia = []
    if ast_json is not None and sint.get("instrucoes_topo_conferem") and ir_json is not None and len(ir_json) == len(ast_json):
        for i, faixa in enumerate(sint["instrucoes_topo"]):
            a, b = sem_eof[faixa[0] - 1], sem_eof[min(faixa[1], len(sem_eof)) - 1]
            correspondencia.append({"instrucao": i + 1, "tokens": [faixa[0], faixa[1]], "linhas": [a["linha"], b["linha"]],
                                    "ast": ast_json[i]["n"], "ir": ir_json[i]["n"]})

    return {
        "hash": sha(codigo), "codigo": codigo, "versao": bruto["versao"], "julia": bruto.get("julia"),
        "estados": estados, "falha": falha, "etapas_nao_realizadas": bloqueadas,
        "lexica": {"ok": lex["ok"], "parcial": parcial, "erro": lex.get("erro"), "codigo": lex.get("codigo"),
                   "diagnostico": lex.get("diagnostico"), "posicao": posicao_do_erro(lex.get("erro", "")),
                   "tokens": tokens, "total": len(sem_eof), "sinteticos": sum(1 for t in sem_eof if t["sintetico"]), "reservadas": catalogo_reservadas(reservadas),
                   "palavras_reservadas_total": len(reservadas)},
        "simbolos": simbolos, "normalizado": normal,
        "g2": g.para_dict(),
        "sintatica": {"real": real, "g2": analise, "fora_do_recorte": fora, "veredito": veredito},
        "ast": {"estado": real["estado"], "arvore": ast_json, "texto": sint.get("ast_texto"),
                "posicoes": "A AST da ABT não guarda posições no código-fonte; só os intervalos de tokens das instruções "
                            "de nível superior são conhecidos (via parser real).",
                "instrucoes_topo": sint.get("instrucoes_topo")},
        "ir": {"estado": [x for x in estados if x["id"] == "ir"][0]["estado"], "arvore": ir_json, "texto": ir_txt,
               "erro": e["ir"].get("erro")},
        "correspondencia": correspondencia,
        "semantica": semantica, "otimizacao": otim, "gerado": gerado, "desempenho": desempenho,
        "execucoes": {},
    }


def veredito_g2(lex_ok, analise, fora, sint):
    if not lex_ok:
        return {"codigo": "lexico", "texto": "Análise sintática não realizada: o lexer real da ABT rejeitou o texto."}
    abt_ok = sint["ok"]
    if analise["aceita"] and abt_ok:
        return {"codigo": "aceito", "texto": "Aceito por G2 e pelo parser real da ABT."}
    if analise["aceita"] and not abt_ok:
        return {"codigo": "divergencia", "texto": "ATENÇÃO: G2 aceitou, mas o parser real da ABT rejeitou. Divergência "
                "entre a gramática acadêmica e a implementação; investigue."}
    if fora:
        itens = ", ".join("%s (%d:%d)" % (f["lexema"] or f["tipo"], f["linha"], f["coluna"]) for f in fora[:6])
        if abt_ok:
            return {"codigo": "fora_do_recorte", "texto": "Programa VÁLIDO na ABT, mas fora do recorte da gramática G2: "
                    "usa símbolos que G2 não contém (%s)." % itens}
        return {"codigo": "rejeitado_ambos", "texto": "Rejeitado por G2 e pelo parser real da ABT. Há também símbolos "
                "fora do recorte de G2: %s." % itens}
    if abt_ok:
        return {"codigo": "fora_do_recorte", "texto": "Programa VÁLIDO na ABT, mas G2 o rejeita: usa uma construção que G2 "
                "não descreve (a gramática acadêmica é um recorte da linguagem). Primeiro erro de G2: %s." %
                analise["erro"]["mensagem"]}
    return {"codigo": "rejeitado_ambos", "texto": "Rejeitado por G2 e pelo parser real da ABT."}


# ───────────── cache em memória e execução dos três caminhos ─────────────
_CACHE = {}
_TRAVA = threading.Lock()
CACHE_MAX = 16


def guardar(pacote):
    with _TRAVA:
        _CACHE[pacote["hash"]] = pacote
        while len(_CACHE) > CACHE_MAX:
            _CACHE.pop(next(iter(_CACHE)))


def obter(hash_):
    with _TRAVA:
        return _CACHE.get(hash_)


def inspecionar(codigo, instrumentar=False):
    inicio = time.monotonic()
    bruto, ms = rodar_julia_inspecao(codigo, instrumentar)
    pacote = construir_pacote(codigo, bruto, ms_parede=ms)
    pacote["ms_inspecao_total"] = int((time.monotonic() - inicio) * 1000)
    guardar(pacote)
    return pacote


CAMINHOS = ("interpretador", "julia", "julia_otimizado")


def executar_caminho(codigo, caminho, executar_abt):
    """Executa UM caminho, por pedido explícito. O código Julia vem do pacote inspecionado (gerado pelo compilador),
    nunca do cliente. `executar_abt(codigo, modo)` é a execução já existente da IDE (abt run)."""
    if caminho not in CAMINHOS:
        raise ErroInspecao("Caminho de execução desconhecido: %s" % caminho)
    if caminho == "interpretador":
        r = executar_abt(codigo, "run")
        r["caminho"] = caminho
    else:
        pacote = obter(sha(codigo)) or inspecionar(codigo)
        chave = "normal" if caminho == "julia" else "otimizado"
        fonte = pacote["gerado"][chave]
        if not fonte:
            raise ErroInspecao("O compilador não gerou código Julia para este programa (%s)." % (pacote["falha"] or "etapa anterior falhou"))
        r = _rodar_julia(fonte, caminho)
    pacote = obter(sha(codigo))
    if pacote is not None:
        pacote["execucoes"][caminho] = r
    return r


def _rodar_julia(fonte, caminho):
    raiz = processos.raiz_da_abt()
    julia, env = processos.localizar_julia(raiz) if raiz else (None, None)
    if julia is None:
        return {"caminho": caminho, "codigo_saida": 127, "saida": "", "erro": "Julia da ABT não encontrada.", "ms": 0}
    pasta = tempfile.mkdtemp(prefix="abt-ide-gen-")
    try:
        with open(Path(pasta) / "programa_gerado.jl", "w", encoding="utf-8", newline="\n") as f:
            f.write(fonte)
        dados = PASTA_EXEMPLOS / "dados"
        if dados.is_dir():
            shutil.copytree(dados, Path(pasta) / "dados")
        inicio = time.monotonic()
        try:
            proc = processos.iniciar_exe(julia, ["--startup-file=no", "--compile=yes", "--project=" + str(raiz),
                                                 "programa_gerado.jl"], pasta, env)
        except OSError as e:
            return {"caminho": caminho, "codigo_saida": 127, "saida": "", "erro": "Não foi possível iniciar a Julia: %s" % e, "ms": 0}
        saida, erro, cod, estourou = processos.esperar(proc, TEMPO_MAX)
        ms = int((time.monotonic() - inicio) * 1000)
    finally:
        shutil.rmtree(pasta, ignore_errors=True)
    dec = lambda b: b.decode("utf-8", errors="replace")
    erro_txt = dec(erro) + ("\nTempo esgotado (%d s); execução interrompida." % TEMPO_MAX if estourou else "")
    return {"caminho": caminho, "codigo_saida": cod, "saida": dec(saida), "erro": erro_txt, "ms": ms}
