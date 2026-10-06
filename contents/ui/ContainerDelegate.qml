import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// One container in two lines:
//   ● name                      status   [actions]
//     image              :port  ip
// Which details appear is chosen in the settings; without the image
// the row collapses to one line with ports and IP next to the status.
Item {
    id: row

    required property var widget

    // Roles from the ListModel (see docker.js parse())
    required property string cid
    required property string cname
    required property string image
    required property string statusText
    required property string health
    required property bool isActive
    required property string ports
    required property string ip
    required property bool busy
    required property string errorText

    readonly property bool showPorts: widget.showPorts && isActive && ports !== ""
    readonly property bool showIp: widget.showIp && isActive && ip !== ""

    // Port links (open in the browser) and the IP (click to copy).
    // Sits on line 2 next to the image, or on line 1 when the image is hidden.
    component PortsAndIp: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: row.showPorts ? row.ports.split(",") : []

            PlasmaComponents3.Label {
                id: portLabel
                required property string modelData

                text: ":" + modelData
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.underline: portHover.hovered
                color: Kirigami.Theme.linkColor

                HoverHandler {
                    id: portHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: row.widget.openPort(portLabel.modelData)
                }

                Accessible.role: Accessible.Link
                Accessible.name: i18n("Open http://localhost:%1", modelData)
                QQC2.ToolTip.text: i18n("Open http://localhost:%1", modelData)
                QQC2.ToolTip.visible: portHover.hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        PlasmaComponents3.Label {
            id: ipLabel

            readonly property bool copied: row.widget.lastCopied === row.ip

            visible: row.showIp
            text: row.ip
            font.family: "monospace"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.underline: ipHover.hovered
            // Turns green briefly after copying
            color: copied ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
            opacity: copied || ipHover.hovered ? 1 : 0.7
            textFormat: Text.PlainText

            HoverHandler {
                id: ipHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: row.widget.copyText(row.ip)
            }

            Accessible.role: Accessible.Button
            Accessible.name: i18n("Copy IP address %1", row.ip)
            QQC2.ToolTip.text: copied ? i18n("Copied") : i18n("Click to copy the IP address")
            QQC2.ToolTip.visible: ipHover.hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2

    // Light hover highlight so the row under the pointer is easy to follow
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.highlightColor
        opacity: rowHover.hovered ? 0.1 : 0
    }

    HoverHandler {
        id: rowHover
    }

    // Right-click (or long press on touch) anywhere on the row opens the menu
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: row.openMenu()
    }

    TapHandler {
        acceptedDevices: PointerDevice.TouchScreen
        onLongPressed: row.openMenu()
    }

    Keys.onMenuPressed: openMenu()

    // The menu is created on demand so 40 rows do not each keep one alive
    function openMenu() {
        const menu = menuComponent.createObject(row);
        menu.closed.connect(() => menu.destroy());
        menu.popup();
    }

    Component {
        id: menuComponent

        PlasmaComponents3.Menu {
            PlasmaComponents3.MenuItem {
                text: i18n("Show logs")
                icon.name: "view-list-text"
                onTriggered: row.widget.openTerminal("logs", row.cid)
            }

            PlasmaComponents3.MenuItem {
                visible: row.isActive
                height: visible ? implicitHeight : 0
                text: i18n("Open shell")
                icon.name: "utilities-terminal"
                onTriggered: row.widget.openTerminal("shell", row.cid)
            }

            PlasmaComponents3.MenuSeparator {}

            PlasmaComponents3.MenuItem {
                text: i18n("Copy name")
                icon.name: "edit-copy"
                onTriggered: row.widget.copyText(row.cname)
            }

            PlasmaComponents3.MenuItem {
                text: i18n("Copy ID")
                icon.name: "edit-copy"
                onTriggered: row.widget.copyText(row.cid.substring(0, 12))
            }

            PlasmaComponents3.MenuItem {
                visible: row.isActive && row.ip !== ""
                height: visible ? implicitHeight : 0
                text: i18n("Copy IP address")
                icon.name: "edit-copy"
                onTriggered: row.widget.copyText(row.ip)
            }

            PlasmaComponents3.MenuSeparator {}

            PlasmaComponents3.MenuItem {
                visible: row.isActive
                height: visible ? implicitHeight : 0
                enabled: !row.busy
                text: i18n("Restart")
                icon.name: "system-reboot"
                onTriggered: row.widget.runAction("restart", row.cid)
            }

            PlasmaComponents3.MenuItem {
                visible: row.isActive
                height: visible ? implicitHeight : 0
                enabled: !row.busy
                text: i18n("Stop")
                icon.name: "media-playback-stop"
                onTriggered: row.widget.runAction("stop", row.cid)
            }

            PlasmaComponents3.MenuItem {
                visible: !row.isActive
                height: visible ? implicitHeight : 0
                enabled: !row.busy
                text: i18n("Start")
                icon.name: "media-playback-start"
                onTriggered: row.widget.runAction("start", row.cid)
            }
        }
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            // Line 1: status dot, name (click to copy), status text.
            // Without the image there is no line 2, so ports and IP move up here.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // Filled dot = running (green ok, orange starting/paused, red unhealthy),
                // hollow ring = stopped (red when it exited with an error)
                Rectangle {
                    readonly property bool filled: row.isActive
                    readonly property color tone: {
                        switch (row.health) {
                        case "ok": return Kirigami.Theme.positiveTextColor;
                        case "starting": return Kirigami.Theme.neutralTextColor;
                        case "unhealthy":
                        case "failed": return Kirigami.Theme.negativeTextColor;
                        default: return Kirigami.Theme.disabledTextColor;
                        }
                    }

                    implicitWidth: Kirigami.Units.smallSpacing * 2
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: filled ? tone : "transparent"
                    border.width: filled ? 0 : 1
                    border.color: tone

                    HoverHandler {
                        id: dotHover
                    }

                    QQC2.ToolTip.text: {
                        switch (row.health) {
                        case "ok": return i18n("Running");
                        case "starting": return i18n("Starting, restarting or paused");
                        case "unhealthy": return i18n("Running, but the health check fails");
                        case "failed": return i18n("Stopped with an error");
                        default: return i18n("Stopped");
                        }
                    }
                    QQC2.ToolTip.visible: dotHover.hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                // Takes the free space; the name inside keeps its natural width
                // and only elides when the row is really too narrow.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: nameLabel.implicitHeight

                    PlasmaComponents3.Label {
                        id: nameLabel

                        readonly property bool copied: row.widget.lastCopied === row.cname

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width)
                        text: row.cname
                        font.bold: true
                        // Turns green briefly after copying
                        color: copied ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        textFormat: Text.PlainText

                        HoverHandler {
                            id: nameHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: row.widget.copyText(row.cname)
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: i18n("Copy name %1", row.cname)
                        QQC2.ToolTip.text: copied ? i18n("Copied") : i18n("Click to copy the name, right-click for more")
                        QQC2.ToolTip.visible: nameHover.hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }

                PortsAndIp {
                    visible: !row.widget.showImage
                }

                PlasmaComponents3.Label {
                    visible: row.widget.showStatus
                    text: row.statusText
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    textFormat: Text.PlainText
                }
            }

            // Line 2: image, port links, IP
            RowLayout {
                Layout.fillWidth: true
                // Line up with the name, past the status dot
                Layout.leftMargin: Kirigami.Units.smallSpacing * 3
                visible: row.widget.showImage
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: row.image
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                }

                PortsAndIp {}
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing * 3
                visible: row.errorText !== ""
                text: row.errorText
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }

        PlasmaComponents3.BusyIndicator {
            visible: row.busy
            running: row.busy
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }

        PlasmaComponents3.ToolButton {
            visible: !row.busy && row.isActive
            icon.name: "system-reboot"
            display: QQC2.AbstractButton.IconOnly
            text: i18n("Restart")
            onClicked: row.widget.runAction("restart", row.cid)
            Accessible.name: i18n("Restart %1", row.cname)
            QQC2.ToolTip.text: i18n("Restart")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        PlasmaComponents3.ToolButton {
            visible: !row.busy && row.isActive
            icon.name: "media-playback-stop"
            display: QQC2.AbstractButton.IconOnly
            text: i18n("Stop")
            onClicked: row.widget.runAction("stop", row.cid)
            Accessible.name: i18n("Stop %1", row.cname)
            QQC2.ToolTip.text: i18n("Stop")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        PlasmaComponents3.ToolButton {
            visible: !row.busy && !row.isActive
            icon.name: "media-playback-start"
            display: QQC2.AbstractButton.IconOnly
            text: i18n("Start")
            onClicked: row.widget.runAction("start", row.cid)
            Accessible.name: i18n("Start %1", row.cname)
            QQC2.ToolTip.text: i18n("Start")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }
}
