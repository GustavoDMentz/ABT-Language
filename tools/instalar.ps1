# Instalador integrado da ABT para Windows (x64): traz a Julia 1.13.3 e os pacotes junto.
# Sem administrador, sem Python, sem instalar Julia a parte.
#
#   irm https://raw.githubusercontent.com/GustavoDMentz/ABT-Language/main/tools/instalar.ps1 | iex
#
# Configuracao por variaveis de ambiente (assim funciona com `| iex`):
#   ABT_ACAO      instalar (padrao) | atualizar | reparar | desinstalar
#   ABT_PREFIXO   pasta da instalacao (padrao: %LOCALAPPDATA%\ABT)
#   ABT_VERSAO    versao a instalar (padrao: a mais recente)
#   ABT_ARQUIVO   pacote .zip ja baixado (instalacao sem internet); ABT_SHA256 = soma esperada
#   ABT_SEM_PATH  1 = nao altera o PATH do usuario
#   ABT_FORCAR    1 = reinstala mesmo que a versao ja esteja instalada
#   ABT_SIM       1 = nao pede confirmacao ao desinstalar
#   ABT_REPO, ABT_BASE_URL  origem dos pacotes (testes)
#
# O pacote traz a Julia e os pacotes, mas sem os caches pre-compilados: eles so valem no
# caminho exato onde a Julia estava quando foram gerados, entao sao gerados no destino.
# (Este arquivo e propositalmente ASCII: o Windows PowerShell 5.1 le arquivos sem BOM como ANSI.)

