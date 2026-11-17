#!/bin/sh
# Instalador integrado da ABT: traz a Julia 1.13.3 e os pacotes junto, sem sudo e sem Python.
#
#   curl -fsSL https://github.com/GustavoDMentz/ABT-Language/releases/latest/download/instalar.sh | sh
#
# O pacote traz uma cópia em <instalação>/libexec/instalar.sh, que atende aos comandos
# `abt atualizar`, `abt reparar` e `abt desinstalar`.
#
# Por que pré-compila no destino: os caches pré-compilados do Julia só valem no caminho
# exato onde a Julia estava quando foram gerados (docs/RELATORIO_INSTALADOR_INTEGRADO.md).
set -eu

REPO=${ABT_REPO:-GustavoDMentz/ABT-Language}
BASE_URL=${ABT_BASE_URL:-https://github.com/$REPO/releases}
PREFIXO=${ABT_PREFIXO:-${HOME:-}/.local/share/abt}
BIN_DIR=${ABT_BIN_DIR:-${HOME:-}/.local/bin}
PLATAFORMA=linux-x86_64
JULIA_VERSAO='julia version 1.13.3'

ACAO=instalar
VERSAO=latest
ARQUIVO=
SHA256_ESPERADO=
FORCAR=0
CONFIRMADO=0
BIN_EXPLICITO=0
SEM_VERIFICACAO=0
VERIFICAR_ATESTACAO=${ABT_VERIFICAR_ATESTACAO:-0}

uso() {
    cat <<'EOF'
Uso: instalar.sh [opções]

  --prefixo DIR      pasta da instalação (padrão: ~/.local/share/abt)
  --bin DIR          pasta do comando `abt` (padrão: ~/.local/bin)
  --versao X.Y.Z     versão a instalar (padrão: a mais recente)
  --arquivo ARQ      usa um pacote já baixado (instalação sem internet)
  --sha256 HEX       soma SHA-256 esperada de --arquivo
  --sem-verificacao  permite instalar --arquivo sem soma SHA-256 (não recomendado)
  --verificar-atestacao  confere a procedência do pacote baixado com `gh attestation verify`
  --forcar           reinstala mesmo que a versão já esteja instalada
  --atualizar        atualiza a instalação existente
  --reparar          pré-compila de novo (use se a pasta foi movida)
  --desinstalar      remove a ABT (use --sim para não pedir confirmação)
  --ajuda            mostra esta mensagem

Variáveis: ABT_PREFIXO, ABT_BIN_DIR, ABT_REPO, ABT_BASE_URL (só https://; http:// apenas em
localhost), ABT_VERIFICAR_ATESTACAO=1.
EOF
}

erro() {
    printf 'ABT: %s\n' "$*" >&2
    exit 1
}
aviso() { printf 'ABT: %s\n' "$*" >&2; }
info() { printf 'ABT: %s\n' "$*"; }

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefixo) [ "$#" -ge 2 ] || erro "--prefixo exige um valor"; PREFIXO=$2; shift ;;
        --bin) [ "$#" -ge 2 ] || erro "--bin exige um valor"; BIN_DIR=$2; BIN_EXPLICITO=1; shift ;;
        --versao) [ "$#" -ge 2 ] || erro "--versao exige um valor"; VERSAO=${2#v}; shift ;;
        --arquivo) [ "$#" -ge 2 ] || erro "--arquivo exige um valor"; ARQUIVO=$2; shift ;;
        --sha256) [ "$#" -ge 2 ] || erro "--sha256 exige um valor"; SHA256_ESPERADO=$2; shift ;;
        --sem-verificacao) SEM_VERIFICACAO=1 ;;
        --verificar-atestacao) VERIFICAR_ATESTACAO=1 ;;
        --forcar) FORCAR=1 ;;
        --sim) CONFIRMADO=1 ;;
        --instalar|--atualizar|--reparar|--desinstalar) ACAO=${1#--} ;;
        --ajuda|-h) uso; exit 0 ;;
        *) uso >&2; erro "opção desconhecida: $1" ;;
    esac
    shift
done

# `abt atualizar` roda a partir de uma cópia deste script; o launcher informa a instalação atual.
if [ -n "${ABT_PREFIXO_ATUAL:-}" ] && [ "$ACAO" != instalar ] && [ -z "${ABT_PREFIXO:-}" ]; then
    PREFIXO=$ABT_PREFIXO_ATUAL
