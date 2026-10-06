# Dermaga – Docker Containers

A KDE Plasma 6 widget that shows your Docker containers in the panel. Start, stop,
restart, read logs or open a shell without going to the terminal first.

*Dermaga* is Indonesian for "pier", where containers dock.

- Pure QML + JavaScript, nothing to compile
- Follows your Plasma theme (light and dark, Wayland and X11)
- Talks to the `docker` CLI only; no extra services, no root (except to start the Docker service, via `pkexec`)

## Features

- **Panel icon with a badge** showing how many containers are running, or `!` when Docker cannot be used.
- **Running and Stopped tabs**, each with its count.
- **Compact rows** (one or two lines) with name, status, image, published ports and IP.
- **Click to act**: a port opens `http://localhost:<port>` in your browser; the name or the IP copies to the clipboard.
- **Start, stop and restart** buttons on every row.
- **Right-click menu**: show logs, open a shell, copy name / ID / IP, start / stop / restart.
- **Health at a glance**: the status dot shows healthy, starting, unhealthy or failed containers.
- **Search** across name, image, port and IP, in both tabs.
- **Helpful empty and error screens** that explain what is wrong and offer the fix.
- **Settings** for the refresh interval and which details each row shows.

## Requirements

- KDE Plasma 6.0 or newer
- Docker Engine with the `docker` CLI, managed by systemd
- Your user in the `docker` group (the widget tells you how if not)
- Optional: Konsole or another terminal for logs and shell

Docker Desktop, rootless Docker and Podman are not tested yet.

## Install

**From the KDE Store**: right-click the panel, choose *Add Widgets…*, then
*Get New Widgets…* → *Download New Plasma Widgets*, and search for "Dermaga".

**From a release file**: download `dermaga-<version>.plasmoid`, then

    kpackagetool6 -t Plasma/Applet -i dermaga-<version>.plasmoid

**From source**:

    git clone https://github.com/adweb-id/plasma-dermaga.git
    cd plasma-dermaga
    kpackagetool6 -t Plasma/Applet -i .

Installing only makes the widget available. To show it, right-click the panel,
choose *Add Widgets…* and drag **Dermaga** onto the panel.

Update or remove:

    kpackagetool6 -t Plasma/Applet -u .
    kpackagetool6 -t Plasma/Applet -r com.adweb.dermaga

After an update, restart Plasma to load the new code:

    kquitapp6 plasmashell && kstart plasmashell

## Using the widget

### Panel icon

| Badge | Meaning |
| --- | --- |
| Number | Running containers. Hidden when none are running. |
| `!` | Docker cannot be used: not installed, no permission, or the service is stopped. Hover for the reason, click for the fix. |

Hover the icon for a summary such as "6 running · 35 stopped".

### The container row

With all details turned on, each container takes two lines:

    ● rw_db                          Up 28 hours    ⟳  ■
      mariadb:10.4.13       :32002   172.23.0.3

When the image is hidden in the settings, ports and IP move up and the row
becomes a single line:

    ● rw_db         :32002  172.23.0.3   Up 28 hours    ⟳  ■

Untagged images (`sha256:…`) are shortened to the 12-character ID, as `docker ps` does.
Long names are cut with "…" only when the row is too narrow; there is no fixed limit.

| Click on | Does |
| --- | --- |
| Name | Copies the container name. It turns green briefly to confirm. |
| `:port` | Opens `http://localhost:<port>` in your default browser. |
| IP | Copies the IP address. It turns green briefly to confirm. |
| ⟳ / ■ / ▶ | Restart, stop or start. A spinner shows while Docker works; errors appear under the row. |
| Anywhere, right button | Opens the menu below. |

Port ranges such as `80-81->80-81/tcp` are shown as separate ports (up to 10 per range).

### Status dot

Hover the dot to see what it means.

| Dot | Meaning |
| --- | --- |
| Green, filled | Running (healthy, or no health check) |
| Orange, filled | Health check still starting, restarting, or paused |
| Red, filled | Running, but the health check fails |
| Grey ring | Stopped normally (exit code 0, or created but never started) |
| Red ring | Stopped with an error (non-zero exit code, or dead) |

### Right-click menu

| Item | What it runs |
| --- | --- |
| Show logs | Opens a terminal with `docker logs -f --tail 200 <id>` |
| Open shell | Running containers only: opens a terminal with `docker exec -it <id>`, using `bash` when available, otherwise `sh` |
| Copy name / Copy ID / Copy IP address | Copies to the clipboard (ID is the short 12-character form) |
| Restart / Stop / Start | Same as the row buttons |

The terminal is the one set in *System Settings → Default Applications → Terminal
Emulator*, or Konsole if none is set. The window stays open after the command
ends, so error messages remain readable; press Enter to close it.

### Search

The search field sits at the top of the popup and has focus as soon as the
popup opens, so you can just type.

