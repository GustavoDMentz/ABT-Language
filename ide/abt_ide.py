#!/usr/bin/env python3
"""IDE mínima para a linguagem ABT.

    python3 ide/abt_ide.py            abre http://127.0.0.1:8765 no navegador
    python3 ide/abt_ide.py --porta 9000 --sem-navegador
    Windows: dê dois cliques em ide/abrir_ide.bat (ou py -3 ide\\abt_ide.py)

Funciona em Linux, macOS e Windows (Python 3.8 ou superior). Só usa a biblioteca padrão do Python. Precisa do comando `abt` instalado (ou ABT_BIN apontando
para ele). O servidor escuta apenas em 127.0.0.1 e exige um token gerado a cada execução,
porque executar um programa ABT roda código na sua máquina.
"""
import argparse
import json
import os
import secrets
import shutil
import subprocess
import tempfile
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TEMPO_MAX = 60          # segundos por execução (a 1ª execução carrega os pacotes e demora mais)
TAMANHO_MAX = 1 << 20   # 1 MiB de código
TOKEN = secrets.token_urlsafe(24)
PADRAO = '# Programa de exemplo\nnotas = [7.5, 4.0, 9.0, 6.5]\ntotal = 0.0\npara cada nota em notas {\n    total = total + nota\n}\nmostrar total / 4\n'


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


PASTA_EXEMPLOS = Path(__file__).resolve().parent / "exemplos"


def exemplos():
    """Exemplos de ide/exemplos/*.abt, na ordem dos nomes. O título é o comentário da 1ª linha."""
    achados = {}
    if PASTA_EXEMPLOS.is_dir():
        for arq in sorted(PASTA_EXEMPLOS.glob("*.abt")):
            try:
                codigo = arq.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            primeira = codigo.split("\n", 1)[0]
            titulo = primeira.lstrip("# ").strip() if primeira.startswith("#") else arq.stem
            achados[f"{len(achados) + 1}. {titulo}"] = codigo
    return achados


def executar(codigo, modo):
    abt = achar_abt()
    if abt is None:
        return {"codigo_saida": 127, "saida": "", "erro": "Comando 'abt' não encontrado. Instale a ABT ou defina ABT_BIN.", "ms": 0}
    comando = "check" if modo == "check" else "run"
    pasta = tempfile.mkdtemp(prefix="abt-ide-")
    try:
        with open(Path(pasta) / "programa.abt", "w", encoding="utf-8", newline="\n") as f:
            f.write(codigo)
        dados = PASTA_EXEMPLOS / "dados"   # CSV/FASTA/FASTQ usados pelos exemplos: "dados/arquivo"
        if dados.is_dir():
            shutil.copytree(dados, Path(pasta) / "dados")
        inicio = time.monotonic()
        try:
            # caminho relativo: a pasta temporária vira o diretório atual, e o nome não tem espaços
            proc = iniciar(abt, [comando, "programa.abt"], pasta)
        except OSError as e:
            return {"codigo_saida": 127, "saida": "", "erro": f"Não foi possível iniciar o abt: {e}", "ms": 0}
        try:
            saida, erro = proc.communicate(timeout=TEMPO_MAX)
            cod = proc.returncode
        except subprocess.TimeoutExpired:
            encerrar(proc)
            saida, erro = proc.communicate()
            erro += f"\nTempo esgotado ({TEMPO_MAX} s); execução interrompida.".encode()
            cod = 124
        ms = int((time.monotonic() - inicio) * 1000)
    finally:
        shutil.rmtree(pasta, ignore_errors=True)
    dec = lambda b: b.decode("utf-8", errors="replace")
    return {"codigo_saida": cod, "saida": dec(saida), "erro": dec(erro), "ms": ms}


