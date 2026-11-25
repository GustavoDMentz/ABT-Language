"""Localização e execução de processos da IDE (abt e Julia), igual em Linux, macOS e Windows."""
import os
import shutil
import subprocess
from pathlib import Path

WINDOWS = os.name == "nt"


def achar_abt():
    """Localiza o comando abt: ABT_BIN, o PATH ou a pasta padrão da instalação (Linux/macOS e Windows)."""
    candidatos = [os.environ.get("ABT_BIN"), shutil.which("abt")]
    if WINDOWS:
        local = os.environ.get("LOCALAPPDATA")
        candidatos.append(str(Path(local) / "ABT" / "bin" / "abt.cmd") if local else None)
    else:
        candidatos.append(str(Path.home() / ".local/bin/abt"))
    for candidato in candidatos:
        if candidato and Path(candidato).exists():
            return candidato
    return None


def iniciar(abt, argumentos, pasta):
    """Inicia o abt. No Windows o lançador é um .cmd: o comando vai como texto único, com aspas
    no caminho (pode ter espaços), e o processo ganha um grupo próprio para poder ser encerrado."""
    opcoes = dict(cwd=pasta, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
    if WINDOWS:
        if abt.lower().endswith((".cmd", ".bat")):
            if '"' in abt or "%" in abt:
                raise OSError("o caminho do abt não pode conter aspas nem %")
            return subprocess.Popen(f'cmd /d /s /c ""{abt}" {" ".join(argumentos)}"',
                                    creationflags=subprocess.CREATE_NEW_PROCESS_GROUP, **opcoes)
        return subprocess.Popen([abt, *argumentos], creationflags=subprocess.CREATE_NEW_PROCESS_GROUP, **opcoes)
    return subprocess.Popen([abt, *argumentos], start_new_session=True, **opcoes)


def encerrar(proc):
    """Encerra o abt e os processos filhos (a Julia roda como filha do lançador)."""
    try:
        if WINDOWS:
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
        else:
            import signal
            os.killpg(proc.pid, signal.SIGKILL)
    except OSError:
        proc.kill()


def raiz_da_abt(abt=None):
    """Pasta da instalação da ABT (a que contém src/ABT.jl e Project.toml). ABT_RAIZ tem prioridade."""
    abt = abt or achar_abt()
    candidatos = [os.environ.get("ABT_RAIZ")]
    if abt:
        real = Path(os.path.realpath(abt))
        candidatos.append(str(real.parent.parent))       # RAIZ/bin/abt  ou  RAIZ\bin\abt.cmd
    for c in candidatos:
        if c and (Path(c) / "src" / "ABT.jl").is_file() and (Path(c) / "Project.toml").is_file():
            return Path(c)
    return None


def localizar_julia(raiz):
    """(comando, ambiente) para rodar a Julia da ABT, como o lançador `abt` faz: runtime embutido da instalação
    (com o depot dela, offline) ou, na falta dele, ABT_JULIA / `julia` do PATH. Devolve (None, None) se não achar."""
    exe = "julia.exe" if WINDOWS else "julia"
    embutido = raiz / "runtime" / "julia" / "bin" / exe
    env = dict(os.environ)
    if not os.environ.get("ABT_JULIA") and embutido.is_file():
        env["JULIA_DEPOT_PATH"] = str(raiz / "depot")
        env["JULIA_PKG_OFFLINE"] = "true"
        return str(embutido), env
    externo = os.environ.get("ABT_JULIA") or shutil.which("julia")
    return (externo, env) if externo else (None, None)


def iniciar_exe(exe, argumentos, pasta, env=None):
    """Inicia um executável (ex.: julia) sem shell, em grupo próprio para poder ser encerrado por inteiro."""
    opcoes = dict(cwd=pasta, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
    if WINDOWS:
        return subprocess.Popen([exe, *argumentos], creationflags=subprocess.CREATE_NEW_PROCESS_GROUP, **opcoes)
    return subprocess.Popen([exe, *argumentos], start_new_session=True, **opcoes)


def esperar(proc, tempo):
    """(stdout, stderr, código, estourou_o_tempo): ao estourar, encerra o processo e todos os filhos."""
    try:
        saida, erro = proc.communicate(timeout=tempo)
        return saida, erro, proc.returncode, False
    except subprocess.TimeoutExpired:
        encerrar(proc)
        saida, erro = proc.communicate()
        return saida, erro, 124, True