fi
[ -n "$PREFIXO" ] && [ -n "$BIN_DIR" ] || erro "HOME não definido; use --prefixo e --bin"
# Manutenção usa a pasta do comando registrada na instalação, salvo indicação em contrário.
if [ "$ACAO" != instalar ] && [ "$BIN_EXPLICITO" -ne 1 ] && [ -z "${ABT_BIN_DIR:-}" ] && [ -f "$PREFIXO/.abt-install.json" ]; then
    bin_gravado=$(sed -n 's/.*"bin": *"\([^"]*\)".*/\1/p' "$PREFIXO/.abt-install.json" | head -n 1)
    [ -z "$bin_gravado" ] || BIN_DIR=$bin_gravado
fi
case "$PREFIXO$BIN_DIR" in *\"*|*\\*) erro "os caminhos não podem conter aspas nem barra invertida" ;; esac
case "$PREFIXO" in /*) ;; *) erro "--prefixo deve ser um caminho absoluto" ;; esac
case "$BIN_DIR" in /*) ;; *) erro "--bin deve ser um caminho absoluto" ;; esac
LINK=$BIN_DIR/abt
MARCADOR=$PREFIXO/.abt-install.json

precisa() {
    command -v "$1" >/dev/null 2>&1 || erro "comando necessário não encontrado: $1 ($2)"
}

# Só baixa por HTTPS; http:// e file:// são aceitos apenas para servidores locais de teste.
baixar() {
    seguro=0
    case "$1" in
        https://*) seguro=1 ;;
        http://127.0.0.1:*|http://127.0.0.1/*|http://localhost:*|http://localhost/*) ;;
        *) erro "endereço recusado (use https://): $1" ;;
    esac
    if command -v curl >/dev/null 2>&1; then
        if [ "$seguro" -eq 1 ]; then
            curl -fL --retry 3 --progress-bar --proto '=https' --proto-redir '=https' --tlsv1.2 -o "$2" "$1" || erro "falha ao baixar $1"
        else
            curl -fL --retry 3 --progress-bar -o "$2" "$1" || erro "falha ao baixar $1"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [ "$seguro" -eq 1 ]; then
            wget -q --show-progress --https-only -O "$2" "$1" || erro "falha ao baixar $1"
        else
            wget -q --show-progress -O "$2" "$1" || erro "falha ao baixar $1"
        fi
    else
        erro "é preciso ter curl ou wget para baixar o pacote (ou use --arquivo)"
    fi
}

soma_sha256() { sha256sum "$1" | cut -d' ' -f1; }

versao_instalada() {
    [ -f "$MARCADOR" ] && sed -n 's/.*"versao": *"\([^"]*\)".*/\1/p' "$MARCADOR" | head -n 1
}

# O link só é "nosso" se apontar para o bin/abt desta instalação.
link_e_nosso() {
    [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$PREFIXO/bin/abt" ]
}

# Link que sobrou de uma instalação movida ou removida: aponta para um bin/abt que não existe mais.
link_orfao() {
    [ -L "$LINK" ] && [ ! -e "$LINK" ] && case "$(readlink "$LINK")" in */bin/abt) return 0 ;; esac
    return 1
}

verificar_prefixo_existente() {
    [ -e "$PREFIXO" ] || [ -L "$PREFIXO" ] || return 0
    [ -d "$PREFIXO" ] && [ ! -L "$PREFIXO" ] || erro "$PREFIXO existe e não é uma pasta da ABT"
    if [ ! -f "$MARCADOR" ]; then
        erro "$PREFIXO existe mas não tem marcador de instalação integrada. Se for a instalação por 'tools/install.py', remova-a antes com 'python3 tools/uninstall.py'. Nada foi alterado."
    fi
    if grep -q '"schema": *1' "$MARCADOR"; then
        erro "$PREFIXO é uma instalação antiga (tools/install.py). Remova-a com 'python3 tools/uninstall.py' e rode este instalador de novo. Nada foi alterado."
    fi
}

pre_compilar() {
    info "pré-compilando pacotes para este computador. Isto leva alguns minutos e só acontece uma vez."
    JULIA_DEPOT_PATH="$PREFIXO/depot" JULIA_PKG_OFFLINE=true \
        "$PREFIXO/runtime/julia/bin/julia" --startup-file=no --project="$PREFIXO" \
        -e 'import Pkg; Pkg.precompile(); using ABT' \
        || return 1
    printf '%s\n' "$PREFIXO" >"$PREFIXO/.abt-prefixo"
}

teste_rapido() {
    pasta=$(mktemp -d "${TMPDIR:-/tmp}/abt-teste.XXXXXX")
    printf 'mostrar 1\n' >"$pasta/teste.abt"
    resposta=$("$PREFIXO/bin/abt" run "$pasta/teste.abt" 2>&1) || { rm -rf "$pasta"; aviso "teste de execução falhou: $resposta"; return 1; }
    rm -rf "$pasta"
    [ "$resposta" = 1 ] || { aviso "teste de execução devolveu '$resposta' em vez de 1"; return 1; }
}

