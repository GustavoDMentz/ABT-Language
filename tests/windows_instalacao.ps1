# Teste de ponta a ponta do instalador integrado no Windows (roda no CI, em um Windows limpo).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\windows_instalacao.ps1 -Pacote dist\abt-X.Y.Z-windows-x86_64.zip [-Rapido]
#
# Usa o Windows PowerShell 5.1, o mesmo que o usuario final tem. Sem Julia instalada.
# -Rapido: instala, roda um exemplo e desinstala (para iterar no CI).
# (ASCII de proposito: o Windows PowerShell 5.1 le arquivos sem BOM como ANSI.)
param(
    [Parameter(Mandatory = $true)][string]$Pacote,
    [switch]$Rapido
)
$ErrorActionPreference = 'Stop'
$Raiz = Split-Path -Parent $PSScriptRoot
$Pacote = (Resolve-Path $Pacote).Path
$Instalador = Join-Path $Raiz 'tools\instalar.ps1'
$Temp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
# Caminho com espaco e acentos (instalacao + c cedilha + a til + o)
$Prefixo = Join-Path $Temp ('abt instala' + [char]0x00E7 + [char]0x00E3 + 'o')
$Movido = Join-Path $Temp ('abt movido ' + [char]0x00E9)
$Falhas = 0

function Ok($m) { Write-Host "ok    $m" -ForegroundColor Green }
function Erro($m) { Write-Host "FALHA $m" -ForegroundColor Red; $script:Falhas++ }
function Verifica($condicao, $mensagem) { if ($condicao) { Ok $mensagem } else { Erro $mensagem } }

# Executa um comando nativo sem que stderr vire excecao; devolve codigo e texto.
function Executa($exe, [string[]]$argumentos) {
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $texto = (& $exe @argumentos 2>&1 | Out-String)
        return [pscustomobject]@{ Codigo = $LASTEXITCODE; Texto = $texto }
    } finally { $ErrorActionPreference = $eap }
}
function Instalador($acao, $variaveis) {
    $env:ABT_ACAO = $acao
    foreach ($k in $variaveis.Keys) { Set-Item -Path "Env:$k" -Value $variaveis[$k] }
    try {
        $r = Executa 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Instalador)
        Write-Host $r.Texto
        return $r
    } finally {
        Remove-Item Env:ABT_ACAO -ErrorAction SilentlyContinue
        foreach ($k in $variaveis.Keys) { Remove-Item "Env:$k" -ErrorAction SilentlyContinue }
    }
}
function PathUsuario() { [Environment]::GetEnvironmentVariable('Path', 'User') }

# Os runners do GitHub trazem uma Julia no PATH; o teste simula uma maquina sem Julia.
$env:Path = (($env:Path -split ';') | Where-Object { $_ -and -not (Test-Path (Join-Path $_ 'julia.exe')) }) -join ';'
Remove-Item Env:ABT_JULIA -ErrorAction SilentlyContinue
Verifica (-not (Get-Command julia -ErrorAction SilentlyContinue)) 'nao ha Julia no PATH (ambiente limpo)'

# ---------------------------------------------------------------- instalacao
Write-Host "== instalacao em $Prefixo"
$r = Instalador 'instalar' @{ ABT_PREFIXO = $Prefixo; ABT_ARQUIVO = $Pacote }
Verifica ($r.Codigo -eq 0) 'instalacao terminou com codigo 0'
$abt = Join-Path $Prefixo 'bin\abt.cmd'
Verifica (Test-Path $abt) 'bin\abt.cmd existe'
Verifica (Test-Path (Join-Path $Prefixo '.abt-install.json')) 'marcador gravado'
Verifica ((PathUsuario) -like "*$Prefixo\bin*") 'bin foi adicionado ao PATH do usuario'
if ($Falhas -gt 0) { throw 'instalacao falhou; abortando' }

$r = Executa $abt @('doctor')
Write-Host $r.Texto
Verifica ($r.Codigo -eq 0 -and $r.Texto -match 'embutida') 'abt doctor usa a Julia embutida'
$r = Executa $abt @('--version')
Verifica ($r.Codigo -eq 0 -and $r.Texto -match 'ABT \d+\.\d+\.\d+') "abt --version: $($r.Texto.Trim())"

# ---------------------------------------------------------------- exemplos
Write-Host '== exemplos da documentacao'
$env:ABT_FIGURA_PATH = Join-Path $Temp 'figura.png'
$env:ABT_DOC_FIGURE_PATH = Join-Path $Temp 'figura2.png'
Push-Location $Raiz
try {
    $exemplos = Get-ChildItem 'docs\examples\*.abt' | Sort-Object Name
    if ($Rapido) { $exemplos = $exemplos | Where-Object { $_.Name -in 'nucleo.abt', 'falhar.abt' } }
    foreach ($e in $exemplos) {
        $r = Executa $abt @('run', $e.FullName)
        $esperado = if ($e.Name -eq 'falhar.abt') { 1 } else { 0 }
        if ($r.Codigo -eq $esperado) { Ok $e.Name } else { Erro "$($e.Name) (codigo $($r.Codigo), esperado $esperado): $($r.Texto)" }
    }
} finally { Pop-Location }

