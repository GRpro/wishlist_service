@echo off
setlocal

REM Start Docker Desktop.
REM If Docker is already running this command does nothing.
REM If Docker is stopped it will start the Docker Desktop service.
docker desktop start