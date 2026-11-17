@echo off
rem Lancador da ABT para Windows (equivalente ao bin/abt do Linux).
rem Usa a Julia e o depot embutidos pela instalacao integrada (tools/instalar.ps1),
rem exceto quando ABT_JULIA esta definida.
rem   abt.cmd [--perfil padrao ou rapido] comando ...   (--perfil so como primeiro argumento)
setlocal EnableExtensions DisableDelayedExpansion

for %%I in ("%~dp0..") do set "ABT_ROOT=%%~fI"

rem Console em UTF-8 durante a execucao; restaura a pagina de codigo ao sair.
set "ABT_CHCP="
for /f "tokens=2 delims=:" %%C in ('chcp 2^>nul') do set "ABT_CHCP=%%C"
if defined ABT_CHCP set "ABT_CHCP=%ABT_CHCP: =%"
chcp 65001 >nul 2>nul

set "ABT_EMBUTIDO=0"
set "ABT_RUNTIME=julia"
if defined ABT_JULIA set "ABT_RUNTIME=%ABT_JULIA%"
if not defined ABT_JULIA if exist "%ABT_ROOT%\runtime\julia\bin\julia.exe" (
    set "ABT_EMBUTIDO=1"
    set "ABT_RUNTIME=%ABT_ROOT%\runtime\julia\bin\julia.exe"
    set "JULIA_DEPOT_PATH=%ABT_ROOT%\depot"
    set "JULIA_PKG_OFFLINE=true"
)

rem ---- perfil de execucao
set "ABT_COMPILE=yes"
set "ABT_PERFIL_ORIGEM=padrao"
set "ABT_SHIFT=0"
set "ABT_PERFIL="
if /i "%~1"=="--perfil" (
    set "ABT_PERFIL=%~2"
    set "ABT_SHIFT=2"
    set "ABT_PERFIL_ORIGEM=cli"
    if "%~2"=="" (
        echo ABT: --perfil exige um valor ^(padrao ou rapido^). 1>&2
        set "ABT_RC=2" & goto :sair
    )
) else (
    set "ABT_ARG1=%~1"
    setlocal EnableDelayedExpansion
    if /i "!ABT_ARG1:~0,9!"=="--perfil=" (
        endlocal
        for /f "tokens=1* delims==" %%A in ("%~1") do set "ABT_PERFIL=%%B"
        set "ABT_SHIFT=1"
        set "ABT_PERFIL_ORIGEM=cli"
    ) else (
        endlocal
    )
)
if "%ABT_PERFIL_ORIGEM%"=="cli" (
    if /i "%ABT_PERFIL%"=="padrao" (
        set "ABT_COMPILE=yes"
    ) else if /i "%ABT_PERFIL%"=="rapido" (
        set "ABT_COMPILE=min"
    ) else (
        echo ABT: perfil invalido ^(use padrao ou rapido^). 1>&2
        set "ABT_RC=2" & goto :sair
    )
) else if defined ABT_JULIA_COMPILE (
    set "ABT_COMPILE=%ABT_JULIA_COMPILE%"
    set "ABT_PERFIL_ORIGEM=ABT_JULIA_COMPILE"
    if /i not "%ABT_COMPILE%"=="min" if /i not "%ABT_COMPILE%"=="yes" if /i not "%ABT_COMPILE%"=="all" if /i not "%ABT_COMPILE%"=="no" (
        echo ABT: ABT_JULIA_COMPILE deve ser min, yes, all ou no. 1>&2
        set "ABT_RC=2" & goto :sair
    )
)

rem ---- comandos de manutencao (so na instalacao integrada)
set "ABT_MANUT="
if /i "%~1"=="atualizar" set "ABT_MANUT=atualizar"
if /i "%~1"=="reparar" set "ABT_MANUT=reparar"
if /i "%~1"=="desinstalar" set "ABT_MANUT=desinstalar"
if defined ABT_MANUT goto :manutencao

if /i "%~1"=="doctor" if "%~2"=="" goto :doctor

rem ---- execucao normal
call :verificar_julia || goto :sair
call :aviso_movida
if "%ABT_SHIFT%"=="2" goto :executar2
if "%ABT_SHIFT%"=="1" goto :executar1
"%ABT_RUNTIME%" --startup-file=no --compile=%ABT_COMPILE% --project="%ABT_ROOT%" "%ABT_ROOT%\src\CLI.jl" %*
set "ABT_RC=%ERRORLEVEL%"
goto :sair
:executar1
"%ABT_RUNTIME%" --startup-file=no --compile=%ABT_COMPILE% --project="%ABT_ROOT%" "%ABT_ROOT%\src\CLI.jl" %2 %3 %4 %5 %6 %7 %8 %9
set "ABT_RC=%ERRORLEVEL%"
goto :sair
:executar2
"%ABT_RUNTIME%" --startup-file=no --compile=%ABT_COMPILE% --project="%ABT_ROOT%" "%ABT_ROOT%\src\CLI.jl" %3 %4 %5 %6 %7 %8 %9
set "ABT_RC=%ERRORLEVEL%"
goto :sair

