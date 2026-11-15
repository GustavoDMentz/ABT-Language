#!/bin/sh
# Constrói o pacote do instalador integrado: Julia 1.13.3 + ABT + pacotes (sem caches pré-compilados).
#
#   tools/construir_bundle.sh [--saida DIR] [--julia-dir DIR]
#
# Gera DIR/abt-<versão>-linux-x86_64.tar.xz e o arquivo .sha256 correspondente.
# Os caches pré-compilados NÃO entram no pacote: só valem no caminho onde foram gerados,
# então o instalador pré-compila no destino (docs/RELATORIO_INSTALADOR_INTEGRADO.md).
set -eu

JULIA_URL=https://julialang-s3.julialang.org/bin/linux/x64/1.13/julia-1.13.3-linux-x86_64.tar.gz
JULIA_SHA256=5c61cb4b40332cb5a3504e7779e2f5dac093caa4a1116ded19f01413f85c63e4
PLATAFORMA=linux-x86_64

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
SAIDA=$RAIZ/dist
JULIA_DIR=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --saida) SAIDA=$2; shift ;;
        --julia-dir) JULIA_DIR=$2; shift ;;
        -h|--ajuda) sed -n '2,8p' "$0"; exit 0 ;;
        *) printf 'opção desconhecida: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

erro() { printf 'construir_bundle: %s\n' "$*" >&2; exit 1; }
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || erro "só Linux x86_64"
for cmd in git tar xz sha256sum; do command -v "$cmd" >/dev/null 2>&1 || erro "comando necessário: $cmd"; done

VERSAO=$(sed -n 's/^version *= *"\(.*\)"/\1/p' "$RAIZ/Project.toml" | head -n 1)
[ -n "$VERSAO" ] || erro "versão não encontrada em Project.toml"
mkdir -p "$SAIDA"
SAIDA=$(cd "$SAIDA" && pwd)
TRABALHO=$(mktemp -d "${TMPDIR:-/tmp}/abt-bundle.XXXXXX")
trap 'rm -rf "$TRABALHO"' EXIT
BUNDLE=$TRABALHO/abt
mkdir -p "$BUNDLE/runtime"

printf '==> Julia\n'
if [ -n "$JULIA_DIR" ]; then
    [ -x "$JULIA_DIR/bin/julia" ] || erro "--julia-dir sem bin/julia"
    cp -a "$JULIA_DIR" "$BUNDLE/runtime/julia"
else
    command -v curl >/dev/null 2>&1 || erro "curl é necessário para baixar a Julia"
    curl -fL --retry 3 -o "$TRABALHO/julia.tar.gz" "$JULIA_URL"
    [ "$(sha256sum "$TRABALHO/julia.tar.gz" | cut -d' ' -f1)" = "$JULIA_SHA256" ] || erro "SHA-256 da Julia diferente do fixado"
    mkdir "$BUNDLE/runtime/julia"
    tar -xzf "$TRABALHO/julia.tar.gz" -C "$BUNDLE/runtime/julia" --strip-components=1
    rm -f "$TRABALHO/julia.tar.gz"
fi
[ "$("$BUNDLE/runtime/julia/bin/julia" --version)" = 'julia version 1.13.3' ] || erro "Julia diferente da homologada (1.13.3)"

printf '==> Código da ABT\n'
tar -C "$RAIZ" -cf - bin src Project.toml Manifest.toml ABT.packages.toml | tar -x -C "$BUNDLE"
mkdir -p "$BUNDLE/libexec"
cp "$RAIZ/tools/instalar.sh" "$BUNDLE/libexec/instalar.sh"
chmod +x "$BUNDLE/bin/abt" "$BUNDLE/libexec/instalar.sh"

printf '==> Pacotes Julia (sem pré-compilar)\n'
JULIA_DEPOT_PATH="$BUNDLE/depot" JULIA_PKG_PRECOMPILE_AUTO=0 \
    "$BUNDLE/runtime/julia/bin/julia" --startup-file=no --project="$BUNDLE" -e 'import Pkg; Pkg.instantiate()'
rm -rf "$BUNDLE/depot/compiled" "$BUNDLE/depot/registries" "$BUNDLE/depot/logs" "$BUNDLE/depot/scratchspaces"
[ -d "$BUNDLE/depot/packages" ] && [ -d "$BUNDLE/depot/artifacts" ] || erro "depot incompleto"

printf '==> Avisos de terceiros\n'
{
    printf '# Componentes de terceiros incluídos neste pacote\n\n'
    printf 'A ABT é distribuída junto com os componentes abaixo, cada um sob a sua própria licença.\n\n'
    printf -- '- **Julia 1.13.3**: `runtime/julia/LICENSE.md` (MIT, mais as licenças das bibliotecas que ela inclui).\n'
    printf -- '- **Pacotes Julia** (versões fixadas em `Manifest.toml`): o texto de cada licença está no arquivo `LICENSE*` dentro de `depot/packages/<Pacote>/<hash>/`.\n'
    printf -- '- **Bibliotecas binárias** (artefatos JLL, como o Cairo): licenças em `depot/artifacts/<hash>/share/licenses/`.\n\n'
    printf '## Pacotes Julia\n\n| Pacote | Versão |\n|---|---|\n'
    awk '/^\[\[deps\./ {gsub(/^\[\[deps\.|\]\]$/, ""); n = $0}
         /^version = / {gsub(/version = |"/, ""); if (n != "") { printf "| %s | %s |\n", n, $0; n = "" }}' "$BUNDLE/Manifest.toml"
} >"$BUNDLE/THIRD_PARTY_NOTICES.md"

printf '==> Empacotando\n'
NOME=abt-$VERSAO-$PLATAFORMA.tar.xz
EPOCA=$(cd "$RAIZ" && git log -1 --format=%ct HEAD)
tar -C "$TRABALHO" --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$EPOCA" -cf - abt \
    | xz -T0 -6 >"$SAIDA/$NOME"
(cd "$SAIDA" && sha256sum "$NOME" >"$NOME.sha256")
printf '%s\n' "$VERSAO" >"$SAIDA/VERSION"
printf '==> Pronto: %s (%s)\n' "$SAIDA/$NOME" "$(du -h "$SAIDA/$NOME" | cut -f1)"
