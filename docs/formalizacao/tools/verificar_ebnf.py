#!/usr/bin/env python3
"""Verificação EMPÍRICA da EBNF da especificação (§7.2) contra o analisador sintático REAL da ABT.

O que faz:
  1. GERA programas aleatórios por derivação da EBNF do §7.2 (este script é um gerador; NÃO interpreta nem analisa ABT);
  2. entrega cada programa ao `tokenize` + `parse_program` originais da ABT (tools/analisar_sintaxe.jl);
  3. conta quantos o analisador real aceita.
  Controle negativo (informativo): remove um símbolo estrutural de cada programa e verifica que o analisador real
  passa a rejeitar a maioria dos mutantes — mostra que o teste não é vacuoso.

O que demonstra: nas amostras geradas, a EBNF NÃO é mais permissiva do que o analisador real.
O que NÃO demonstra: que o analisador real não aceita programas que a EBNF não gera (completude), nem equivalência
de linguagens, nem qualquer propriedade como LL(1).

Uso:
    python3 tools/verificar_ebnf.py --abt-repo /caminho/ABT-Language [--n 500] [--julia julia]
"""
import argparse, json, os, random, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NOMES = ["x", "y", "total", "a1", "i2", "dados", "resultado", "b_2"]
TEXTOS = ['"texto"', '"a b"', '"x\\ny"']


class Gerador:
    def __init__(self, rng):
        self.r = rng

    def nome(self):
        return self.r.choice(NOMES)

    def lista(self, d):
        n = self.r.randint(0, 3)
        return "[ " + " , ".join(self.expr(d - 1) for _ in range(n)) + " ]"

    def argumentos(self, d):
        return " , ".join(self.expr(d - 1) for _ in range(self.r.randint(0, 3)))

    def atomo_simples(self, d):  # fonte de formas de coleção: nome, lista ou expressão entre parênteses
        k = self.r.random()
        if k < 0.5 or d <= 0:
            return self.nome()
        return self.lista(d) if k < 0.8 else "( " + self.expr(d - 1) + " )"

    def atomo(self, d):
        r = self.r
        if d <= 0:
            return r.choice([str(r.randint(0, 99)), self.nome(), "verdadeiro", "falso"])
        k = r.random()
        if k < 0.18: return str(r.randint(0, 9999))
        if k < 0.30: return f"{r.randint(0, 99)}.{r.randint(0, 99)}"
        if k < 0.36: return r.choice(TEXTOS)
        if k < 0.42: return r.choice(["verdadeiro", "falso"])
        if k < 0.50: return self.lista(d)
        if k < 0.60: return "( " + self.expr(d - 1) + " )"
        if k < 0.70: return f"{self.nome()} ( {self.argumentos(d)} )"                      # chamada
        if k < 0.74: return f"{self.nome()} . {self.nome()}"                               # campo
        if k < 0.78: return f"{self.nome()} de {self.nome()}"                              # campo de registro
        if k < 0.82: return "valor"
        if k < 0.86: return f"{r.choice(['soma', 'media'])} de {self.atomo_simples(d - 1)}" + (f" onde {self.expr(d - 1)}" if r.random() < 0.5 else "")
        if k < 0.89: return f"filtrar {self.atomo_simples(d - 1)} onde {self.expr(d - 1)}"
        if k < 0.92: return f"transformar {self.atomo_simples(d - 1)} com {self.expr(d - 1)}"
        if k < 0.94: return f"limitar {self.atomo_simples(d - 1)} a {r.choice([str(r.randint(0, 5)), self.nome()])}"
        return self.nome()

    def potencia(self, d):
        a = self.atomo(d)
        return f"{a} ^ {self.unario(d - 1)}" if d > 0 and self.r.random() < 0.15 else a

    def unario(self, d):
        if d > 0 and self.r.random() < 0.15:
            return self.r.choice(["+", "-"]) + " " + self.unario(d - 1)
        return self.potencia(d)

    def produto(self, d):
        t = [self.unario(d)]
        while d > 0 and self.r.random() < 0.3:
            t += [self.r.choice(["*", "/"]), self.unario(d - 1)]
        return " ".join(t)

    def soma(self, d):
        t = [self.produto(d)]
        while d > 0 and self.r.random() < 0.3:
            t += [self.r.choice(["+", "-"]), self.produto(d - 1)]
        return " ".join(t)

    def relacao(self, d):
        t = [self.soma(d)]
        while d > 0 and self.r.random() < 0.25:
            t += [self.r.choice([">", "<", ">=", "<=", "==", "!=", "é", "é maior", "é menor", "é maior que", "é menor que"]), self.soma(d - 1)]
        return " ".join(t)

    def conj(self, d):
        t = [self.relacao(d)]
        while d > 0 and self.r.random() < 0.2:
            t += [self.r.choice(["e", "and"]), self.relacao(d - 1)]
        return " ".join(t)

    def expr(self, d):
        t = [self.conj(d)]
        while d > 0 and self.r.random() < 0.2:
            t += [self.r.choice(["ou", "or"]), self.conj(d - 1)]
        return " ".join(t)

    def bloco(self, d):
        n = self.r.randint(0, 3)
        return "{ " + " ".join(self.instrucao(d - 1) + (" ;" if self.r.random() < 0.3 else "") for _ in range(n)) + " }"

    def instrucao(self, d):
        r = self.r
        k = r.random()
        if k < 0.30 or d <= 0: return f"{self.nome()} = {self.expr(2)}"
        if k < 0.50: return f"{r.choice(['mostrar', 'show'])} {self.expr(2)}"
        if k < 0.65: return f"{r.choice(['se', 'if'])} {self.expr(2)} {self.bloco(d)}" + (f" {r.choice(['senao', 'senão', 'else'])} {self.bloco(d)}" if r.random() < 0.5 else "")
        if k < 0.78: return f"{r.choice(['para', 'for'])} {r.choice(['cada', 'each'])} {self.nome()} {r.choice(['em', 'in'])} {self.expr(2)} {self.bloco(d)}"
        if k < 0.88:
            ps = " , ".join(r.sample(NOMES, r.randint(0, 3)))
            return f"{r.choice(['função', 'funcao', 'function'])} {self.nome()} ( {ps} ) {self.bloco(d)}"
        if k < 0.95: return f"{r.choice(['retornar', 'return'])} {self.expr(2)}"
        return r.choice(["usar Julia . Statistics", "usar Python . math", "usar Python . os . path"])

    def programa(self):
        n = self.r.randint(1, 6)
        partes = []
        for _ in range(n):
            if self.r.random() < 0.1:
                partes.append(";")
            partes.append(self.instrucao(3))
        return self.r.choice(["\n", " "]).join(partes) + "\n"


