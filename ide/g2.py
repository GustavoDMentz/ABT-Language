"""Gramática acadêmica G2 e análise preditiva tabular (FERRAMENTA DIDÁTICA; NÃO é o parser da ABT).

A ABT real usa análise descendente recursiva (src/ABT.jl, `parse_program`). Este módulo calcula, a partir das
produções em `g2.txt`, os conjuntos FIRST e FOLLOW e a tabela M, e simula o analisador preditivo com pilha
sobre os tokens que o lexer REAL da ABT produziu. Nada aqui é escrito à mão além das próprias produções.
"""
from pathlib import Path

EPS = "ε"
FIM = "$"
ARQUIVO_G2 = Path(__file__).resolve().parent / "g2.txt"

# Token do lexer real da ABT -> terminal de G2. Os demais tokens (operadores e pontuação) têm tipo == lexema.
TERMINAL_DE = {"IDENT": "id", "NUMBER": "num", "SHOW": "mostrar", "IF": "se", "ELSE": "senao",
               "FOR": "para", "EACH": "cada", "IN": "em"}


class Gramatica:
    def __init__(self, texto, nome="G2"):
        self.nome = nome
        self.regras = []          # [(A, (X1..Xn))]; produção vazia = ()
        self.nts = []
        for linha in texto.splitlines():
            linha = linha.strip()
            if not linha or linha.startswith("#"):
                continue
            esq, dir_ = [p.strip() for p in linha.split("->", 1)]
            if esq not in self.nts:
                self.nts.append(esq)
            for alt in dir_.split(" | "):
                simbolos = tuple(alt.split())
                self.regras.append((esq, () if simbolos == (EPS,) else simbolos))
        self.inicial = self.nts[0]
        self.terminais = []
        for _, rhs in self.regras:
            for s in rhs:
                if s not in self.nts and s not in self.terminais:
                    self.terminais.append(s)

    def texto_regra(self, i):
        a, rhs = self.regras[i - 1]
        return "%s → %s" % (a, " ".join(rhs) if rhs else EPS)


def anulaveis(g):
    nul, mudou = set(), True
    while mudou:
        mudou = False
        for a, rhs in g.regras:
            if a not in nul and all(s in nul for s in rhs):
                nul.add(a)
                mudou = True
    return nul


def first_de_seq(g, seq, first, nul):
    """FIRST de uma sequência de símbolos e se ela é anulável."""
    out = set()
    for s in seq:
        out |= first[s] if s in g.nts else {s}
        if s not in nul:
            return out, False
    return out, True


def first_follow(g):
    nul = anulaveis(g)
    first = {a: set() for a in g.nts}
    mudou = True
    while mudou:
        mudou = False
        for a, rhs in g.regras:
            f, _ = first_de_seq(g, rhs, first, nul)
            if not f <= first[a]:
                first[a] |= f
                mudou = True
    follow = {a: set() for a in g.nts}
    follow[g.inicial].add(FIM)
    mudou = True
    while mudou:
        mudou = False
        for a, rhs in g.regras:
            for i, s in enumerate(rhs):
                if s in g.nts:
                    f, tudo = first_de_seq(g, rhs[i + 1:], first, nul)
                    novo = f | (follow[a] if tudo else set())
                    if not novo <= follow[s]:
                        follow[s] |= novo
                        mudou = True
    return nul, first, follow


def tabela_m(g, first, follow, nul):
    """M[(A, t)] = [(produção, origem)], origem = 'FIRST' (t ∈ FIRST(α)) ou 'FOLLOW' (α anulável e t ∈ FOLLOW(A))."""
    M = {}
    for i, (a, rhs) in enumerate(g.regras, start=1):
        f, tudo = first_de_seq(g, rhs, first, nul)
        for t in f:
            M.setdefault((a, t), []).append((i, "FIRST"))
        if tudo:
            for t in follow[a]:
                M.setdefault((a, t), []).append((i, "FOLLOW"))
    conflitos = sorted((a, t, [p for p, _ in ps]) for (a, t), ps in M.items() if len(ps) > 1)
    return M, conflitos


class G2:
    """Gramática carregada com FIRST, FOLLOW e M calculados (uma vez)."""

    def __init__(self, texto=None):
        self.g = Gramatica(texto if texto is not None else ARQUIVO_G2.read_text(encoding="utf-8"))
        self.nul, self.first, self.follow = first_follow(self.g)
        self.M, self.conflitos = tabela_m(self.g, self.first, self.follow, self.nul)

    def para_dict(self):
        g = self.g
        colunas = sorted(g.terminais) + [FIM]
        return {
            "nome": g.nome,
            "inicial": g.inicial,
            "terminais": list(g.terminais),
            "nao_terminais": list(g.nts),
            "producoes": [{"n": i, "esq": a, "dir": list(rhs), "texto": g.texto_regra(i)}
                          for i, (a, rhs) in enumerate(g.regras, start=1)],
            "anulaveis": sorted(self.nul),
            "first": {a: sorted(self.first[a]) for a in g.nts},
            "follow": {a: sorted(self.follow[a]) for a in g.nts},
            "colunas": colunas,
            "tabela_m": [{"nt": a, "terminal": t, "producoes": [p for p, _ in ps], "origem": [o for _, o in ps]}
                         for (a, t), ps in sorted(self.M.items())],
            "conflitos": [{"nt": a, "terminal": t, "producoes": ps} for a, t, ps in self.conflitos],
            "ll1": not self.conflitos,
            "celulas": len(self.M),
        }


