@echo off
setlocal
REM ============================================================
REM Docker + WSL2 removal script for Windows 11
REM ------------------------------------------------------------
REM What this script does:
REM 1. Stops Docker Desktop and shuts down WSL
REM 2. Removes Docker images, containers, networks and build cache
REM 3. Uninstalls Docker Desktop
REM 4. Uninstalls WSL
REM 5. Optionally reboots the system
REM
REM Notes:
REM - Run this script as Administrator
REM - Removing WSL will also remove Docker WSL distributions
REM - All Docker images, containers, caches and volumes may be lost
REM ============================================================

REM ============================================================
REM Stop Docker Desktop and shut down all WSL instances
REM ------------------------------------------------------------
REM This ensures that Docker files are not locked and WSL is
REM fully stopped before cleanup and uninstall steps.
REM ============================================================
docker desktop stop --force
wsl --shutdown

REM ============================================================
REM Remove Docker runtime data
REM ------------------------------------------------------------
REM This deletes:
REM - stopped containers
REM - unused images
REM - unused networks
REM - build cache
REM
REM Important:
REM This does NOT always guarantee full removal of every Docker
REM volume or WSL-backed storage, but it cleans most local data.
REM ============================================================
docker system prune -a -f


REM ============================================================
REM Uninstall Docker Desktop
REM ------------------------------------------------------------
REM Docker Desktop is removed via winget in silent mode.
REM ============================================================
winget uninstall -e --silent --disable-interactivity --id Docker.DockerDesktop


REM ============================================================
REM Uninstall WSL
REM ------------------------------------------------------------
REM This removes the Windows Subsystem for Linux from the system.
REM Any remaining WSL distributions may also be removed.
REM Use this only if WSL is no longer needed for other projects.
REM ============================================================
wsl --uninstall


REM ============================================================
REM Offer reboot
REM ------------------------------------------------------------
REM Reboot is recommended to fully unload virtualization
REM components and complete Docker/WSL removal.
REM ============================================================
choice /m "Reboot system?"
if errorlevel 2 goto rebootend
if errorlevel 1 goto rebootyes

:rebootyes
echo Rebooting system...
shutdown /r /t 0
goto rebootend

:rebootend
