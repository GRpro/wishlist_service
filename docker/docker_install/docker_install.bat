@echo off
setlocal
REM ============================================================
REM Docker + WSL2 installation script for Windows 11
REM ------------------------------------------------------------
REM What this script does:
REM 1. Updates WSL and forces WSL2 as the default version
REM 2. Installs Docker Desktop via winget
REM 3. Stops Docker Desktop and shuts down WSL
REM 4. Disables Docker autostart for the current user
REM 5. Copies predefined .wslconfig into the user's profile
REM 6. Optionally reboots the system so all settings apply cleanly
REM
REM Notes:
REM - Run this script as Administrator
REM - The .wslconfig file must be located in the same folder as this script
REM - Docker Desktop will use WSL2 backend
REM ============================================================

REM Update WSL runtime to the latest available version
wsl.exe --update

REM Force WSL2 as the default architecture for future distributions
wsl.exe --set-default-version 2


REM ============================================================
REM Install Docker Desktop
REM ------------------------------------------------------------
REM Docker Desktop is installed through winget.
REM Package/source agreements are accepted automatically.
REM Silent mode is used to avoid interactive installer dialogs.
REM ============================================================
winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent


REM ============================================================
REM Stop Docker Desktop and fully shut down WSL
REM ------------------------------------------------------------
REM This is needed before replacing .wslconfig so that
REM WSL restarts later with the new resource settings.
REM ============================================================
docker desktop stop --force
wsl --shutdown


REM ============================================================
REM Disable Docker Desktop autorun for the current user
REM ------------------------------------------------------------
REM Docker should not start automatically with Windows,
REM so it does not consume RAM when not needed.
REM ============================================================
reg delete HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v "Docker Desktop" /f


REM ============================================================
REM Copy project-specific .wslconfig into the current user's profile
REM ------------------------------------------------------------
REM %USERPROFILE% usually resolves to:
REM C:\Users\<current_user>
REM
REM This file defines WSL2 limits such as:
REM - memory
REM - processors
REM - swap
REM - autoMemoryReclaim
REM ============================================================
copy /y ".wslconfig" "%USERPROFILE%\.wslconfig"


REM ============================================================
REM Offer reboot
REM ------------------------------------------------------------
REM Reboot is recommended so Docker/WSL and system components
REM start with the new configuration from a clean state.
REM ============================================================
choice /m "Reboot system?"
if errorlevel 2 goto rebootend
if errorlevel 1 goto rebootyes

:rebootyes
echo Rebooting system...
shutdown /r /t 0
goto rebootend

:rebootend
