#!/usr/bin/env python3
"""Rejeita caminhos pessoais e segredos nos arquivos versionados.

  python3 tools/check_privacy.py              confere os arquivos versionados (usado no CI)
  python3 tools/check_privacy.py --historico  confere também todo o histórico do git (informativo)
  python3 tools/check_privacy.py --historico --estrito   o histórico também faz o comando falhar

Fora de um repositório git, confere a árvore de arquivos. Arquivos que não são UTF-8 são lidos
com substituição de caracteres (um segredo em ASCII continua visível), nunca ignorados.
"""
from pathlib import Path
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
MAX_BYTES = 20 * 1024 * 1024
PATTERNS = {
    "Linux home": re.compile(r"/home/[A-Za-z0-9_-]+(?:/|\b)"),
    "macOS home": re.compile(r"/Users/[A-Za-z0-9_-]+(?:/|\b)"),
    "Windows home": re.compile(r"[A-Za-z]:\\Users\\[^\\\s]+", re.I),
    "GitHub token": re.compile(r"\b(?:ghp_|gho_|ghu_|ghs_|ghr_|github_pat_)[A-Za-z0-9_]{20,}"),
    "AWS access key": re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"),
    "Slack token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    "API key (sk-)": re.compile(r"\bsk-[A-Za-z0-9_-]{32,}"),
    "Private key": re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY"),
}
# Exemplos públicos e inofensivos que não devem ser tratados como achados.
PERMITIDOS = {"/home/runner", "/home/linuxbrew"}


def achados(texto):
    """Devolve (rótulo, número da linha) para cada ocorrência no texto."""
    saida = []
    for rotulo, padrao in PATTERNS.items():
        for m in padrao.finditer(texto):
            if m.group(0).rstrip("/") in PERMITIDOS:
                continue
            saida.append((rotulo, texto.count("\n", 0, m.start()) + 1))
    return saida


def arquivos_da_arvore():
    try:
        nomes = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT, stderr=subprocess.DEVNULL).decode().split("\0")
        return [n for n in nomes if n]
    except (subprocess.CalledProcessError, FileNotFoundError):
        encontrados = []
        for pasta, dirs, nomes in os.walk(ROOT):
            dirs[:] = [d for d in dirs if d != ".git"]
            encontrados += [str((Path(pasta) / n).relative_to(ROOT)) for n in nomes]
        return encontrados


def conferir_arvore():
    problemas = []
    for nome in arquivos_da_arvore():
        caminho = ROOT / nome
        if not caminho.is_file() or caminho.is_symlink() or caminho.stat().st_size > MAX_BYTES:
            continue
        texto = caminho.read_bytes().decode("utf-8", errors="replace")
        problemas += [f"{nome}:{linha}: {rotulo}" for rotulo, linha in achados(texto)]
    return problemas


def conferir_historico():
    """Procura nos trechos adicionados de todos os commits (git log -p --all)."""
    try:
        saida = subprocess.run(["git", "log", "--all", "-p", "--no-color", "--format=commit %H"], cwd=ROOT,
                               capture_output=True, check=True).stdout.decode("utf-8", errors="replace")
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    problemas, commit, arquivo = set(), "", ""
    for linha in saida.splitlines():
        if linha.startswith("commit "):
            commit = linha[7:19]
        elif linha.startswith("+++ b/"):
            arquivo = linha[6:]
        elif linha.startswith("+") and not linha.startswith("+++"):
            for rotulo, _ in achados(linha[1:]):
                problemas.add(f"{commit} {arquivo}: {rotulo}")
    return sorted(problemas)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    falhou = False
    problemas = conferir_arvore()
    if problemas:
        print("\n".join(problemas))
        falhou = True
    else:
        print("Privacy check passed: no personal paths or secret-shaped strings in tracked files.")
    if "--historico" in argv:
        historico = conferir_historico()
        if historico is None:
            print("Histórico: não é um repositório git; nada a conferir.")
        elif historico:
            print(f"Histórico: {len(historico)} ocorrência(s) em commits antigos (a árvore atual está limpa?):")
            print("\n".join(historico[:50]) + ("\n..." if len(historico) > 50 else ""))
            print("Removê-las exige reescrever o histórico (git filter-repo) e force-push; decida com o dono do repositório.")
            falhou = falhou or "--estrito" in argv
        else:
            print("Histórico: nenhuma ocorrência.")
    return int(falhou)


if __name__ == "__main__":
    raise SystemExit(main())