function Invoke-InstaladorAbt {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

    function Info($m) { Write-Host "ABT: $m" }
    function Aviso($m) { Write-Host "ABT: $m" -ForegroundColor Yellow }
    function Falha($m) { throw "ABT: $m" }

    $acao = $env:ABT_ACAO; if (-not $acao) { $acao = 'instalar' }
    $repo = $env:ABT_REPO; if (-not $repo) { $repo = 'GustavoDMentz/ABT-Language' }
    $baseUrl = $env:ABT_BASE_URL; if (-not $baseUrl) { $baseUrl = "https://github.com/$repo/releases" }
    $prefixo = $env:ABT_PREFIXO
    if (-not $prefixo -and $env:ABT_PREFIXO_ATUAL -and $acao -ne 'instalar') { $prefixo = $env:ABT_PREFIXO_ATUAL }
    if (-not $prefixo) { $prefixo = Join-Path $env:LOCALAPPDATA 'ABT' }
    $prefixo = [IO.Path]::GetFullPath($prefixo).TrimEnd('\')
    $plataforma = 'windows-x86_64'
    $juliaVersao = 'julia version 1.13.3'
    $marcador = Join-Path $prefixo '.abt-install.json'
    $utf8 = New-Object Text.UTF8Encoding($false)

    if ($env:OS -ne 'Windows_NT') { Falha 'este instalador e para Windows. No Linux use tools/instalar.sh.' }
    if (-not [Environment]::Is64BitOperatingSystem) { Falha 'e preciso um Windows de 64 bits.' }
    if ($prefixo.Contains('"')) { Falha 'o caminho da instalacao nao pode conter aspas.' }

    # ------------------------------------------------------------ utilidades
    function Baixar($url, $destino) {
        $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
        if (Test-Path $curl) {
            & $curl -fL --retry 3 --progress-bar -o $destino $url
            if ($LASTEXITCODE -ne 0) { Falha "falha ao baixar $url" }
        } else {
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $destino
        }
    }
    function Soma($arquivo) { (Get-FileHash -Algorithm SHA256 -LiteralPath $arquivo).Hash.ToLowerInvariant() }
    function Remover($caminho) {
        # rmdir /s evita o limite de 260 caracteres que o Remove-Item do PowerShell 5.1 pode encontrar
        if (Test-Path -LiteralPath $caminho) {
            Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c rmdir /s /q "' + $caminho + '"') -Wait -NoNewWindow
            if (Test-Path -LiteralPath $caminho) { Remove-Item -LiteralPath $caminho -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    function LerMarcador() {
        if (-not (Test-Path -LiteralPath $marcador)) { return $null }
        try { return ([IO.File]::ReadAllText($marcador, $utf8) | ConvertFrom-Json) } catch { return $null }
    }
    function EntradasPath() {
        $p = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $p) { return @() }
        return @($p.Split(';') | Where-Object { $_ -ne '' })
    }
    function GravarPath($entradas) {
        [Environment]::SetEnvironmentVariable('Path', ($entradas -join ';'), 'User')
    }
    function NormalizaDir($d) { return $d.TrimEnd('\').ToLowerInvariant() }
    function AdicionaPath($dir) {
        $e = EntradasPath
        if (-not ($e | Where-Object { (NormalizaDir $_) -eq (NormalizaDir $dir) })) { GravarPath ($e + $dir) }
        if (-not (($env:Path.Split(';') | ForEach-Object { NormalizaDir $_ }) -contains (NormalizaDir $dir))) { $env:Path = "$env:Path;$dir" }
    }
    function RemovePath($dir) {
        $e = EntradasPath
        $novo = @($e | Where-Object { (NormalizaDir $_) -ne (NormalizaDir $dir) })
        if ($novo.Count -ne $e.Count) { GravarPath $novo }
    }
    function PreCompilar() {
        Info 'pre-compilando pacotes para este computador. Isto leva alguns minutos e so acontece uma vez.'
        $env:JULIA_DEPOT_PATH = Join-Path $prefixo 'depot'
        $env:JULIA_PKG_OFFLINE = 'true'
        $julia = Join-Path $prefixo 'runtime\julia\bin\julia.exe'
        & $julia --startup-file=no ("--project=" + $prefixo) -e 'import Pkg; Pkg.precompile(); using ABT'
        if ($LASTEXITCODE -ne 0) { return $false }
        [IO.File]::WriteAllText((Join-Path $prefixo '.abt-prefixo'), $prefixo + "`r`n", $utf8)
        return $true
    }
    function TesteRapido() {
        $pasta = Join-Path ([IO.Path]::GetTempPath()) ('abt-teste-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $pasta | Out-Null
        try {
            $programa = Join-Path $pasta 'teste.abt'
            [IO.File]::WriteAllText($programa, "mostrar 1`n", $utf8)
            $eap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try { $resposta = (& (Join-Path $prefixo 'bin\abt.cmd') run $programa 2>&1 | Out-String).Trim() } finally { $ErrorActionPreference = $eap }
            if ($LASTEXITCODE -ne 0) { Aviso "teste de execucao falhou: $resposta"; return $false }
            if ($resposta -ne '1') { Aviso "teste de execucao devolveu '$resposta' em vez de 1"; return $false }
            return $true
        } finally { Remover $pasta }
    }

    # ------------------------------------------------------------ reparar
    if ($acao -eq 'reparar') {
        $m = LerMarcador
        if (-not $m) { Falha "nenhuma instalacao integrada em $prefixo" }
        $antigo = $null
        if ($m.prefixo -and ($m.prefixo -ne $prefixo)) { $antigo = $m.prefixo }
        if (-not (PreCompilar)) { Falha 'a pre-compilacao falhou' }
        if (-not (TesteRapido)) { Falha 'a instalacao nao passou no teste de execucao' }
        if ($m.path) {
            if ($antigo) { RemovePath (Join-Path $antigo 'bin') }
            AdicionaPath (Join-Path $prefixo 'bin')
        }
        $novoMarcador = [ordered]@{ application = 'ABT'; schema = 2; versao = $m.versao; plataforma = $plataforma; prefixo = $prefixo; path = [bool]$m.path }
        [IO.File]::WriteAllText($marcador, (($novoMarcador | ConvertTo-Json -Compress) + "`r`n"), $utf8)
        Info "instalacao reparada em $prefixo."
        return
    }

    # ------------------------------------------------------------ desinstalar
    if ($acao -eq 'desinstalar') {
        if (-not (Test-Path -LiteralPath $prefixo)) { Info "nada instalado em $prefixo."; return }
        $m = LerMarcador
        if (-not $m) { Falha "$prefixo nao tem marcador de instalacao integrada; nada foi removido" }
        if ($env:ABT_SIM -ne '1') {
            $r = Read-Host "Remover a ABT de $prefixo ? [s/N]"
            if ($r -notmatch '^(s|sim)$') { Info 'cancelado.'; return }
        }
        RemovePath (Join-Path $prefixo 'bin')
        # O abt.cmd que chamou este script ainda esta em execucao: se ele for apagado agora, o cmd.exe nao
        # consegue ler a linha seguinte e termina com erro. Apaga tudo menos ele e remove o resto logo depois.
        $lancador = (Join-Path $prefixo 'bin\abt.cmd').ToLowerInvariant()
        Get-ChildItem -LiteralPath $prefixo -Force | Where-Object { $_.Name -ne 'bin' } | ForEach-Object { Remover $_.FullName }
        $binDir = Join-Path $prefixo 'bin'
        if (Test-Path -LiteralPath $binDir) {
            Get-ChildItem -LiteralPath $binDir -Force | Where-Object { $_.FullName.ToLowerInvariant() -ne $lancador } | ForEach-Object { Remover $_.FullName }
        }
        if (Test-Path -LiteralPath $lancador) {
            Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ping -n 3 127.0.0.1 >nul & rmdir /s /q "' + $prefixo + '"') -WindowStyle Hidden
        } else {
            Remover $prefixo
        }
        Info 'ABT removida. O seu .julia (se existir) nao foi tocado.'
        return
    }

    if ($acao -ne 'instalar' -and $acao -ne 'atualizar') { Falha "acao desconhecida: $acao" }

    # ------------------------------------------------------------ instalar / atualizar
    if (Test-Path -LiteralPath $prefixo) {
        $m = LerMarcador
        if (-not $m) { Falha "$prefixo existe mas nao tem marcador de instalacao integrada. Nada foi alterado." }
    }
    $trabalho = "$prefixo.tmp." + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $backup = $null
    $trocado = $false
    $concluido = $false
    New-Item -ItemType Directory -Path (Split-Path -Parent $prefixo) -Force | Out-Null
    New-Item -ItemType Directory -Path $trabalho | Out-Null
    try {
        $arquivo = $env:ABT_ARQUIVO
        $somaEsperada = $env:ABT_SHA256
        $versao = $env:ABT_VERSAO
        if ($arquivo) {
            if (-not (Test-Path -LiteralPath $arquivo)) { Falha "arquivo nao encontrado: $arquivo" }
            $pacote = $arquivo
            if (-not $somaEsperada -and (Test-Path -LiteralPath "$arquivo.sha256")) {
                $somaEsperada = ((Get-Content -LiteralPath "$arquivo.sha256" -Raw).Trim() -split '\s+')[0]
            }
            if (-not $somaEsperada) { Aviso 'sem soma SHA-256 para conferir; instalando sem verificacao de integridade.' }
        } else {
            if (-not $versao) {
                Info 'procurando a versao mais recente'
                Baixar "$baseUrl/latest/download/VERSION" (Join-Path $trabalho 'VERSION')
                $versao = (Get-Content -LiteralPath (Join-Path $trabalho 'VERSION') -Raw).Trim()
            }
            $versao = $versao.TrimStart('v')
            if ($versao -notmatch '^\d+\.\d+\.\d+$') { Falha 'versao invalida recebida do servidor' }
            $m = LerMarcador
            if ($acao -eq 'atualizar' -and $m -and $m.versao -eq $versao -and $env:ABT_FORCAR -ne '1') {
                Info "a ABT $versao ja e a versao mais recente."
                $concluido = $true
                return
            }
            $nome = "abt-$versao-$plataforma.zip"
            $pacote = Join-Path $trabalho $nome
            Info "baixando a ABT $versao (cerca de 300 MB)"
            Baixar "$baseUrl/download/v$versao/$nome" $pacote
            Baixar "$baseUrl/download/v$versao/$nome.sha256" "$pacote.sha256"
            $somaEsperada = ((Get-Content -LiteralPath "$pacote.sha256" -Raw).Trim() -split '\s+')[0]
        }
        if ($somaEsperada) {
            $real = Soma $pacote
            if ($real -ne $somaEsperada.ToLowerInvariant()) { Falha "soma SHA-256 diferente da esperada (esperada $somaEsperada, obtida $real); nada foi instalado" }
            Info 'integridade do pacote verificada (SHA-256).'
        }

        Info 'extraindo (alguns minutos)'
        $novo = Join-Path $trabalho 'novo'
        New-Item -ItemType Directory -Path $novo | Out-Null
        $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
        if (Test-Path $tar) {
            & $tar -xf $pacote -C $novo --strip-components=1
            if ($LASTEXITCODE -ne 0) { Falha 'falha ao extrair o pacote' }
        } else {
            $tmp = Join-Path $trabalho 'extraido'
            Expand-Archive -LiteralPath $pacote -DestinationPath $tmp -Force
            Get-ChildItem -LiteralPath (Join-Path $tmp 'abt') | Move-Item -Destination $novo
        }
        foreach ($rel in 'bin\abt.cmd', 'src\CLI.jl', 'Project.toml', 'Manifest.toml', 'runtime\julia\bin\julia.exe') {
            if (-not (Test-Path -LiteralPath (Join-Path $novo $rel))) { Falha "pacote invalido: falta $rel" }
        }
        $v = (& (Join-Path $novo 'runtime\julia\bin\julia.exe') --version 2>&1 | Out-String).Trim()
        if ($v -ne $juliaVersao) { Falha "o pacote nao traz a Julia esperada ($juliaVersao)" }
        $textoProjeto = Get-Content -LiteralPath (Join-Path $novo 'Project.toml') -Raw
        if ($textoProjeto -notmatch '(?m)^version\s*=\s*"([^"]+)"') { Falha 'pacote invalido: versao ausente em Project.toml' }
        $versaoPacote = $Matches[1]

        $marcadorAnterior = LerMarcador
        if (Test-Path -LiteralPath $prefixo) {
            $backup = "$prefixo.antiga." + [guid]::NewGuid().ToString('N').Substring(0, 8)
            Move-Item -LiteralPath $prefixo -Destination $backup
        }
        Move-Item -LiteralPath $novo -Destination $prefixo
        $trocado = $true
        $usarPath = ($env:ABT_SEM_PATH -ne '1')
        $novoMarcador = [ordered]@{ application = 'ABT'; schema = 2; versao = $versaoPacote; plataforma = $plataforma; prefixo = $prefixo; path = $usarPath }
        [IO.File]::WriteAllText($marcador, (($novoMarcador | ConvertTo-Json -Compress) + "`r`n"), $utf8)

        if (-not (PreCompilar)) { Falha 'a pre-compilacao falhou' }
        if (-not (TesteRapido)) { Falha 'a instalacao nao passou no teste de execucao' }
        if ($usarPath) { AdicionaPath (Join-Path $prefixo 'bin') }

        $concluido = $true
        if ($backup) { Remover $backup; $backup = $null }
        Info "ABT $versaoPacote instalada em $prefixo."
        if ($usarPath) { Info 'a pasta bin foi adicionada ao PATH do usuario; abra um novo terminal para usar o comando abt.' }
        else { Info "adicione $(Join-Path $prefixo 'bin') ao PATH para usar o comando abt." }
        Info 'para comecar: abt doctor'
    } finally {
        if (-not $concluido -and $trocado) {
            Remover $prefixo
            if ($backup) { Move-Item -LiteralPath $backup -Destination $prefixo; Info 'instalacao anterior restaurada.' }
        }
        Remover $trabalho
    }
}

$codigoSaidaAbt = 0
try { Invoke-InstaladorAbt } catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $codigoSaidaAbt = 1
}
# Executado como arquivo (-File): devolve o codigo de saida. Via `| iex` nao fecha a janela do usuario.
if ($MyInvocation.MyCommand.Path) { exit $codigoSaidaAbt }