dica_path() {
    case ":${PATH:-}:" in
        *":$BIN_DIR:"*) ;;
        *) info "adicione $BIN_DIR ao PATH (por exemplo: export PATH=\"$BIN_DIR:\$PATH\") para usar o comando abt." ;;
    esac
}

# ---------------------------------------------------------------- reparar
acao_reparar() {
    [ -f "$MARCADOR" ] || erro "nenhuma instalação integrada em $PREFIXO"
    pre_compilar || erro "a pré-compilação falhou"
    teste_rapido || erro "a instalação não passou no teste de execução"
    if link_orfao; then ln -sfn "$PREFIXO/bin/abt" "$LINK"; info "comando $LINK reapontado para $PREFIXO."; fi
    info "instalação reparada em $PREFIXO."
}

# ---------------------------------------------------------------- desinstalar
acao_desinstalar() {
    [ -e "$PREFIXO" ] || { info "nada instalado em $PREFIXO."; return 0; }
    [ -f "$MARCADOR" ] || erro "$PREFIXO não tem marcador de instalação integrada; nada foi removido"
    if [ "$CONFIRMADO" -ne 1 ]; then
        printf 'Remover a ABT de %s? [s/N] ' "$PREFIXO" >&2
        resposta=
        if [ -r /dev/tty ]; then read -r resposta </dev/tty || resposta=; fi
        case "$resposta" in s|S|sim|SIM) ;; *) info "cancelado."; return 0 ;; esac
    fi
    if link_e_nosso || link_orfao; then rm -f "$LINK"; fi
    rm -rf "$PREFIXO"
    info "ABT removida. O seu ~/.julia (se existir) não foi tocado."
}

