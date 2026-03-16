@echo off
setlocal

REM Stop Docker Desktop
docker desktop stop --force

REM Shutdown WSL to release RAM used by the Docker VM
wsl --shutdown