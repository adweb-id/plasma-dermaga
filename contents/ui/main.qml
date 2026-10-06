import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.notification

import "docker.js" as Docker

PlasmoidItem {
    id: root

    // loading | ready | notInstalled | noPermission | daemonDown | error
    property string dockerState: "loading"
    property string errorText: ""
    property int activeCount: 0
    property int inactiveCount: 0
    // Rows left in each tab after the search filter
    property int activeShown: 0
    property int inactiveShown: 0

    // Text typed in the popup's search field; filters both tabs
    property string searchText: ""
    // Last parsed list, so the filter can be re-applied without calling Docker
    property var lastList: []

    property bool refreshing: false
    property bool refreshQueued: false
    property var busyIds: ({})
    property var actionErrors: ({})

    // Text copied most recently; rows use it to show a short "Copied" confirmation
    property string lastCopied: ""

    // One model per tab
    readonly property alias activeModel: activeModel
    readonly property alias inactiveModel: inactiveModel
    readonly property bool showInactive: Plasmoid.configuration.showInactive
    // Ask before Stop and Restart
    readonly property bool confirmActions: Plasmoid.configuration.confirmActions
    // Names of containers pinned to the top of their tab (names survive re-creation, IDs do not)
    readonly property var pinnedNames: Plasmoid.configuration.pinned

    // Row details chosen in the settings
    readonly property bool showImage: Plasmoid.configuration.showImage
    readonly property bool showStatus: Plasmoid.configuration.showStatus
    readonly property bool showPorts: Plasmoid.configuration.showPorts
    readonly property bool showIp: Plasmoid.configuration.showIp
    readonly property bool hasWarning: dockerState !== "ready" && dockerState !== "loading"
    readonly property url iconSource: Qt.resolvedUrl("../icons/dermaga-symbolic.svg")
    readonly property string summaryText: {
        switch (dockerState) {
        case "loading": return i18n("Loading…");
        case "ready": return i18n("%1 running · %2 stopped", activeCount, inactiveCount);
        case "notInstalled": return i18n("Not installed");
        case "noPermission": return i18n("Permission denied");
        case "daemonDown": return i18n("Service stopped");
        default: return i18n("Error");
        }
    }

    Plasmoid.icon: iconSource
    toolTipMainText: i18n("Dermaga")
    toolTipSubText: summaryText

    // Extra entries in the widget's own right-click menu (next to "Configure Dermaga…")
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Show stopped containers")
            checkable: true
            checked: Plasmoid.configuration.showInactive
            onTriggered: Plasmoid.configuration.showInactive = checked
        }
    ]

    compactRepresentation: CompactRepresentation { widget: root }
    fullRepresentation: FullRepresentation { widget: root }

    ListModel {
        id: activeModel
    }

    ListModel {
        id: inactiveModel
    }

    // Runs a shell command and hands stdout, stderr and the exit code to a callback.
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})

        onNewData: (sourceName, data) => {
            const callback = callbacks[sourceName];
            delete callbacks[sourceName];
            disconnectSource(sourceName);
            if (callback) {
                callback(data["stdout"] || "", data["stderr"] || "", data["exit code"]);
            }
        }
    }

    function exec(command, callback) {
        if (executable.callbacks[command]) {
            return false; // same command already running
        }
        executable.callbacks[command] = callback;
        executable.connectSource(command);
        return true;
    }

    function refresh() {
        if (refreshing) {
            refreshQueued = true;
            return;
        }
        refreshing = true;
        exec(Docker.listCommand(), (stdout, stderr, exitCode) => {
            refreshing = false;
            const next = Docker.classify(exitCode, stderr);
            notifyDockerChange(dockerState, next, stderr.trim());
            if (next === "ready") {
                lastList = Docker.parse(stdout);
                notifyContainerChanges(lastList);
                syncModel(lastList);
                errorText = "";
            } else {
                containerSnapshot = null; // compare afresh once Docker is back
                lastList = [];
                activeModel.clear();
                inactiveModel.clear();
                activeCount = 0;
                inactiveCount = 0;
                activeShown = 0;
                inactiveShown = 0;
                errorText = stderr.trim();
            }
            dockerState = next;
            if (refreshQueued) {
                refreshQueued = false;
                refresh();
            }
        });
    }

    function syncModel(list) {
        activeCount = list.filter(c => c.isActive).length;
        inactiveCount = list.length - activeCount;

        // Pinned containers first, then by name
        const shown = list.filter(c => Docker.matches(c, searchText));
        for (const c of shown) {
            c.pinned = isPinned(c.cname);
        }
        shown.sort((a, b) => (a.pinned === b.pinned ? a.cname.localeCompare(b.cname) : (a.pinned ? -1 : 1)));
        const active = shown.filter(c => c.isActive);
        const inactive = shown.filter(c => !c.isActive);
        activeShown = active.length;
        inactiveShown = inactive.length;
        syncInto(activeModel, active);
        syncInto(inactiveModel, inactive);
    }

    onSearchTextChanged: syncModel(lastList)
    onPinnedNamesChanged: syncModel(lastList)

    function isPinned(name) {
        return pinnedNames.indexOf(name) !== -1;
    }

    function togglePin(name) {
        const names = pinnedNames.filter(n => n !== name);
        if (!isPinned(name)) {
            names.push(name);
        }
        Plasmoid.configuration.pinned = names;
    }

    // --- CPU and memory, fetched while the pointer rests on a running container ---

    // cid -> {cpu, mem, at}; statsRevision bumps so rows re-read it
    property var stats: ({})
    property int statsRevision: 0

    function fetchStats(id) {
        const cached = stats[id];
        if (cached && Date.now() - cached.at < 10000) {
            return;
        }
        const command = Docker.statsCommand(id);
        if (!command) {
            return;
        }
        exec(command, (stdout, stderr, exitCode) => {
            const value = exitCode === 0 ? Docker.parseStats(stdout) : null;
            if (value) {
                value.at = Date.now();
                stats[id] = value;
                statsRevision++;
            }
        });
    }

    // Updates rows in place so the list keeps its scroll position.
    function syncInto(model, list) {
        for (const item of list) {
            item.busy = !!busyIds[item.cid];
            item.errorText = actionErrors[item.cid] || "";
        }
        while (model.count > list.length) {
            model.remove(model.count - 1);
        }
        for (let i = 0; i < list.length; i++) {
            if (i < model.count) {
                model.set(i, list[i]);
            } else {
                model.append(list[i]);
            }
        }
    }

    function setRow(id, values) {
        for (const model of [activeModel, inactiveModel]) {
            for (let i = 0; i < model.count; i++) {
                if (model.get(i).cid === id) {
                    model.set(i, values);
                    return;
                }
            }
        }
    }

    // action: "start" | "stop" | "restart"
    function runAction(action, id) {
        const command = Docker.actionCommand(action, id);
        if (!command || busyIds[id]) {
            return;
        }
        busyIds[id] = true;
        actionErrors[id] = "";
        userActionAt[id] = Date.now(); // the user did this, so no "stopped" notification
        setRow(id, { busy: true, errorText: "" });

        exec(command, (stdout, stderr, exitCode) => {
            delete busyIds[id];
            actionErrors[id] = exitCode === 0 ? "" : stderr.trim();
            setRow(id, { busy: false, errorText: actionErrors[id] });
            refresh();
        });
    }

    // kind: "logs" | "shell"; opens a terminal window, nothing to wait for
    function openTerminal(kind, id) {
        const command = Docker.terminalCommand(kind, id);
        if (command) {
            exec(command, () => {});
        }
    }

    function startService() {
        serviceStartedAt = Date.now();
        exec(Docker.START_SERVICE, () => refresh());
    }

    // --- Desktop notifications ---------------------------------------------

    // Containers as seen on the previous refresh; null until there is one to compare with
    property var containerSnapshot: null
    // cid -> time the user started/stopped/restarted it from the widget
    property var userActionAt: ({})
    // Time the user pressed "Start Docker", to skip the redundant "running again" message
    property double serviceStartedAt: 0
    // Set once a "Docker unavailable" notification went out, so recovery is reported too
    property bool dockerDownNotified: false

    readonly property int quietPeriod: 60000 // ms after a user action

    function notifyDockerChange(previous, next, stderr) {
        if (!Plasmoid.configuration.notifyDocker) {
            return;
        }
        if (previous === "ready" && next !== "ready") {
            dockerDownNotified = true;
            if (next === "daemonDown") {
                notify(i18n("Docker service stopped"),
                       i18n("Containers cannot be listed until the Docker service runs again."),
                       "dialog-warning", i18n("Start Docker"), () => startService());
            } else {
                notify(i18n("Docker is unavailable"), stderr || summaryText, "dialog-warning");
            }
        } else if (previous !== "ready" && previous !== "loading" && next === "ready" && dockerDownNotified) {
            dockerDownNotified = false;
            if (Date.now() - serviceStartedAt > quietPeriod) {
                notify(i18n("Docker is running again"), "", "dialog-information");
            }
        }
    }

    function notifyContainerChanges(list) {
        const previous = containerSnapshot;
        containerSnapshot = Docker.snapshot(list);
        if (!previous || !Plasmoid.configuration.notifyContainers) {
            return;
        }
        const now = Date.now();
        const ignore = {};
        for (const id in userActionAt) {
            if (now - userActionAt[id] < quietPeriod) {
                ignore[id] = true;
            } else {
                delete userActionAt[id];
            }
        }
        const events = Docker.containerEvents(previous, list, ignore);
        for (const kind of ["crashed", "unhealthy"]) {
            const group = events.filter(e => e.kind === kind);
            if (group.length === 0) {
                continue;
            }
            // One notification per kind; with a single container it gets a "Show logs" button
            const one = group.length === 1 ? group[0] : null;
            const names = group.map(e => e.name).join(", ");
            if (kind === "crashed") {
                notify(one ? i18n("%1 stopped with an error", one.name)
                           : i18np("%1 container stopped with an error", "%1 containers stopped with an error", group.length),
                       one ? one.status : names,
                       "dialog-error",
                       one ? i18n("Show logs") : "", one ? () => openTerminal("logs", one.cid) : null);
            } else {
                notify(one ? i18n("%1 is unhealthy", one.name)
                           : i18np("%1 container is unhealthy", "%1 containers are unhealthy", group.length),
                       one ? i18n("Its health check is failing.") : names,
                       "dialog-warning",
                       one ? i18n("Show logs") : "", one ? () => openTerminal("logs", one.cid) : null);
            }
        }
    }

    // Sends one desktop notification, optionally with a single action button
    function notify(title, text, icon, actionLabel, onAction) {
        const n = notificationComponent.createObject(root, {
            title: title,
            text: text,
            iconName: icon
        });
        if (actionLabel && onAction) {
            const action = actionComponent.createObject(n, { label: actionLabel });
            action.activated.connect(onAction);
            n.actions = [action];
        }
        n.closed.connect(() => n.destroy());
        n.sendEvent();
    }

    Component {
        id: notificationComponent

        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            autoDelete: false // QML owns it; destroyed when closed
        }
    }

    Component {
        id: actionComponent

        NotificationAction {}
    }

    function openGuide() {
        Qt.openUrlExternally(Docker.INSTALL_GUIDE);
    }

    function copyPermissionFix() {
        copyText(Docker.PERMISSION_FIX);
    }

    function setShowInactive(show) {
        Plasmoid.configuration.showInactive = show;
    }

    function openPort(port) {
        Qt.openUrlExternally("http://localhost:" + port);
    }

    // QML has no clipboard API; a hidden TextEdit is the usual workaround.
    TextEdit {
        id: clipboardHelper
        visible: false
    }

    function copyText(text) {
        clipboardHelper.text = text;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        lastCopied = text;
        copiedReset.restart();
    }

    Timer {
        id: copiedReset
        interval: 1500
        onTriggered: root.lastCopied = ""
    }

    // Fast while the popup is open, once a minute otherwise (keeps the badge fresh).
    Timer {
        interval: root.expanded ? Plasmoid.configuration.refreshInterval * 1000 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onExpandedChanged: {
        if (root.expanded) {
            refresh();
        } else {
            searchText = ""; // start fresh next time the popup opens
        }
    }
}
