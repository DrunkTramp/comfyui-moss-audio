@echo off
setlocal enabledelayedexpansion

REM install.bat — One-command setup for comfyui-moss-audio (Windows)
REM Run from ComfyUI\ directory or set COMFY_ROOT

if "%COMFY_ROOT%"=="" set "COMFY_ROOT=%CD%"
set "MOSS_DIR=%COMFY_ROOT%\models\moss-audio"
set "VENV=%MOSS_DIR%\venv"
set "USE_UV=false"

echo === comfyui-moss-audio installer ===
echo ComfyUI root: %COMFY_ROOT%
echo MOSS dir:     %MOSS_DIR%
echo.

REM ── 0. Find Python 3.11 (system or uv) ────────────────────────────

REM Try system Python first
python -c "import sys; exit(0 if sys.version_info.major==3 and sys.version_info.minor==11 else 1)" 2>nul
if not errorlevel 1 (
    echo Using system Python (3.11)
    goto :found_python
)

REM Try py -3 launcher
py -3 -c "import sys; exit(0 if sys.version_info.major==3 and sys.version_info.minor==11 else 1)" 2>nul
if not errorlevel 1 (
    echo Using system Python (3.11)
    goto :found_python
)

REM No system 3.11 — check for uv
where uv >nul 2>nul
if not errorlevel 1 (
    echo Python 3.11 not found on system, but uv is available.
    uv python list --only-installed 2>nul | findstr "3.11" >nul
    if errorlevel 1 (
        echo Installing Python 3.11 via uv...
        uv python install 3.11
    )
    set "USE_UV=true"
    echo Using uv-managed Python 3.11
    goto :found_python
)

REM No system 3.11, no uv — ask user
echo Python 3.11 not found on system.
echo uv can download and manage Python 3.11 automatically.
set /p choice="Download and install uv? (y/N): "
if /i "!choice!"=="y" (
    echo Installing uv...
    powershell -Command "& {[System.Net.ServicePointManager]::SecurityProtocol = 3072; Invoke-Expression (Invoke-WebRequest -Uri 'https://astral.sh/uv/install.ps1' -UseBasicParsing).Content}" <nul
    REM Add uv to PATH for this session
    set "PATH=%USERPROFILE%\.local\bin;%PATH%"
    where uv >nul 2>nul
    if not errorlevel 1 (
        echo uv installed. Installing Python 3.11...
        uv python install 3.11
        set "USE_UV=true"
        echo Using uv-managed Python 3.11
        goto :found_python
    ) else (
        echo ERROR: uv installation failed. Install Python 3.11 manually.
        echo   See: https://astral.sh/uv/  or  https://python.org
        exit /b 1
    )
) else (
    echo ERROR: Python 3.11 is required. Install it manually or rerun with 'y' to auto-install.
    echo   https://astral.sh/uv/  or  https://python.org
    exit /b 1
)

:found_python

REM ── 1. Clone MOSS-Audio source ──────────────────────────────────────
if exist "%MOSS_DIR%\src\src\modeling_moss_audio.py" (
    echo [1/4] MOSS-Audio source already present, skipping clone.
) else (
    echo [1/4] Cloning MOSS-Audio source...
    if not exist "%MOSS_DIR%" mkdir "%MOSS_DIR%"
    git clone https://github.com/OpenMOSS/MOSS-Audio.git "%MOSS_DIR%\src"
    if errorlevel 1 (
        echo ERROR: Git clone failed. Is Git installed and in PATH?
        exit /b 1
    )
)

REM ── 2. Create standalone venv ───────────────────────────────────────
if exist "%VENV%\Scripts\python.exe" (
    echo [2/4] Standalone venv already exists, skipping.
) else (
    echo [2/4] Creating standalone venv (Python 3.11)...
    if "%USE_UV%"=="true" (
        uv venv --python 3.11 "%VENV%"
    ) else (
        python -m venv "%VENV%"
    )
    if errorlevel 1 (
        echo ERROR: Failed to create venv.
        exit /b 1
    )
)

REM ── 3. Install venv dependencies ────────────────────────────────────
echo [3/4] Installing dependencies in standalone venv...
if "%CUDA_VER%"=="" set "CUDA_VER=cu128"

"%VENV%\Scripts\python" -m pip install --quiet ^
    torch torchaudio torchcodec --index-url "https://download.pytorch.org/whl/%CUDA_VER%" ^
    "transformers==4.57.1" ^
    safetensors soundfile tiktoken einops scipy accelerate ^
    numpy

if errorlevel 1 (
    echo ERROR: pip install failed. Check CUDA version compatibility.
    exit /b 1
)

REM ── 4. Install caption CLI script ───────────────────────────────────
copy "%~dp0caption_cli.py" "%MOSS_DIR%\caption_cli.py" >nul 2>&1
if errorlevel 1 (
    echo [4/4] CLI script already in place.
) else (
    echo [4/4] CLI script installed.
)

echo.
echo === Setup complete ===
echo.
echo Next steps:
echo   1. Download a model:
echo      cd /d %MOSS_DIR%
echo      hf download OpenMOSS-Team/MOSS-Audio-4B-Instruct --local-dir MOSS-Audio-4B-Instruct
echo.
echo   2. Restart ComfyUI
echo.
echo   3. Add MOSS-Audio Model Loader + MOSS-Audio Caption nodes
echo.
echo See README.md for more details.

endlocal
