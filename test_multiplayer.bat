@echo off
echo ================================
echo Testing Heroes of Castlevania Multiplayer
echo ================================
echo.

REM Шлях до Godot executable
set GODOT_PATH=E:\Godot\Godot_v4.4.1-stable_win64.exe
set PROJECT_PATH=%~dp0heroes-of-castlevania

echo Starting HOST (first window)...
start "HeroesOfCastlevania - HOST" "%GODOT_PATH%" "%PROJECT_PATH%"

timeout /t 3 /nobreak

echo Starting CLIENT (second window)...
start "HeroesOfCastlevania - CLIENT" "%GODOT_PATH%" "%PROJECT_PATH%"

echo.
echo ================================
echo Both instances started!
echo.
echo In HOST window: Click "Create Game"
echo In CLIENT window: Click "Join" and connect to 127.0.0.1:7777
echo ================================
pause
