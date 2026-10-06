# KDE Store listing

Text and files for the product page on store.kde.org. Copy each field as is.

## Basics

| Field | Value |
| --- | --- |
| Title | Dermaga – Docker Containers |
| Category | Plasma 6 Widgets |
| License | GPL-3.0-or-later |
| Source / Homepage | https://github.com/adweb-id/plasma-dermaga |
| Tags | docker, containers, devops, developer, plasma6, widget, plasmoid |
| Logo | `docs/store/logo-512.png` |
| File | `dermaga-<version>.plasmoid` from the GitHub release |

## Screenshots (in this order)

1. `docs/screenshots/running.png`
2. `docs/screenshots/menu.png`
3. `docs/screenshots/stopped.png`
4. `docs/screenshots/service-stopped.png`
5. `docs/screenshots/settings.png`

## Summary (one line)

Your Docker containers in the Plasma panel: start, stop, restart, logs and shell in one click.

## Description

Dermaga shows your Docker containers right in the Plasma panel. Check what is running, open a port in the browser, read logs or restart a service without going to the terminal first.

Features
- Panel icon with the number of running containers, or "!" when Docker cannot be used
- Running and Stopped tabs with compact one- or two-line rows: name, status, image, ports, IP
- Start, stop and restart from each row, with a "Stop?" confirmation you can turn off
- Click a port to open http://localhost:<port>; click the name or IP to copy it
- Right-click a container: show logs, open a shell, pin to top, copy name / ID / IP
- Status dot shows healthy, starting, unhealthy and crashed containers
- CPU and memory of a container while the pointer rests on it
- Search by name, image, port or IP; works from the keyboard
- Desktop notifications when the Docker service stops or a container crashes or turns unhealthy
- Clear screens when Docker is not installed, you lack permission, or the service is stopped, each with the fix (Start Docker, copy the usermod command, install guide)
- Choose which details each row shows
- Follows your Plasma theme; English and Indonesian

Requirements
- Plasma 6.0 or newer
- Docker Engine with the docker command
- Your user in the docker group (Dermaga shows how if not)
- Konsole or another terminal for logs and shell

Pure QML and JavaScript: nothing to compile, no background service. Dermaga only calls the docker command; it never passes container names to the shell, and asks for your password (pkexec) only to start the Docker service.

After installing, right-click the panel, choose "Add Widgets…" and drag Dermaga onto the panel.

Bugs and ideas: https://github.com/adweb-id/plasma-dermaga/issues

## Changelog for 0.2.0

- Desktop notifications for the Docker service and for crashed or unhealthy containers
- Confirmation before Stop and Restart (on by default)
- Pin containers to the top of their tab
- CPU and memory while the pointer rests on a container
- Keyboard navigation
- "Show stopped containers" toggle in the panel icon's right-click menu
- Indonesian translation
- Fixed: the "No containers yet" illustration showed a generic document icon
