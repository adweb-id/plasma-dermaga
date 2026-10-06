import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

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
            if (next === "ready") {
                lastList = Docker.parse(stdout);
                syncModel(lastList);
                errorText = "";
            } else {
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

        const shown = list.filter(c => Docker.matches(c, searchText));
        const active = shown.filter(c => c.isActive);
        const inactive = shown.filter(c => !c.isActive);
        activeShown = active.length;
        inactiveShown = inactive.length;
        syncInto(activeModel, active);
        syncInto(inactiveModel, inactive);
    }

    onSearchTextChanged: syncModel(lastList)

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
        exec(Docker.START_SERVICE, () => refresh());
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
