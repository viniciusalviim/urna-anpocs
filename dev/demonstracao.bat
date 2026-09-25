@echo off
rem Abre a urna e o painel ao mesmo tempo, cada um numa janela preta,
rem e depois as duas abas do navegador.
rem   urna:   http://127.0.0.1:8001
rem   painel: http://127.0.0.1:8002
rem Para parar: feche as duas janelas pretas.

cd /d "%~dp0.."

start "URNA - feche esta janela para parar a urna" Rscript -e "shiny::runApp('urna', port = 8001, launch.browser = FALSE)"
start "PAINEL - feche esta janela para parar o painel" Rscript -e "shiny::runApp('painel', port = 8002, launch.browser = FALSE)"

echo Esperando a urna e o painel ficarem prontos...
timeout /t 10 /nobreak >nul

start "" http://127.0.0.1:8001
start "" http://127.0.0.1:8002