# ---------------------------------------------------------------- instalar / atualizar
acao_instalar() {
    [ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] \
        || erro "este instalador cobre apenas Linux x86_64 por enquanto (sistema atual: $(uname -s) $(uname -m))"
    precisa tar "pacote tar.xz"
    precisa xz "descompactação xz (pacote xz-utils)"
    precisa sha256sum "verificação do pacote"
    precisa mktemp "pasta temporária"
    verificar_prefixo_existente
    if [ ! -e "$PREFIXO" ] && { [ -e "$LINK" ] || [ -L "$LINK" ]; }; then
        erro "o comando $LINK já existe e não pertence a esta instalação; nada foi alterado"
    fi
    if [ -e "$PREFIXO" ] && [ -e "$LINK" ] && ! link_e_nosso; then
        erro "o comando $LINK aponta para outro lugar; nada foi alterado"
    fi

    mkdir -p "$(dirname "$PREFIXO")"
    TRABALHO=$(mktemp -d "$PREFIXO.tmp.XXXXXX") || erro "não foi possível criar pasta temporária ao lado de $PREFIXO"
    BACKUP=
    TROCADO=0
    CONCLUIDO=0
    limpar() {
        if [ "$CONCLUIDO" -ne 1 ]; then
            if [ "$TROCADO" -eq 1 ]; then
                rm -rf "$PREFIXO"
                [ -n "$BACKUP" ] && mv "$BACKUP" "$PREFIXO"
                [ -n "$BACKUP" ] && info "instalação anterior restaurada."
            fi
        fi
        rm -rf "$TRABALHO"
    }
    trap limpar EXIT
    trap 'exit 130' INT TERM

    if [ -n "$ARQUIVO" ]; then
        [ -f "$ARQUIVO" ] || erro "arquivo não encontrado: $ARQUIVO"
        PACOTE=$ARQUIVO
        if [ -z "$SHA256_ESPERADO" ] && [ -f "$ARQUIVO.sha256" ]; then
            SHA256_ESPERADO=$(cut -d' ' -f1 <"$ARQUIVO.sha256")
        fi
        if [ -z "$SHA256_ESPERADO" ] && [ "$SEM_VERIFICACAO" -ne 1 ]; then
            erro "sem soma SHA-256 para conferir $ARQUIVO; coloque o arquivo .sha256 ao lado dele, use --sha256, ou --sem-verificacao se aceita o risco."
        fi
        [ -n "$SHA256_ESPERADO" ] || aviso "instalando SEM verificação de integridade (--sem-verificacao)."
        NOVA_VERSAO=${VERSAO}
        [ "$NOVA_VERSAO" != latest ] || NOVA_VERSAO=local
    else
        if [ "$VERSAO" = latest ]; then
            info "procurando a versão mais recente"
            baixar "$BASE_URL/latest/download/VERSION" "$TRABALHO/VERSION"
            VERSAO=$(tr -d ' \r\n' <"$TRABALHO/VERSION")
            case "$VERSAO" in [0-9]*.[0-9]*.[0-9]*) ;; *) erro "versão inválida recebida do servidor" ;; esac
        fi
        NOVA_VERSAO=$VERSAO
        instalada=$(versao_instalada || true)
        if [ "$ACAO" = atualizar ] && [ "$instalada" = "$NOVA_VERSAO" ] && [ "$FORCAR" -ne 1 ]; then
            info "a ABT $instalada já é a versão mais recente."
            CONCLUIDO=1
            return 0
        fi
        NOME=abt-$NOVA_VERSAO-$PLATAFORMA.tar.xz
        PACOTE=$TRABALHO/$NOME
        info "baixando a ABT $NOVA_VERSAO (cerca de 250 MB)"
        baixar "$BASE_URL/download/v$NOVA_VERSAO/$NOME" "$PACOTE"
        baixar "$BASE_URL/download/v$NOVA_VERSAO/$NOME.sha256" "$TRABALHO/$NOME.sha256"
        SHA256_ESPERADO=$(cut -d' ' -f1 <"$TRABALHO/$NOME.sha256")
    fi

    if [ -n "$SHA256_ESPERADO" ]; then
        real=$(soma_sha256 "$PACOTE")
        [ "$real" = "$SHA256_ESPERADO" ] || erro "soma SHA-256 diferente da esperada (esperada $SHA256_ESPERADO, obtida $real); nada foi instalado"
        info "integridade do pacote verificada (SHA-256)."
    fi
    # A soma vem da mesma origem do pacote; a atestação prova que ele foi construído pelo workflow do repositório.
    if [ "$VERIFICAR_ATESTACAO" = 1 ]; then
        [ -z "$ARQUIVO" ] || erro "--verificar-atestacao só vale para pacotes baixados"
        command -v gh >/dev/null 2>&1 || erro "--verificar-atestacao exige o GitHub CLI (gh)"
        gh attestation verify "$PACOTE" --repo "$REPO" >/dev/null 2>&1 \
            || erro "a atestação de procedência do pacote não foi confirmada; nada foi instalado"
        info "procedência do pacote confirmada (atestação do GitHub)."
    fi

    info "extraindo"
    mkdir "$TRABALHO/novo"
    tar -xJf "$PACOTE" -C "$TRABALHO/novo" --strip-components=1 || erro "falha ao extrair o pacote"
    for arq in bin/abt src/CLI.jl Project.toml Manifest.toml runtime/julia/bin/julia; do
        [ -e "$TRABALHO/novo/$arq" ] || erro "pacote inválido: falta $arq"
    done
    [ "$("$TRABALHO/novo/runtime/julia/bin/julia" --version 2>&1)" = "$JULIA_VERSAO" ] \
        || erro "o pacote não traz a Julia esperada ($JULIA_VERSAO)"
    # A versão instalada é a declarada no próprio pacote (não confia no nome do arquivo).
    versao_pacote=$(sed -n 's/^version *= *"\(.*\)"/\1/p' "$TRABALHO/novo/Project.toml" | head -n 1)
    [ -n "$versao_pacote" ] || erro "pacote inválido: versão ausente em Project.toml"
    NOVA_VERSAO=$versao_pacote

    if [ -e "$PREFIXO" ]; then
        BACKUP=$PREFIXO.antiga.$$
        mv "$PREFIXO" "$BACKUP"
    fi
    mv "$TRABALHO/novo" "$PREFIXO"
    TROCADO=1
    printf '{"application": "ABT", "schema": 2, "versao": "%s", "plataforma": "%s", "prefixo": "%s", "bin": "%s"}\n' \
        "$NOVA_VERSAO" "$PLATAFORMA" "$PREFIXO" "$BIN_DIR" >"$MARCADOR"

    pre_compilar || erro "a pré-compilação falhou"
    mkdir -p "$BIN_DIR"
    ln -sfn "$PREFIXO/bin/abt" "$LINK"
    teste_rapido || { rm -f "$LINK"; erro "a instalação não passou no teste de execução"; }

    CONCLUIDO=1
    [ -z "$BACKUP" ] || rm -rf "$BACKUP"
    info "ABT $NOVA_VERSAO instalada em $PREFIXO."
    info "comando: $LINK"
    dica_path
    info "para começar: abt doctor"
}

case "$ACAO" in
    instalar|atualizar) acao_instalar ;;
    reparar) acao_reparar ;;
    desinstalar) acao_desinstalar ;;
esac
