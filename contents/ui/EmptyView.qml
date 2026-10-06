import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "docker.js" as Docker

// Shown when Docker works but the selected tab has no containers (or no search matches).
// Explains why the list is empty and offers the next step.
ColumnLayout {
    id: empty

    required property var widget
    required property bool stoppedTab

    // 0 = Running tab, 1 = Stopped tab
    signal showTabRequested(int index)
    signal clearSearchRequested()

    readonly property int total: widget.activeCount + widget.inactiveCount
    // Search matches in the tab that is not shown (the Stopped tab only when it is enabled)
    readonly property int otherMatches: stoppedTab ? widget.activeShown
                                                   : (widget.showInactive ? widget.inactiveShown : 0)
    // none | noMatch | noneRunning | noneRunningHidden | noneStopped
    readonly property string kind: {
        if (total === 0) {
            return "none";
        }
        if (widget.searchText.trim() !== "") {
            return "noMatch";
        }
        if (stoppedTab) {
            return "noneStopped";
        }
        return widget.showInactive ? "noneRunning" : "noneRunningHidden";
    }
    readonly property url illustration: Qt.resolvedUrl("../icons/dermaga-empty.svg")
    readonly property bool exampleCopied: widget.lastCopied === Docker.EXAMPLE_RUN

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Kirigami.Units.iconSizes.huge
        implicitHeight: Kirigami.Units.iconSizes.huge
        // A search with no results gets the search icon, an empty dock otherwise
        source: empty.kind === "noMatch" ? "edit-find" : empty.illustration.toString()
        isMask: empty.kind !== "noMatch"
        color: Kirigami.Theme.textColor
        opacity: 0.6
    }

    Kirigami.Heading {
        Layout.fillWidth: true
        level: 3
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        opacity: 0.8
        text: {
            switch (empty.kind) {
            case "none": return i18n("No containers yet");
            case "noMatch": return i18n("No matching containers");
            case "noneStopped": return i18n("No stopped containers");
            default: return i18n("No running containers");
            }
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: {
            switch (empty.kind) {
            case "none":
                return i18n("Docker is running, but there are no containers on this machine. Create one, for example:");
            case "noMatch":
                if (empty.otherMatches > 0) {
                    return empty.stoppedTab
                        ? i18np("Nothing stopped matches “%2”, but %1 running container does.",
                                "Nothing stopped matches “%2”, but %1 running containers do.",
                                empty.otherMatches, empty.widget.searchText.trim())
                        : i18np("Nothing running matches “%2”, but %1 stopped container does.",
                                "Nothing running matches “%2”, but %1 stopped containers do.",
                                empty.otherMatches, empty.widget.searchText.trim());
                }
                return i18n("No container name, image, port or IP contains “%1”.", empty.widget.searchText.trim());
            case "noneStopped":
                return i18np("The only container is running.", "All %1 containers are running.", empty.total);
            case "noneRunning":
                return i18np("%1 stopped container is ready to start.",
                             "%1 stopped containers are ready to start.", empty.widget.inactiveCount);
            default:
                return i18np("%1 stopped container is hidden by the settings.",
                             "%1 stopped containers are hidden by the settings.", empty.widget.inactiveCount);
            }
        }
    }

    // Example command, monospace so it reads as something to type
    PlasmaComponents3.Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: parent.width
        visible: empty.kind === "none"
        text: Docker.EXAMPLE_RUN
        font.family: "monospace"
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    PlasmaComponents3.Button {
        Layout.alignment: Qt.AlignHCenter
        visible: empty.kind !== "noneStopped"
        icon.name: {
            switch (empty.kind) {
            case "none": return empty.exampleCopied ? "dialog-ok" : "edit-copy";
            case "noMatch": return empty.otherMatches > 0 ? "go-next" : "edit-clear";
            case "noneRunning": return "go-next";
            default: return "view-visible";
            }
        }
        text: {
            switch (empty.kind) {
            case "none":
                return empty.exampleCopied ? i18n("Copied") : i18n("Copy command");
            case "noMatch":
                if (empty.otherMatches === 0) {
                    return i18n("Clear search");
                }
                return empty.stoppedTab ? i18n("Show running matches") : i18n("Show stopped matches");
            default:
                return i18n("Show stopped containers");
            }
        }
        onClicked: {
            switch (empty.kind) {
            case "none":
                empty.widget.copyText(Docker.EXAMPLE_RUN);
                break;
            case "noMatch":
                if (empty.otherMatches > 0) {
                    empty.showTabRequested(empty.stoppedTab ? 0 : 1);
                } else {
                    empty.clearSearchRequested();
                }
                break;
            case "noneRunningHidden":
                // Turn the Stopped tab back on, then jump to it
                empty.widget.setShowInactive(true);
                empty.showTabRequested(1);
                break;
            default:
                empty.showTabRequested(1);
            }
        }
    }
}
