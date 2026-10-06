.pragma library

// All Docker knowledge lives here: the shell commands, the output parser
// and the error classification. No QML types, so it is easy to test.

var SEPARATOR = "---IPS---";
var ACTIVE_STATES = ["running", "paused", "restarting"];
var ID_PATTERN = /^[a-f0-9]{12,64}$/;

var PERMISSION_FIX = "sudo usermod -aG docker $USER";
var START_SERVICE = "pkexec systemctl start docker";
var INSTALL_GUIDE = "https://docs.docker.com/engine/install/";
var EXAMPLE_RUN = "docker run -d -p 8080:80 nginx";

// One shell call per refresh:
//   1. exit 127 if the docker binary is missing
//   2. one JSON object per container
//   3. "<id> <ip> <ip>..." for running containers (best effort, never fails)
function listCommand() {
    return "command -v docker >/dev/null 2>&1 || exit 127; "
        + "LC_ALL=C docker ps -a --no-trunc --format '{{json .}}' || exit $?; "
        + "echo '" + SEPARATOR + "'; "
        + "(docker ps -q --no-trunc | xargs -r docker inspect -f "
        + "'{{.Id}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}') 2>/dev/null || true";
}

// Returns "" for anything that is not a known action on a valid container ID,
// so nothing user-controlled is ever interpolated into the shell.
function actionCommand(action, id) {
    if (["start", "stop", "restart"].indexOf(action) === -1) {
        return "";
    }
    if (!ID_PATTERN.test(id)) {
        return "";
    }
    return "LC_ALL=C docker " + action + " " + id;
}

// ready | notInstalled | noPermission | daemonDown | error
// Order matters: without the binary there is no stderr to match.
function classify(exitCode, stderr) {
    var err = (stderr || "").toLowerCase();
    if (exitCode === 127) {
        return "notInstalled";
    }
    if (err.indexOf("permission denied") !== -1) {
        return "noPermission";
    }
    if (err.indexOf("cannot connect to the docker daemon") !== -1
            || err.indexOf("is the docker daemon running") !== -1) {
        return "daemonDown";
    }
    if (exitCode !== 0) {
        return "error";
    }
    return "ready";
}

// "0.0.0.0:8080->80/tcp, :::8080->80/tcp, 127.0.0.1:80-81->80-81/tcp, 3306/tcp" -> "80,81,8080"
// Returned as a comma-separated string because ListModel roles cannot hold arrays.
// Ranges are expanded, up to MAX_RANGE ports so a huge range cannot flood the row.
var MAX_RANGE = 10;
function hostPorts(portsText) {
    var seen = {};
    var ports = [];
    var re = /:(\d+)(?:-(\d+))?->/g;
    var m;
    while ((m = re.exec(portsText || "")) !== null) {
        var first = Number(m[1]);
        var last = m[2] ? Math.min(Number(m[2]), first + MAX_RANGE - 1) : first;
        for (var p = first; p <= last; p++) {
            if (!seen[p]) {
                seen[p] = true;
                ports.push(p);
            }
        }
    }
    ports.sort(function (a, b) { return a - b; });
    return ports.join(",");
}

// Untagged images show as "sha256:<64 hex>"; keep the 12-char short ID like `docker ps`.
function shortImage(image) {
    var m = /^sha256:([a-f0-9]{12})[a-f0-9]*$/.exec(image || "");
    return m ? m[1] : (image || "");
}