:verificar_julia
set "ABT_JV="
rem A saida vai para um arquivo temporario (e nao para for /f): o for /f passa o comando por cmd /c,
rem que quebra caminhos com e comercial mesmo entre aspas.
set "ABT_JVF=%TEMP%\abt-jv-%RANDOM%%RANDOM%.txt"
"%ABT_RUNTIME%" --version >"%ABT_JVF%" 2>&1
if exist "%ABT_JVF%" set /p ABT_JV=<"%ABT_JVF%"
del "%ABT_JVF%" >nul 2>nul
if not defined ABT_JV (
    echo ABT: Julia nao encontrada. Execute abt doctor para detalhes. 1>&2
    set "ABT_RC=2" & exit /b 2
)
if not "%ABT_JV%"=="julia version 1.13.3" (
    echo ABT: Julia 1.13.3 necessaria; a versao encontrada e diferente. 1>&2
    set "ABT_RC=2" & exit /b 2
)
exit /b 0

:aviso_movida
if not "%ABT_EMBUTIDO%"=="1" exit /b 0
if not exist "%ABT_ROOT%\.abt-prefixo" exit /b 0
set "ABT_PREFIXO_GRAVADO="
set /p ABT_PREFIXO_GRAVADO=<"%ABT_ROOT%\.abt-prefixo"
setlocal EnableDelayedExpansion
if /i "!ABT_PREFIXO_GRAVADO!"=="!ABT_ROOT!" (endlocal & exit /b 0)
endlocal
call :eco_movida
exit /b 1

rem Os valores abaixo vem do disco ou do ambiente e podem ter caracteres especiais: nunca entram em um
rem echo por porcentagem (a expansao acontece antes da analise da linha e executaria o que vier depois
rem do e comercial). Com expansao atrasada (pontos de exclamacao) o valor e apenas texto.
:eco_movida
setlocal EnableDelayedExpansion
echo ABT: a instalacao foi movida de !ABT_PREFIXO_GRAVADO!; execute "abt reparar" (a primeira execucao sera lenta). 1>&2
endlocal & exit /b 0

:eco_raiz
setlocal EnableDelayedExpansion
echo ABT: !ABT_ROOT!
endlocal & exit /b 0

:eco_julia
setlocal EnableDelayedExpansion
if "%ABT_EMBUTIDO%"=="1" echo Julia: !ABT_JV! [embutida em !ABT_ROOT!\runtime\julia]
if not "%ABT_EMBUTIDO%"=="1" echo Julia: !ABT_JV! [externa]
endlocal & exit /b 0


:doctor
call :eco_raiz
if not exist "%ABT_ROOT%\src\CLI.jl" goto :incompleta
if not exist "%ABT_ROOT%\src\ABT.jl" goto :incompleta
if not exist "%ABT_ROOT%\ABT.packages.toml" goto :incompleta
if not exist "%ABT_ROOT%\Project.toml" goto :incompleta
call :verificar_julia || goto :sair
call :eco_julia
call :aviso_movida || ( set "ABT_RC=2" & goto :sair )
echo Compilacao Julia: --compile=%ABT_COMPILE% ^(origem: %ABT_PERFIL_ORIGEM%^)
echo ABT: arquivos essenciais e runtime disponiveis.
set "ABT_RC=0"
goto :sair

:incompleta
echo ABT: instalacao incompleta ^(arquivos essenciais ausentes^). 1>&2
set "ABT_RC=2"
goto :sair

:manutencao
if not "%ABT_EMBUTIDO%"=="1" goto :sem_integrada
if not exist "%ABT_ROOT%\libexec\instalar.ps1" goto :sem_integrada
rem Copia o script: a instalacao pode ser substituida ou removida enquanto ele roda.
set "ABT_TMP_PS=%TEMP%\abt-instalar-%RANDOM%%RANDOM%.ps1"
copy /y "%ABT_ROOT%\libexec\instalar.ps1" "%ABT_TMP_PS%" >nul || ( set "ABT_RC=2" & goto :sair )
set "ABT_ACAO=%ABT_MANUT%"
set "ABT_PREFIXO_ATUAL=%ABT_ROOT%"
if /i "%~2"=="--sim" set "ABT_SIM=1"
if /i "%~2"=="--forcar" set "ABT_FORCAR=1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ABT_TMP_PS%"
set "ABT_RC=%ERRORLEVEL%"
del "%ABT_TMP_PS%" >nul 2>nul
goto :sair

:sem_integrada
echo ABT: "%ABT_MANUT%" so existe na instalacao integrada ^(tools/instalar.ps1^). 1>&2
set "ABT_RC=2"
goto :sair

:sair
if defined ABT_CHCP chcp %ABT_CHCP% >nul 2>nul
endlocal & exit /b %ABT_RC%
