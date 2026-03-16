## Docker Installation with Scripts

The project provides helper scripts to simplify Docker and WSL2 setup.

### docker_install.bat
Installs **WSL2** and **Docker Desktop**, then applies the initial configuration.

The script also:
- updates WSL
- installs Docker Desktop
- disables Docker autostart
- copies the project `.wslconfig` file to `%USERPROFILE%`

### docker_uninstall.bat
Removes **Docker Desktop** and optionally removes **WSL2** and related data.

The script can also clean Docker images and containers before removal.


### .wslconfig
The `.wslconfig` file is copied to "%USERPROFILE%\.wslconfig"

It defines WSL2 virtual machine settings such as:
- memory limits
- CPU allocation
- swap configuration
- memory reclaim behavior

## Docker Install

### Install WSL2
Install the Windows Subsystem for Linux (WSL2) and reboot the system afterwards:
```
wsl.exe --update
wsl.exe --set-default-version 2
```

This installs the WSL2 subsystem without any Linux distribution.

You do **not need to install a Linux distribution** for this project because Docker Desktop uses its own internal WSL distributions (`docker-desktop` and `docker-desktop-data`).  
However, you may install a distribution manually if you need a Linux environment for development or debugging.

Check the installed WSL version:
```
wsl --version
```

### Install Docker

Docker Desktop can be installed in two ways.

#### Option 1 — Install Docker from the official website

Download and install Docker Desktop silently:
```
curl -L -o docker-desktop-installer.exe https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
docker-desktop-installer.exe install --quiet --accept-license --backend=wsl-2
del docker-desktop-installer.exe
```

This installs Docker Desktop using the WSL2 backend.

#### Option 2 — Install Docker via Microsoft Store (winget)
Docker Desktop can also be installed using `winget`:

```
winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
```

### Post-installation checks
Verify that Docker is installed correctly:

```
docker --version
```

### Disable Docker autostart
By default Docker Desktop may start automatically with Windows. For development environments this is often unnecessary and consumes memory.

You can disable autostart with:

```
reg delete HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v "Docker Desktop" /f
```

Docker can still be started manually when needed.

### Verify Docker environment

Check that Docker and WSL are working correctly:
```
docker --version
docker ps
wsl -l -v
```

## Docker Uninstall

### Stop Docker and WSL
Before uninstalling Docker it is recommended to stop Docker Desktop and shut down WSL.

```
docker desktop stop --force
wsl --shutdown
```

### Clean Docker images

Remove all unused Docker images, containers, networks and build cache:
```
docker system prune -a -f
```

### Uninstall Docker

Docker Desktop can be removed in two ways.

#### Option 1 — Uninstall Docker using the installer

If you still have the installer available, Docker Desktop can be removed with:
```
docker-desktop-installer.exe uninstall --quiet
```

#### Option 2 — Uninstall Docker using Microsoft Store (winget)

Docker Desktop can also be removed using `winget`:

```
winget uninstall -e --silent --disable-interactivity --id Docker.DockerDesktop
```

### Uninstall WSL

#### Remove installed distributions

If any Linux distributions were installed manually, they should be removed first.

List installed distributions:
```
wsl --list --all
```

Remove a distribution:
```
wsl --unregister <DistributionName>
```

Automating removal of all distributions is possible but **not recommended**, since other projects may depend on them.

#### Uninstall the WSL service

Finally, uninstall the Windows Subsystem for Linux:

```
wsl --uninstall
```

## Docker / WSL2 Setup and Configuration

### Apply WSL configuration

Copy the prepared `.wslconfig` file into the user profile directory:
```
copy /y .wslconfig %USERPROFILE%\.wslconfig
```

This file configures the WSL2 virtual machine limits such as:
- memory usage
- CPU threads
- swap
- memory reclaim behavior

After updating the configuration it is recommended to restart WSL:

```
wsl --shutdown
```

### Stop Docker and WSL

Docker Desktop and the WSL virtual machine can be stopped with:

```
docker desktop stop --force
wsl --shutdown
```

This completely shuts down the Docker environment and releases the RAM used by WSL.

### Start Docker

Docker Desktop can be started manually with:

```
docker desktop start
```