// Opens the user's terminal (Konsole unless another one is set in System Settings)
// running `docker logs` or a shell inside the container. Detached with setsid so
// the widget does not wait for the terminal to close. "" for an invalid ID.
function terminalCommand(kind, id) {
    if (!ID_PATTERN.test(id)) {
        return "";
    }
    var inner;
    if (kind === "logs") {
        inner = "docker logs -f --tail 200 " + id;
    } else if (kind === "shell") {
        inner = "docker exec -it " + id + " sh -c \"command -v bash >/dev/null && exec bash || exec sh\"";
    } else {
        return "";
    }
    // Keep the window open after the command ends so errors stay readable
    var script = inner + "; echo; echo '[exited, press Enter to close]'; read _";
    return "t=$(kreadconfig6 --group General --key TerminalApplication 2>/dev/null); "
        + "setsid -f ${t:-konsole} -e sh -c '" + script.replace(/'/g, "'\\''") + "' >/dev/null 2>&1";
}

// Dot shown before the name:
//   ok (running, healthy or no healthcheck) | starting (health check pending, restarting, paused)
//   unhealthy | stopped (exit 0, created) | failed (stopped with a non-zero exit code, dead)
function health(state, statusText) {
    var status = (statusText || "").toLowerCase();
    if (state === "running") {
        if (status.indexOf("(unhealthy)") !== -1) {
            return "unhealthy";
        }
        if (status.indexOf("health: starting") !== -1) {
            return "starting";
        }
        return "ok";
    }
    if (state === "restarting" || state === "paused") {
        return "starting";
    }
    if (state === "dead") {
        return "failed";
    }
    var exit = /exited \((\d+)\)/.exec(status);
    return exit && exit[1] !== "0" ? "failed" : "stopped";
}

// --- Desktop notifications --------------------------------------------------

// Exit codes that mean "asked to stop" (Ctrl+C, SIGTERM), not a crash
var CLEAN_EXIT_CODES = ["0", "130", "143"];

// What notifications compare between two refreshes: cid -> {name, isActive, health, status}
function snapshot(list) {
    var map = {};
    list.forEach(function (c) {
        map[c.cid] = { name: c.cname, isActive: c.isActive, health: c.health, status: c.statusText };
    });
    return map;
}

// Changes since the previous refresh that are worth a notification:
//   crashed:   was running, now stopped with an error exit code (or dead)
//   unhealthy: health check started failing
// Containers listed in `ignore` (ids the user just acted on) are skipped.
function containerEvents(prev, list, ignore) {
    var events = [];
    list.forEach(function (c) {
        var p = prev[c.cid];
        if (!p || (ignore && ignore[c.cid])) {
            return;
        }
        if (p.isActive && !c.isActive && c.health === "failed") {
            var exit = /exited \((\d+)\)/i.exec(c.statusText || "");
            if (!exit || CLEAN_EXIT_CODES.indexOf(exit[1]) === -1) {
                events.push({ kind: "crashed", cid: c.cid, name: c.cname, status: c.statusText });
            }
        } else if (c.health === "unhealthy" && p.health !== "unhealthy") {
            events.push({ kind: "unhealthy", cid: c.cid, name: c.cname, status: c.statusText });
        }
    });
    return events;
}

// Case-insensitive match of the search text against name, image, ports and IP.
function matches(c, query) {
    var q = (query || "").trim().toLowerCase();
    if (!q) {
        return true;
    }
    return [c.cname, c.image, c.ports, c.ip].some(function (field) {
        return (field || "").toLowerCase().indexOf(q) !== -1;
    });
}

function parse(stdout) {
    var parts = (stdout || "").split(SEPARATOR);

    var ips = {};
    (parts[1] || "").split("\n").forEach(function (line) {
        var tokens = line.trim().split(/\s+/);
        if (tokens[0]) {
            ips[tokens[0]] = tokens.slice(1).join(", ");
        }
    });

    var list = [];
    parts[0].split("\n").forEach(function (line) {
        line = line.trim();
        if (!line) {
            return;
        }
        var c;
        try {
            c = JSON.parse(line);
        } catch (e) {
            return;
        }
        var active = ACTIVE_STATES.indexOf(c.State) !== -1;
        list.push({
            cid: c.ID,
            cname: c.Names,
            image: shortImage(c.Image),
            statusText: c.Status,
            health: health(c.State, c.Status),
            isActive: active,
            group: active ? "active" : "inactive",
            ports: active ? hostPorts(c.Ports) : "",
            ip: ips[c.ID] || "",
            busy: false,
            errorText: ""
        });
    });

    list.sort(function (a, b) {
        if (a.isActive !== b.isActive) {
            return a.isActive ? -1 : 1;
        }
        return a.cname.localeCompare(b.cname);
    });
    return list;
}
