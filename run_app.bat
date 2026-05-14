@echo off
title IvCaptions Launcher
echo ===================================================
echo               IvCaptions App Launcher              
echo ===================================================
echo.

echo [1/2] Spoustim Backend (FastAPI na portu 8000)...
start "IvCaptions Backend" cmd /k "cd backend && venv\Scripts\activate && python main.py"

echo [2/2] Spoustim Frontend (Flutter - Windows)...
start "IvCaptions Frontend" cmd /k "cd frontend && flutter run -d windows"

echo.
echo ===================================================
echo Obe casti byly spusteny v novych oknech.
echo Pro ukonceni staci zavrit prislusna okna konzole.
echo ===================================================
pause
