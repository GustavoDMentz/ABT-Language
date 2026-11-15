# Constroi o pacote do instalador integrado para Windows: Julia 1.13.3 + ABT + pacotes
# (sem caches pre-compilados, que so valem no caminho onde foram gerados).
#
#   tools\construir_bundle.ps1 [-Saida DIR] [-JuliaDir DIR]
#
# Gera DIR\abt-<versao>-windows-x86_64.zip, o .sha256 correspondente e VERSION.
# (ASCII de proposito: o Windows PowerShell 5.1 le arquivos sem BOM como ANSI.)
param(
    [string]$Saida = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist'),
    [string]$JuliaDir = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$JuliaUrl = 'https://julialang-s3.julialang.org/bin/winnt/x64/1.13/julia-1.13.3-win64.zip'
$JuliaSha256 = '1fae8fc95e6199b3d8f6d7a3791810e45e1b3c480eb4b9f5bb211789badfc729'
$Plataforma = 'windows-x86_64'
$Raiz = Split-Path -Parent $PSScriptRoot
$Tar = Join-Path $env:SystemRoot 'System32\tar.exe'
$Utf8 = New-Object Text.UTF8Encoding($false)

function Falha($m) { throw "construir_bundle: $m" }

$projeto = Get-Content -LiteralPath (Join-Path $Raiz 'Project.toml') -Raw
if ($projeto -notmatch '(?m)^version\s*=\s*"([^"]+)"') { Falha 'versao nao encontrada em Project.toml' }
$versao = $Matches[1]

New-Item -ItemType Directory -Path $Saida -Force | Out-Null
$Saida = (Resolve-Path $Saida).Path
$trabalho = Join-Path ([IO.Path]::GetTempPath()) ('abt-bundle-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $trabalho | Out-Null
try {
    $bundle = Join-Path $trabalho 'abt'
    New-Item -ItemType Directory -Path (Join-Path $bundle 'runtime') -Force | Out-Null
    $juliaDestino = Join-Path $bundle 'runtime\julia'

    Write-Host '==> Julia'
    if ($JuliaDir) {
        Copy-Item -LiteralPath $JuliaDir -Destination $juliaDestino -Recurse
    } else {
        $zip = Join-Path $trabalho 'julia.zip'
        & (Join-Path $env:SystemRoot 'System32\curl.exe') -fL --retry 3 -o $zip $JuliaUrl
        if ($LASTEXITCODE -ne 0) { Falha 'falha ao baixar a Julia' }
        $soma = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
        if ($soma -ne $JuliaSha256) { Falha "SHA-256 da Julia diferente do fixado ($soma)" }
        New-Item -ItemType Directory -Path $juliaDestino | Out-Null
        & $Tar -xf $zip -C $juliaDestino --strip-components=1
        if ($LASTEXITCODE -ne 0) { Falha 'falha ao extrair a Julia' }
        Remove-Item -LiteralPath $zip
    }
    $julia = Join-Path $juliaDestino 'bin\julia.exe'
    if ((& $julia --version).Trim() -ne 'julia version 1.13.3') { Falha 'Julia diferente da homologada (1.13.3)' }

    Write-Host '==> Codigo da ABT'
    foreach ($item in 'bin', 'src') { Copy-Item -LiteralPath (Join-Path $Raiz $item) -Destination (Join-Path $bundle $item) -Recurse }
    foreach ($item in 'Project.toml', 'Manifest.toml', 'ABT.packages.toml') { Copy-Item -LiteralPath (Join-Path $Raiz $item) -Destination $bundle }
    New-Item -ItemType Directory -Path (Join-Path $bundle 'libexec') | Out-Null
    Copy-Item -LiteralPath (Join-Path $Raiz 'tools\instalar.ps1') -Destination (Join-Path $bundle 'libexec\instalar.ps1')

    Write-Host '==> Pacotes Julia (sem pre-compilar)'
    $env:JULIA_DEPOT_PATH = Join-Path $bundle 'depot'
    $env:JULIA_PKG_PRECOMPILE_AUTO = '0'
    & $julia --startup-file=no ("--project=" + $bundle) -e 'import Pkg; Pkg.instantiate()'
    if ($LASTEXITCODE -ne 0) { Falha 'Pkg.instantiate falhou' }
    foreach ($sub in 'compiled', 'registries', 'logs', 'scratchspaces') {
        $d = Join-Path $bundle "depot\$sub"
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    }
    if (-not ((Test-Path (Join-Path $bundle 'depot\packages')) -and (Test-Path (Join-Path $bundle 'depot\artifacts')))) { Falha 'depot incompleto' }

    Write-Host '==> Avisos de terceiros'
    $linhas = New-Object Collections.Generic.List[string]
    $linhas.Add('# Componentes de terceiros incluidos neste pacote')
    $linhas.Add('')
    $linhas.Add('A ABT e distribuida junto com os componentes abaixo, cada um sob a sua propria licenca.')
    $linhas.Add('')
    $linhas.Add('- **Julia 1.13.3**: `runtime/julia/LICENSE.md` (MIT, mais as licencas das bibliotecas que ela inclui).')
    $linhas.Add('- **Pacotes Julia** (versoes fixadas em `Manifest.toml`): o texto de cada licenca esta no arquivo `LICENSE*` dentro de `depot/packages/<Pacote>/<hash>/`.')
    $linhas.Add('- **Bibliotecas binarias** (artefatos JLL, como o Cairo): licencas em `depot/artifacts/<hash>/share/licenses/`.')
    $linhas.Add('')
    $linhas.Add('## Pacotes Julia')
    $linhas.Add('')
    $linhas.Add('| Pacote | Versao |')
    $linhas.Add('|---|---|')
    $nome = $null
    foreach ($linha in Get-Content -LiteralPath (Join-Path $bundle 'Manifest.toml')) {
        if ($linha -match '^\[\[deps\.(.+)\]\]$') { $nome = $Matches[1] }
        elseif ($nome -and $linha -match '^version = "(.+)"$') { $linhas.Add("| $nome | $($Matches[1]) |"); $nome = $null }
    }
    [IO.File]::WriteAllText((Join-Path $bundle 'THIRD_PARTY_NOTICES.md'), (($linhas -join "`n") + "`n"), $Utf8)

    Write-Host '==> Empacotando'
    $arquivo = "abt-$versao-$Plataforma.zip"
    $destino = Join-Path $Saida $arquivo
    if (Test-Path -LiteralPath $destino) { Remove-Item -LiteralPath $destino }
    & $Tar -a -cf $destino -C $trabalho abt
    if ($LASTEXITCODE -ne 0) { Falha 'falha ao criar o zip' }
    $somaPacote = (Get-FileHash -Algorithm SHA256 -LiteralPath $destino).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$destino.sha256", "$somaPacote  $arquivo`n", $Utf8)
    [IO.File]::WriteAllText((Join-Path $Saida 'VERSION'), "$versao`n", $Utf8)
    Write-Host ("==> Pronto: {0} ({1:N0} MB)" -f $destino, ((Get-Item -LiteralPath $destino).Length / 1MB))
} finally {
    if (Test-Path -LiteralPath $trabalho) {
        Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c rmdir /s /q "' + $trabalho + '"') -Wait -NoNewWindow
    }
}