class No:
    def __init__(self, simbolo, token=None):
        self.simbolo, self.token, self.filhos, self.producao, self.indice = simbolo, token, [], None, None

    def para_dict(self):
        d = {"s": self.simbolo}
        if self.token is not None:
            d["lexema"] = self.token
            d["i"] = self.indice
        if self.producao:
            d["p"] = self.producao
        if self.filhos:
            d["f"] = [f.para_dict() for f in self.filhos]
        return d


def terminal_do_token(tipo):
    return TERMINAL_DE.get(tipo, tipo)


def fora_do_recorte(g2, tokens):
    """Tokens reais cujo terminal não pertence a G2 (a ABT os aceita, mas G2 não os descreve)."""
    t2 = set(g2.g.terminais)
    return [{"indice": t["indice"], "lexema": t["lexema"], "tipo": t["tipo"], "linha": t["linha"], "coluna": t["coluna"]}
            for t in tokens if terminal_do_token(t["tipo"]) not in t2]


def analisar(g2, tokens):
    """Análise preditiva tabular de G2.

    `tokens`: lista de dicts do lexer real, SEM o EOF (chaves tipo, lexema, linha, coluna, indice).
    Devolve dict com passos, aceita, erro (primeiro erro), contadores e árvore de derivação.
    A contagem de passos inclui o estado inicial e, se houver, o passo final de aceitação.
    """
    g = g2.g
    fita = [(terminal_do_token(t["tipo"]), t) for t in tokens] + [(FIM, None)]
    raiz = No(g.inicial)
    pilha = [No(FIM), raiz]          # topo = fim da lista
    pos = 0
    passos = []
    contagem = {"producoes": 0, "casamentos": 0}

    def pilha_txt():
        return [n.simbolo for n in reversed(pilha)]

    def fita_txt():
        return [t for t, _ in fita[pos:]]

    def registrar(acao, consulta=None, producao=None, tipo="inicio", **extra):
        passo = {"n": len(passos) + 1, "pilha": pilha_txt(), "entrada": fita_txt(),
                 "atual": fita[pos][0] if pos < len(fita) else FIM, "consulta": consulta,
                 "producao": producao, "tipo": tipo, "acao": acao, "pos": pos}
        passo.update(extra)
        passos.append(passo)

    registrar("estado inicial: pilha = [%s, %s]" % (FIM, g.inicial), tipo="inicio")
    erro = None
    aceita = False
    while pilha:
        topo = pilha[-1]
        a = fita[pos][0]
        tok = fita[pos][1]
        if topo.simbolo == FIM and a == FIM:
            registrar("aceita: pilha e entrada chegaram a %s" % FIM, tipo="aceita")
            aceita = True
            break
        if topo.simbolo in g.nts:
            cel = g2.M.get((topo.simbolo, a))
            consulta = {"nt": topo.simbolo, "terminal": a, "producoes": [p for p, _ in cel] if cel else []}
            if not cel or len(cel) > 1:
                msg = ("M[%s, %s] está vazia" % (topo.simbolo, a)) if not cel else \
                      ("M[%s, %s] tem conflito: %s" % (topo.simbolo, a, cel))
                erro = _erro(msg, tok, a, topo.simbolo, pos, tipo="celula_vazia" if not cel else "conflito")
                registrar("ERRO: " + msg, consulta=consulta, tipo="erro")
                break
            p = cel[0][0]
            _, rhs = g.regras[p - 1]
            topo.producao = p
            pilha.pop()
            filhos = [No(s) for s in rhs] or [No(EPS)]
            topo.filhos = filhos
            for f in reversed([f for f in filhos if f.simbolo != EPS]):
                pilha.append(f)
            contagem["producoes"] += 1
            registrar("aplica %s" % g.texto_regra(p), consulta=consulta, producao=p, tipo="producao")
        elif topo.simbolo == a:
            topo.token = tok["lexema"] if tok else ""
            topo.indice = pos
            pilha.pop()
            pos += 1
            contagem["casamentos"] += 1
            registrar("casa o terminal %s" % a, tipo="casamento", casado=a)
        else:
            msg = "esperado %s, encontrado %s" % (topo.simbolo, a)
            erro = _erro(msg, tok, a, topo.simbolo, pos, tipo="terminal_diferente")
            registrar("ERRO: " + msg, tipo="erro")
            break
    else:
        erro = _erro("pilha esvaziada antes do fim", None, FIM, None, pos, tipo="pilha_vazia")
    return {"aceita": aceita, "erro": erro, "passos": passos, "n_passos": len(passos),
            "producoes_aplicadas": contagem["producoes"], "tokens_casados": contagem["casamentos"],
            "sequencia_producoes": sequencia_producoes(raiz), "arvore": raiz.para_dict(), "nos": contar_nos(raiz)}


def _erro(msg, tok, terminal, esperado_topo, pos, tipo):
    e = {"mensagem": msg, "tipo": tipo, "terminal_encontrado": terminal, "topo": esperado_topo, "posicao_token": pos}
    if tok is not None:
        e.update(lexema=tok["lexema"], linha=tok["linha"], coluna=tok["coluna"])
    else:
        e["fim_da_entrada"] = True
    return e


def sequencia_producoes(no):
    """Produções aplicadas em pré-ordem (= derivação mais à esquerda)."""
    out = [no.producao] if no.producao else []
    for c in no.filhos:
        out += sequencia_producoes(c)
    return out


def contar_nos(no):
    return 1 + sum(contar_nos(c) for c in no.filhos)
