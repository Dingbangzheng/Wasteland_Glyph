@echo off
REM ---------------------------------------------------------------------------
REM  Wasteland Glyph / 废土字符 -- one-click launcher
REM
REM  Starts a local server in its own window, waits for it to listen, then joins
REM  with the client. Closing the client window leaves the server running; run
REM  stop.bat (or close the server window) to end it.
REM ---------------------------------------------------------------------------
setlocal
set PORT=17777
set SEED=20261011
set DATA=%~dp0data
set BIN=%~dp0build\bin

if not exist "%BIN%\wasteland_glyph.exe" (
    echo [play] the client is not built. Run these first:
    echo        cmake -S . -B build
    echo        cmake --build build
    pause
    exit /b 1
)
if not exist "%BIN%\wasteland_glyph_server.exe" (
    echo [play] the server is not built. Run these first:
    echo        cmake -S . -B build
    echo        cmake --build build
    pause
    exit /b 1
)

echo [play] starting the server on port %PORT% (seed %SEED%) ...
start "Wasteland Glyph - server" "%BIN%\wasteland_glyph_server.exe" --port %PORT% --seed %SEED% --data "%DATA%"

REM The server loads its data and opens the socket in well under a second, but a
REM fixed wait is more honest than guessing at a ready signal that does not exist.
timeout /t 3 /nobreak >nul

echo [play] joining as 'wanderer' ...
"%BIN%\wasteland_glyph.exe" --connect 127.0.0.1 --port %PORT% --user wanderer --password wasteland --data "%DATA%"

echo.
echo [play] client closed. The server window is still open -- close it to stop the world.
endlocal
