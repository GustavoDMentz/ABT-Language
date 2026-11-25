@echo off
rem Abre a IDE da ABT. Requer Python 3.8+ (https://www.python.org) e a ABT instalada.
cd /d "%~dp0.."
where py >/dev/null 2>nul
if %errorlevel%==0 (
    py -3 ide\abt_ide.py
    goto fim
)
where python >/dev/null 2>nul
if %errorlevel%==0 (
    python ide\abt_ide.py
    goto fim
)
echo Python nao encontrado. Instale em https://www.python.org/downloads/ e marque "Add python.exe to PATH".
:fim
pause
