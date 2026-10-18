@echo off
REM ---------------------------------------------------------------------------
REM  Wasteland Glyph / 废土字符 -- one-click self-check
REM
REM  Answers the only question that matters after a change: is this still a
REM  working game? Runs the full test suite and then the twelve-player Beta gate
REM  over real sockets.
REM ---------------------------------------------------------------------------
setlocal
set BIN=%~dp0build\bin

if not exist "%BIN%\wasteland_glyph_server.exe" (
    echo [check] nothing built yet. Run these first:
    echo         cmake -S . -B build
    echo         cmake --build build
    pause
    exit /b 1
)

echo ============================================================
echo  1/2  unit + integration suite
echo ============================================================
ctest --test-dir "%~dp0build" --output-on-failure
if errorlevel 1 (
    echo.
    echo [check] SUITE FAILED. Do not trust anything below.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  2/2  Beta gate: 12 real clients, real sockets
echo ============================================================
"%BIN%\beta_load.exe"
if errorlevel 1 (
    echo.
    echo [check] BETA GATE FAILED. The suite passed but the network does not.
    pause
    exit /b 1
)

echo.
echo [check] both gates passed -- suite green, 12/12 players connected.
endlocal