# Saida em UTF-8 com acentos, perfil rapido e arquivo com espaco no nome
$dirProg = Join-Path $Temp ('programa com espa' + [char]0x00E7 + 'o')
New-Item -ItemType Directory -Path $dirProg -Force | Out-Null
$prog = Join-Path $dirProg 'ol.abt'
$textoAcentuado = 'Ol' + [char]0x00E1 + ', mundo ' + [char]0x00E7 + [char]0x00E3 + 'o'
[IO.File]::WriteAllText($prog, ('mostrar "' + $textoAcentuado + '"' + "`n"), (New-Object Text.UTF8Encoding($false)))
$saida = Join-Path $Temp 'saida.txt'
& cmd.exe /c ('"' + $abt + '" run "' + $prog + '" > "' + $saida + '"')
$lido = [IO.File]::ReadAllText($saida, [Text.Encoding]::UTF8).Trim()
Verifica ($lido -eq $textoAcentuado) "saida com acentos em UTF-8 ('$lido')"
$r = Executa $abt @('--perfil', 'rapido', 'run', $prog)
Verifica ($r.Codigo -eq 0 -and $r.Texto.Trim() -eq $textoAcentuado) '--perfil rapido executa'
$r = Executa $abt @('--perfil', 'invalido', 'run', $prog)
Verifica ($r.Codigo -eq 2) 'perfil invalido devolve codigo 2'

if (-not $Rapido) {
    # ---------------------------------------------------------------- atualizar (reinstala por cima, via file://)
    Write-Host '== atualizar (forcado) a partir de um servidor local'
    $versao = (Get-Content (Join-Path $Raiz 'Project.toml') -Raw | Select-String '(?m)^version\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
    $servidor = Join-Path $Temp 'servidor'
    New-Item -ItemType Directory -Path (Join-Path $servidor "download\v$versao") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $servidor 'latest\download') -Force | Out-Null
    Copy-Item $Pacote (Join-Path $servidor "download\v$versao")
    Copy-Item "$Pacote.sha256" (Join-Path $servidor "download\v$versao")
    [IO.File]::WriteAllText((Join-Path $servidor 'latest\download\VERSION'), "$versao`n")
    $base = 'file:///' + ($servidor -replace '\\', '/')
    $r = Instalador 'atualizar' @{ ABT_PREFIXO = $Prefixo; ABT_BASE_URL = $base }
    Verifica ($r.Codigo -eq 0 -and $r.Texto -match 'mais recente') 'atualizar reconhece que ja esta na versao mais recente'
    $r = Instalador 'atualizar' @{ ABT_PREFIXO = $Prefixo; ABT_BASE_URL = $base; ABT_FORCAR = '1' }
    Verifica ($r.Codigo -eq 0 -and $r.Texto -match 'instalada em') 'atualizar forcado reinstala por cima'
    $leftovers = @(Get-ChildItem (Split-Path -Parent $Prefixo) -Filter 'abt instala*' | Where-Object { $_.Name -match '\.(tmp|antiga)\.' })
    Verifica ($leftovers.Count -eq 0) 'nenhuma sobra de pasta temporaria ou antiga'
    $r = Executa $abt @('run', $prog)
    Verifica ($r.Codigo -eq 0) 'abt continua funcionando depois de atualizar'

    # ---------------------------------------------------------------- mover e reparar
    Write-Host '== mover a pasta e reparar'
    if (Test-Path $Movido) { Remove-Item $Movido -Recurse -Force }
    Move-Item $Prefixo $Movido
    $abtMovido = Join-Path $Movido 'bin\abt.cmd'
    $r = Executa $abtMovido @('doctor')
    Verifica ($r.Codigo -ne 0 -and $r.Texto -match 'abt reparar') 'doctor avisa que a instalacao foi movida'
    $r = Executa 'powershell.exe' @('-NoProfile', '-Command', "`$env:ABT_SIM='1'; & '$abtMovido' reparar")
    Write-Host $r.Texto
    Verifica ($r.Codigo -eq 0) 'abt reparar terminou com codigo 0'
    $r = Executa $abtMovido @('run', $prog)
    Verifica ($r.Codigo -eq 0 -and $r.Texto.Trim() -eq $textoAcentuado) 'abt funciona depois de reparar, sem avisos'
    Verifica ((PathUsuario) -like "*$Movido\bin*" -and -not ((PathUsuario) -like "*$Prefixo\bin*")) 'PATH aponta para a nova pasta'
    $Prefixo = $Movido
    $abt = $abtMovido
}

# ---------------------------------------------------------------- desinstalar
Write-Host '== desinstalar'
$r = Executa $abt @('desinstalar', '--sim')
Write-Host $r.Texto
Verifica ($r.Codigo -eq 0) 'abt desinstalar terminou com codigo 0'
# O abt.cmd em execucao so pode ser apagado depois que o cmd.exe termina: a remocao final e adiada por alguns segundos.
for ($i = 0; $i -lt 30 -and (Test-Path $Prefixo); $i++) { Start-Sleep -Seconds 1 }
Verifica (-not (Test-Path $Prefixo)) 'pasta da instalacao removida'
Verifica (-not ((PathUsuario) -like "*$Prefixo\bin*")) 'bin removido do PATH do usuario'

if ($Falhas -gt 0) { Write-Host "$Falhas verificacao(oes) falharam" -ForegroundColor Red; exit 1 }
Write-Host 'todas as verificacoes passaram' -ForegroundColor Green
