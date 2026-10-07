import QtQuick
import org.kde.plasma.plasmoid

// Only used by take.sh, never shipped: puts the popup into one scenario
// (tab, search, open menu, ...) because Wayland offers no input automation.
Item {
    id: driver

    required property var widget
    property string scenario: "@SCENARIO@"

    function find(item, name) {
        if (!item) {
            return null;
        }
        if (item.objectName === name) {
            return item;
        }
        for (let i = 0; i < item.children.length; i++) {
            const found = find(item.children[i], name);
            if (found) {
                return found;
            }
        }
        return null;
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: driver.apply()
    }

    function apply() {
        const full = widget.fullRepresentationItem;
        const list = find(full, "containerList");
        if (widget.dockerState === "ready" && !widget.isPinned("web-app")) {
            widget.togglePin("web-app");
        }
        switch (scenario) {
        case "stopped":
            find(full, "tabs").currentIndex = 1;
            break;
        case "search":
            widget.searchText = "node";
            break;
        case "menu":
            list.currentIndex = 2;
            list.forceActiveFocus();
            list.itemAtIndex(2).openMenu(true);
            break;
        case "confirm":
            list.itemAtIndex(2).pendingAction = "stop";
            break;
        case "about":
            widget.showAbout = true;
            break;
        case "settings":
            Plasmoid.internalAction("configure").trigger();
            break;
        }
    }
}