def analisar(julia, repo, programas):
    with tempfile.TemporaryDirectory() as d:
        for i, p in enumerate(programas):
            (Path(d) / f"{i:05d}.abt").write_text(p, encoding="utf-8")
        r = subprocess.run([julia, "--startup-file=no", f"--project={repo}", str(ROOT / "tools/analisar_sintaxe.jl"), d],
                           capture_output=True, text=True, timeout=1200)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[-2000:])
    out = {}
    for linha in r.stdout.splitlines():
        partes = linha.split("\t")
        out[int(partes[0][:5])] = (partes[1], partes[2] if len(partes) > 2 else "")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--abt-repo", required=True)
    ap.add_argument("--julia", default=os.environ.get("ABT_JULIA", "julia"))
    ap.add_argument("--n", type=int, default=500)
    ap.add_argument("--seed", type=int, default=15)
    ap.add_argument("--json", default=str(ROOT / "evidencias/verificacao_ebnf.json"))
    a = ap.parse_args()
    rng = random.Random(a.seed)
    g = Gerador(rng)
    programas = [g.programa() for _ in range(a.n)]
    res = analisar(a.julia, a.abt_repo, programas)
    aceitos = sum(1 for i in range(a.n) if res[i][0] == "ok")
    recusados = [(i, res[i][1]) for i in range(a.n) if res[i][0] != "ok"]
    # controle negativo: remove um símbolo estrutural e confere que o analisador real rejeita a maioria
    estrut = ["{", "}", "=", "(", ")", "[", "]"]
    mutantes = []
    for p in programas:
        toks = p.split(" ")
        idx = [i for i, t in enumerate(toks) if t.strip("\n") in estrut]
        if idx:
            del toks[rng.choice(idx)]
            mutantes.append(" ".join(toks))
    resm = analisar(a.julia, a.abt_repo, mutantes) if mutantes else {}
    rejeitados = sum(1 for i in range(len(mutantes)) if resm[i][0] != "ok")
    resumo = dict(abt=subprocess.run([a.julia, "--startup-file=no", f"--project={a.abt_repo}", "-e", 'using ABT; println("ABT importada")'], capture_output=True, text=True).stdout.strip(),
                  semente=a.seed, programas_gerados=a.n, aceitos_pelo_analisador_real=aceitos, recusados=len(recusados),
                  mutantes=len(mutantes), mutantes_rejeitados=rejeitados,
                  amostra_de_recusados=[dict(indice=i, mensagem=m, programa=programas[i]) for i, m in recusados[:10]],
                  tamanho_medio_em_caracteres=round(sum(map(len, programas)) / a.n),
                  exemplos=programas[:3])
    Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    Path(a.json).write_text(json.dumps(resumo, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{aceitos}/{a.n} programas gerados pela EBNF aceitos pelo analisador real; {rejeitados}/{len(mutantes)} mutantes rejeitados")
    for i, m in recusados[:5]:
        print(f"--- recusado #{i}: {m}\n{programas[i]}")
    return 0 if not recusados else 1


if __name__ == "__main__":
    sys.exit(main())