class Manipulador(BaseHTTPRequestHandler):
    server_version = "ABT-IDE"

    def log_message(self, *args):
        pass

    def host_valido(self):
        return self.headers.get("Host", "") in {f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"}

    def responder(self, status, corpo, tipo):
        dados = corpo if isinstance(corpo, bytes) else corpo.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(dados)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(dados)

    def do_GET(self):
        if not self.host_valido():
            return self.responder(403, "Host não permitido", "text/plain; charset=utf-8")
        if self.path in ("/", "/index.html"):
            abt = achar_abt()
            versao = ""
            if abt:
                try:
                    proc = iniciar(abt, ["--version"], str(Path.home()))
                    try:
                        versao = proc.communicate(timeout=30)[0].decode("utf-8", errors="replace").strip()
                    except subprocess.TimeoutExpired:
                        encerrar(proc)
                except OSError:
                    pass
            config = json.dumps({"token": TOKEN, "versao": versao, "exemplos": exemplos(), "padrao": PADRAO}).replace("</", "<\\/")
            return self.responder(200, PAGINA.replace("__CONFIG__", config), "text/html; charset=utf-8")
        self.responder(404, "Não encontrado", "text/plain; charset=utf-8")

    def do_POST(self):
        if not self.host_valido() or self.headers.get("X-IDE-Token") != TOKEN:
            return self.responder(403, "Não autorizado", "text/plain; charset=utf-8")
        if self.path != "/api/executar":
            return self.responder(404, "Não encontrado", "text/plain; charset=utf-8")
        try:
            tamanho = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            tamanho = -1
        if not 0 <= tamanho <= TAMANHO_MAX:
            return self.responder(413, "Corpo inválido ou grande demais", "text/plain; charset=utf-8")
        try:
            dados = json.loads(self.rfile.read(tamanho))
            codigo, modo = str(dados["codigo"]), str(dados.get("modo", "run"))
        except (ValueError, KeyError):
            return self.responder(400, "Requisição inválida", "text/plain; charset=utf-8")
        self.responder(200, json.dumps(executar(codigo, modo)), "application/json; charset=utf-8")


def main():
    p = argparse.ArgumentParser(description="IDE mínima para a linguagem ABT")
    p.add_argument("--porta", type=int, default=8765)
    p.add_argument("--sem-navegador", action="store_true")
    a = p.parse_args()
    servidor = ThreadingHTTPServer(("127.0.0.1", a.porta), Manipulador)
    url = f"http://127.0.0.1:{servidor.server_port}/"
    print(f"ABT IDE em {url}  (Ctrl+C para sair)")
    if achar_abt() is None:
        print("Aviso: comando 'abt' não encontrado; a execução vai falhar até a ABT ser instalada.")
    if not a.sem_navegador:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\nEncerrado.")


PAGINA = r"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ABT IDE</title>
<style>
:root{--bg:#fafaf8;--painel:#fff;--borda:#d9d7d0;--txt:#1f2328;--suave:#6b7075;--acento:#0b6b57;--erro:#b42318;--ok:#0b6b57;
--kw:#7a3e9d;--num:#b35900;--str:#1a7f37;--com:#8a8f94;--op:#0b5cad;--linha:#f0efe9}
@media (prefers-color-scheme:dark){:root{--bg:#16181a;--painel:#1e2124;--borda:#383c40;--txt:#e6e6e3;--suave:#9aa0a6;--acento:#3fb99b;--erro:#ff8a80;--ok:#3fb99b;
--kw:#c792ea;--num:#f2a65a;--str:#7fd18b;--com:#7d848b;--op:#6cb6ff;--linha:#26292c}}
*{box-sizing:border-box}
html,body{height:100%;margin:0}
body{background:var(--bg);color:var(--txt);font:14px/1.4 system-ui,sans-serif;display:flex;flex-direction:column}
header{display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:8px 16px;border-bottom:1px solid var(--borda);background:var(--painel)}
header h1{font-size:15px;margin:0 8px 0 0}
header .ver{color:var(--suave);font-size:12px;margin-left:auto}
button,select{font:inherit;color:var(--txt);background:var(--painel);border:1px solid var(--borda);border-radius:6px;padding:5px 10px;cursor:pointer}
button:hover,select:hover{border-color:var(--acento)}
button.principal{background:var(--acento);border-color:var(--acento);color:#fff}
button:disabled{opacity:.5;cursor:wait}
main{flex:1;display:flex;flex-direction:column;min-height:0}
.editor{flex:3;display:flex;min-height:120px;background:var(--painel);overflow:hidden}
.nums{padding:12px 8px 12px 12px;text-align:right;color:var(--suave);user-select:none;overflow:hidden;border-right:1px solid var(--borda);background:var(--linha);white-space:pre}
.nums .err{color:var(--erro);font-weight:700}
.codigo{position:relative;flex:1;min-width:0}
.codigo pre,.codigo textarea,.nums{font:13.5px/1.55 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;tab-size:4}
.codigo pre,.codigo textarea{position:absolute;inset:0;margin:0;padding:12px;border:0;white-space:pre;overflow:auto}
.codigo pre{pointer-events:none;color:var(--txt)}
.codigo textarea{background:transparent;color:transparent;caret-color:var(--txt);resize:none;outline:none}
.codigo textarea::selection{background:rgba(11,107,87,.28)}
.k{color:var(--kw);font-weight:600}.n{color:var(--num)}.s{color:var(--str)}.c{color:var(--com);font-style:italic}.o{color:var(--op)}
.saida{flex:2;display:flex;flex-direction:column;min-height:90px;border-top:1px solid var(--borda)}
.saida .barra{display:flex;gap:12px;align-items:center;padding:6px 16px;background:var(--painel);border-bottom:1px solid var(--borda);font-size:12px;color:var(--suave)}
.saida .barra b{color:var(--txt)}
.saida .barra .estado.ok{color:var(--ok)}.saida .barra .estado.falha{color:var(--erro)}
.saida .barra button{margin-left:auto;padding:2px 8px;font-size:12px}
#saida{flex:1;margin:0;padding:12px 16px;overflow:auto;white-space:pre-wrap;font:13px/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;background:var(--bg)}
#saida .e{color:var(--erro)}#saida a{color:var(--erro);text-decoration:underline;cursor:pointer}
footer{padding:4px 16px;font-size:12px;color:var(--suave);border-top:1px solid var(--borda);background:var(--painel);display:flex;gap:16px}
@media (max-width:640px){header .ver{display:none}}
</style>
</head>
<body>
<header>
  <h1>ABT IDE</h1>
  <button id="executar" class="principal" title="Ctrl+Enter">▶ Executar</button>
  <button id="verificar" title="Ctrl+Shift+Enter">✓ Verificar</button>
  <button id="novo">Novo</button>
  <button id="abrir">Abrir…</button>
  <button id="salvar" title="Ctrl+S">Salvar</button>
  <select id="exemplos" aria-label="Exemplos"><option value="">Exemplos…</option></select>
  <span class="ver" id="versao"></span>
  <input id="arquivo" type="file" accept=".abt,text/plain" hidden>
</header>
<main>
  <div class="editor">
    <div class="nums" id="nums"></div>
    <div class="codigo"><pre id="realce" aria-hidden="true"></pre><textarea id="ed" spellcheck="false" autocapitalize="off" autocomplete="off" aria-label="Código ABT"></textarea></div>
  </div>
  <div class="saida">
    <div class="barra"><b>Saída</b><span class="estado" id="estado">pronto</span><span id="tempo"></span><button id="baixar" disabled title="Baixa a saída como arquivo de texto">Baixar .txt</button><button id="limpar">Limpar</button></div>
    <pre id="saida" aria-live="polite"></pre>
  </div>
</main>
<footer><span id="pos">Ln 1, Col 1</span><span id="nome">sem título</span><span>Salvo automaticamente neste navegador</span></footer>
<script>
const CFG = __CONFIG__;
const KW = new Set(["mostrar","show","media","média","average","soma","sum","de","of","onde","where","valor","value","é","is","maior","above","menor","below","que","than","se","if","senao","senão","else","para","for","cada","each","em","in","verdadeiro","true","falso","false","e","and","ou","or","função","funcao","function","retornar","return","usar"]);
const $ = id => document.getElementById(id);
const ed = $("ed"), realce = $("realce"), nums = $("nums"), saida = $("saida");
let nome = "sem título", erroLinha = 0, ultimaSaida = "";
const guardar = (k, v) => { try { localStorage.setItem(k, v); } catch (_) {} };
const ler = k => { try { return localStorage.getItem(k); } catch (_) { return null; } };
const esc = s => s.replace(/[&<>]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));

function colorir(src) {
  const re = /(#[^\n]*)|("[^"\n]*"?)|(\d+(?:\.\d+)?)|([\p{L}_][\p{L}\p{N}_]*)|(==|!=|>=|<=|[=+\-*\/^<>])|([\s\S])/gu;
  let out = "", m;
  while ((m = re.exec(src))) {
    if (m[1]) out += `<span class="c">${esc(m[1])}</span>`;
    else if (m[2]) out += `<span class="s">${esc(m[2])}</span>`;
    else if (m[3]) out += `<span class="n">${m[3]}</span>`;
    else if (m[4]) out += KW.has(m[4].toLowerCase()) ? `<span class="k">${m[4]}</span>` : esc(m[4]);
    else if (m[5]) out += `<span class="o">${esc(m[5])}</span>`;
    else out += esc(m[6]);
  }
  return out + "\n";
}
function atualizar() {
  realce.innerHTML = colorir(ed.value);
  const n = ed.value.split("\n").length;
  let t = "";
  for (let i = 1; i <= n; i++) t += (i === erroLinha ? `<span class="err">${i}</span>` : i) + "\n";
  nums.innerHTML = t;
  nums.style.minWidth = (String(n).length + 2) + "ch";
  guardar("abt-ide-codigo", ed.value); guardar("abt-ide-nome", nome);
  sincronizar(); posicao();
}
function sincronizar() { realce.scrollTop = ed.scrollTop; realce.scrollLeft = ed.scrollLeft; nums.scrollTop = ed.scrollTop; }
function posicao() {
  const antes = ed.value.slice(0, ed.selectionStart).split("\n");
  $("pos").textContent = `Ln ${antes.length}, Col ${antes[antes.length - 1].length + 1}`;
}
function definir(codigo, novoNome) { ed.value = codigo; nome = novoNome; $("nome").textContent = nome; erroLinha = 0; atualizar(); }
function irPara(linha, col) {
  const ls = ed.value.split("\n"); let pos = 0;
  for (let i = 0; i < linha - 1 && i < ls.length; i++) pos += ls[i].length + 1;
  ed.focus(); ed.setSelectionRange(pos + Math.max(0, (col || 1) - 1), pos + (ls[linha - 1] || "").length);
  ed.scrollTop = Math.max(0, (linha - 4) * 21);
}
function mostrarSaida(r, modo) {
  erroLinha = 0;
  let html = esc(r.saida);
  if (r.erro) {
    const lig = esc(r.erro).replace(/(\d+):(\d+)/g, (t, l, c) => { if (!erroLinha) erroLinha = +l; return `<a data-l="${l}" data-c="${c}">${t}</a>`; });
    html += `<span class="e">${lig}</span>`;
  }
  if (!r.saida && !r.erro) html = r.codigo_saida === 0 ? (modo === "check" ? "Nenhum problema encontrado.\n" : "(sem saída)\n") : "";
  saida.innerHTML = html;
  ultimaSaida = r.codigo_saida === 0 && modo !== "check" ? r.saida : "";
  $("baixar").disabled = !ultimaSaida;
  const ok = r.codigo_saida === 0;
  $("estado").textContent = ok ? (modo === "check" ? "sem erros" : "concluído") : `falhou (código ${r.codigo_saida})`;
  $("estado").className = "estado " + (ok ? "ok" : "falha");
  $("tempo").textContent = r.ms + " ms";
  atualizar();
}
saida.addEventListener("click", e => { const a = e.target.closest("a[data-l]"); if (a) irPara(+a.dataset.l, +a.dataset.c); });
async function rodar(modo) {
  const bs = [$("executar"), $("verificar")]; bs.forEach(b => b.disabled = true);
  $("estado").textContent = "executando…"; $("estado").className = "estado";
  try {
    const r = await fetch("/api/executar", { method: "POST", headers: { "Content-Type": "application/json", "X-IDE-Token": CFG.token }, body: JSON.stringify({ codigo: ed.value, modo }) });
    if (!r.ok) throw new Error(await r.text());
    mostrarSaida(await r.json(), modo);
  } catch (e) {
    saida.innerHTML = `<span class="e">${esc(String(e.message || e))}</span>`;
    $("estado").textContent = "erro de comunicação"; $("estado").className = "estado falha";
  } finally { bs.forEach(b => b.disabled = false); }
}
function salvar() {
  const n = nome.endsWith(".abt") ? nome : (nome === "sem título" ? "programa.abt" : nome + ".abt");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([ed.value], { type: "text/plain;charset=utf-8" })); a.download = n;
  document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}
$("executar").onclick = () => rodar("run");
$("verificar").onclick = () => rodar("check");
$("salvar").onclick = salvar;
$("baixar").onclick = () => {
  const pedido = (ed.value.match(/^#\s*arquivo:\s*([\w-]+)(?:\.txt)?\s*$/mi) || [])[1];
  const base = pedido || (nome.replace(/\.abt$/, "").replace(/^\d+\.\s*/, "").split(":")[0].trim() || "saida").replace(/[^\p{L}\p{N}_-]+/gu, "_");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob(["﻿" + ultimaSaida], { type: "text/plain;charset=utf-8" })); a.download = base + ".txt";
  document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1000);
};
$("limpar").onclick = () => { ultimaSaida = ""; $("baixar").disabled = true; saida.textContent = ""; $("estado").textContent = "pronto"; $("estado").className = "estado"; $("tempo").textContent = ""; };
$("novo").onclick = () => { if (!ed.value.trim() || confirm("Descartar o código atual?")) definir("", "sem título"); };
$("abrir").onclick = () => $("arquivo").click();
$("arquivo").onchange = async e => { const f = e.target.files[0]; if (f) definir(await f.text(), f.name); e.target.value = ""; };
const sel = $("exemplos");
Object.keys(CFG.exemplos).forEach(n => sel.add(new Option(n, n)));
sel.onchange = () => { if (sel.value && (!ed.value.trim() || confirm("Substituir o código atual pelo exemplo?"))) definir(CFG.exemplos[sel.value], sel.value); sel.value = ""; };
$("versao").textContent = CFG.versao || "ABT não encontrada";
ed.addEventListener("input", () => { erroLinha = 0; atualizar(); });
ed.addEventListener("scroll", sincronizar);
ed.addEventListener("keyup", posicao); ed.addEventListener("click", posicao);
ed.addEventListener("keydown", e => {
  if (e.key === "Tab") { e.preventDefault(); document.execCommand("insertText", false, "    "); }
  else if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); rodar(e.shiftKey ? "check" : "run"); }
  else if ((e.key === "s" || e.key === "S") && (e.ctrlKey || e.metaKey)) { e.preventDefault(); salvar(); }
  else if (e.key === "Enter" && !e.ctrlKey && !e.metaKey) {
    const antes = ed.value.slice(0, ed.selectionStart), linha = antes.slice(antes.lastIndexOf("\n") + 1);
    let ind = linha.match(/^\s*/)[0]; if (/\{\s*$/.test(linha)) ind += "    ";
    e.preventDefault(); document.execCommand("insertText", false, "\n" + ind);
  }
});
definir(ler("abt-ide-codigo") ?? CFG.padrao, ler("abt-ide-nome") || "sem título");
ed.focus();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