- Matches the name, image, port and IP, ignoring case: `maria`, `3200` and `23.0.3` all find `rw_db`.
- Filters both tabs; the tab counts show the matches.
- `Esc` clears the search; a second `Esc` closes the popup.
- The search is cleared each time the popup closes.
- The panel badge and the header summary always count every container.

### Empty lists

When a tab has nothing to show, the popup explains why and offers the next step.

| Situation | Message | Button |
| --- | --- | --- |
| No containers on this machine | "No containers yet", with an example `docker run` command | Copy command |
| Running tab empty | "N stopped containers are ready to start." | Show stopped containers |
| Stopped tab turned off in settings | "N stopped containers are hidden by the settings." | Show stopped containers (turns the tab back on) |
| Stopped tab empty | "All N containers are running." | none |
| Search finds nothing in this tab, but in the other | "Nothing running matches "x", but N stopped containers do." | Show stopped (or running) matches |
| Search finds nothing at all | "No container name, image, port or IP contains "x"." | Clear search |

### When Docker cannot be used

Instead of an empty list, the popup shows the cause and one button that fixes it.
The checks run in this order on every refresh:

| Problem | How it is detected | Fix offered |
| --- | --- | --- |
| Docker is not installed | The `docker` command is missing (exit code 127) | *Open install guide* (docs.docker.com) |
| No permission | Docker answers "permission denied" | *Copy command* `sudo usermod -aG docker $USER`; then log out and back in |
| Docker service is stopped | Docker answers "Cannot connect to the Docker daemon" | *Start Docker*: runs `pkexec systemctl start docker` (asks for your password) |
| Any other error | Docker exits with an error | Shows Docker's message and a *Try again* button |

## Settings

Right-click the widget → *Configure Dermaga…*

| Setting | Default | Notes |
| --- | --- | --- |
| Refresh interval (seconds) | 5 | How often the list refreshes while the popup is open (2–60). When closed, the badge refreshes once a minute. |
| Show stopped containers | on | Turns the Stopped tab on or off |
| Show in each row: Image | on | Turning it off makes rows one line |
| Show in each row: Status | on | Uptime or exit code, e.g. "Up 2 hours", "Exited (0) 3 days ago" |
| Show in each row: Published ports | on | Running containers only |
| Show in each row: IP address | on | Running containers only |

## How it works

Every refresh is one shell call that runs:

    command -v docker || exit 127
    docker ps -a --no-trunc --format '{{json .}}'
    docker ps -q --no-trunc | xargs -r docker inspect -f '{{.Id}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'

A new refresh never starts before the previous one finishes, and nothing polls
faster than once a minute while the popup is closed.

Security:

- Only container IDs that match `^[a-f0-9]{12,64}$` are ever put into a command. Names and other text from Docker never reach the shell.
- Root is used only to start the Docker service, through `pkexec`, after you confirm.

## Troubleshooting

- **The widget is not in the panel after installing.** Installing only registers it; add it with *Add Widgets…*.
- **Changes do not show after updating.** Restart Plasma: `kquitapp6 plasmashell && kstart plasmashell`.
- **"No permission" right after `usermod`.** Group changes apply after you log out and back in.
- **Show logs / Open shell does nothing.** Make sure Konsole is installed, or set a terminal in *System Settings → Default Applications*.
- **Test without touching your panel:** `plasmoidviewer -a .` (from the `plasma-sdk` package) or `plasmawindowed com.adweb.dermaga`.

## Development

    contents/ui/main.qml                  state, timer, command execution, search filter
    contents/ui/docker.js                 commands, parser, error and health detection
    contents/ui/CompactRepresentation.qml panel icon + badge
    contents/ui/FullRepresentation.qml    popup: header, search, tabs, list
    contents/ui/ContainerDelegate.qml     one container row and its right-click menu
    contents/ui/EmptyView.qml             empty list: why it is empty and what to do next
    contents/ui/WarningView.qml           not installed / no permission / service stopped
    contents/ui/configGeneral.qml         settings page
    contents/config/main.xml              settings schema
    contents/icons/dermaga-symbolic.svg   panel icon (one colour, follows the theme)
    contents/images/empty.svg             empty-list illustration (one colour, follows the theme)
    store-icon.svg                        colour logo for the store listing (not part of the package)

`docker.js` has no QML dependencies, so its parser can be tested with plain Node.js.

Build a release file:

    zip -r dermaga-<version>.plasmoid metadata.json contents

Before a release, raise `Version` in `metadata.json`. `Icon` there (shown in the
widget picker) must be a theme icon name, so it stays `server-database`; the panel
uses `contents/icons/dermaga-symbolic.svg`.

## Contributing

Bug reports and pull requests are welcome at
<https://github.com/adweb-id/plasma-dermaga/issues>.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
