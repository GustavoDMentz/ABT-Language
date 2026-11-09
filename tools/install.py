#!/usr/bin/env python3
"""Install or remove the per-user ABT CLI; Python is only needed for setup."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parent.parent
HOME = Path.home()
TARGET = HOME / ".local/share/abt"
LINK = HOME / ".local/bin/abt"
MARKER = ".abt-install.json"
LEGACY_FILES = (
    "bin/abt", "src/CLI.jl", "src/ABT.jl", "src/Runtime/Bridge.jl",
    "ABT.packages.toml", "Project.toml", "README.md",
)
FILES = LEGACY_FILES + (
    "Manifest.toml", "src/StdlibRender.jl", "src/Stdlib.jl", "src/StdlibBio.jl",
    "src/StdlibAnalytics.jl", "src/StdlibJSON.jl", "src/StdlibStats.jl",
    "src/StdlibLinear.jl", "src/StdlibBatch.jl", "src/ExtensionRegistry.jl",
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message):
    raise ValueError(message)


def existing():
    if not TARGET.exists() or TARGET.is_symlink() or not TARGET.is_dir():
        fail("diretório de instalação ausente, inválido ou não pertencente ao ABT")
    marker_path = TARGET / MARKER
    if not marker_path.is_file() or marker_path.is_symlink():
        fail("instalação existente sem marcador ABT; nenhum arquivo foi alterado")
    try:
        marker = json.loads(marker_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        fail(f"marcador de instalação inválido: {exc}")
    saved_files = set(marker.get("files", {}))
    if marker.get("application") != "ABT" or marker.get("schema") != 1 or saved_files not in (set(FILES), set(LEGACY_FILES)):
        fail("marcador de instalação incompatível")
    allowed = saved_files | {MARKER, "bin", "src", "src/Runtime"}
    found = {str(p.relative_to(TARGET)) for p in TARGET.rglob("*")}
    if found != allowed:
        fail("instalação contém arquivos extras ou ausentes; preserve-os manualmente antes de atualizar/remover")
    for relative in ("bin", "src", "src/Runtime"):
        path = TARGET / relative
        if path.is_symlink() or not path.is_dir():
            fail(f"diretório instalado inválido: {relative}")
    for relative in saved_files:
        path = TARGET / relative
        if path.is_symlink() or not path.is_file() or digest(path) != marker["files"][relative]:
            fail(f"arquivo instalado modificado: {relative}; nenhum arquivo foi alterado")
    if not LINK.is_symlink() or os.readlink(LINK) != str(TARGET / "bin/abt"):
        fail(f"link do comando ausente ou diferente: {LINK}; nenhum arquivo foi alterado")


def stage():
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".abt-stage-", dir=TARGET.parent))
    try:
        hashes = {}
        for relative in FILES:
            origin = SOURCE / relative
            if not origin.is_file() or origin.is_symlink():
                fail(f"arquivo de origem ausente ou inválido: {relative}")
            destination = staging / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(origin, destination)
            hashes[relative] = digest(destination)
        (staging / MARKER).write_text(json.dumps({"application": "ABT", "schema": 1, "files": hashes}, indent=2) + "\n", encoding="utf-8")
        return staging
    except BaseException:
        shutil.rmtree(staging)
        raise


def julia_runtime():
    runtime = os.environ.get("ABT_JULIA") or shutil.which("julia")
    if not runtime:
        fail("Julia não encontrada; instale Julia 1.13.3 ou defina ABT_JULIA")
    try:
        result = subprocess.run([runtime, "--version"], capture_output=True,
                                text=True, timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        fail(f"não foi possível iniciar Julia: {exc}")
    if result.returncode != 0 or result.stdout.strip() != "julia version 1.13.3":
        fail(f"Julia 1.13.3 necessária; encontrado: {result.stdout.strip() or result.stderr.strip()}")
    return runtime


def warm_cache(runtime):
    try:
        result = subprocess.run([runtime, "--startup-file=no", "--compile=min",
                                 f"--project={TARGET}", "-e", "import Pkg; Pkg.instantiate(); using ABT"],
                                capture_output=True, text=True, timeout=300, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        fail(f"pré-compilação ABT não concluiu: {exc}")
    if result.returncode:
        fail(f"pré-compilação ABT falhou: {result.stderr.strip()}")


def install():
    present = TARGET.exists() or TARGET.is_symlink()
    if present:
        existing()
    elif LINK.exists() or LINK.is_symlink():
        fail(f"comando já ocupado por outra instalação: {LINK}")
    runtime = julia_runtime()
    staging = stage()
    backup = None
    link_created = False
    try:
        if present:
            backup = Path(tempfile.mkdtemp(prefix=".abt-backup-", dir=TARGET.parent))
            backup.rmdir()
            TARGET.rename(backup)
        staging.rename(TARGET)
        if not present:
            LINK.parent.mkdir(parents=True, exist_ok=True)
            LINK.symlink_to(TARGET / "bin/abt")
            link_created = True
        warm_cache(runtime)
    except BaseException:
        if link_created:
            LINK.unlink()
        if TARGET.exists() and not present:
            shutil.rmtree(TARGET)
        if backup is not None and backup.exists():
            if TARGET.exists():
                shutil.rmtree(TARGET)
            backup.rename(TARGET)
        raise
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    if backup is not None:
        shutil.rmtree(backup)
    print(f"ABT instalado em {TARGET}")
    if str(LINK.parent) not in os.environ.get("PATH", "").split(os.pathsep):
        print(f"Adicione {LINK.parent} ao PATH para usar 'abt' de qualquer diretório.")


def uninstall():
    if not TARGET.exists() and not TARGET.is_symlink() and not LINK.exists() and not LINK.is_symlink():
        print("ABT já está desinstalado.")
        return
    existing()
    LINK.unlink()
    shutil.rmtree(TARGET)
    print("ABT desinstalado.")


if __name__ == "__main__":
    try:
        if len(sys.argv) == 1:
            install()
        elif sys.argv == [sys.argv[0], "--uninstall"]:
            uninstall()
        else:
            fail("uso: python3 tools/install.py [--uninstall]")
    except (OSError, ValueError) as exc:
        print(f"ABT: {exc}", file=sys.stderr)
        sys.exit(2)
