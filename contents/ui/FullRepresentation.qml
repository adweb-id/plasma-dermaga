import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras

PlasmaExtras.Representation {
    id: full

    required property var widget

    readonly property bool ready: widget.dockerState === "ready"
    // Tab 0 = running, tab 1 = stopped (only when enabled in the settings)
    readonly property bool onStoppedTab: widget.showInactive && tabs.currentIndex === 1

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    spacing: 0

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 4
                        text: i18n("Dermaga")
                        elide: Text.ElideRight
                    }

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: full.widget.summaryText
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: full.widget.refresh()
                    Accessible.name: i18n("Refresh")
                    QQC2.ToolTip.text: i18n("Refresh")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            PlasmaExtras.SearchField {
                id: searchField
                Layout.fillWidth: true
                visible: full.ready
                placeholderText: i18n("Search name, image, port or IP…")
                text: full.widget.searchText
                onTextChanged: full.widget.searchText = text
                Keys.onEscapePressed: event => {
                    if (text !== "") {
                        full.widget.searchText = "";
                        event.accepted = true;
                    } else {
                        event.accepted = false; // let Escape close the popup
                    }
                }
            }

            PlasmaComponents3.TabBar {
                id: tabs
                Layout.fillWidth: true
                visible: full.ready && full.widget.showInactive

                PlasmaComponents3.TabButton {
                    text: i18n("Running (%1)", full.widget.activeShown)
                }

                PlasmaComponents3.TabButton {
                    text: i18n("Stopped (%1)", full.widget.inactiveShown)
                }
            }
        }
    }

    // State: list of the selected tab
    PlasmaComponents3.ScrollView {
        anchors.fill: parent
        visible: full.ready && list.count > 0

        contentItem: ListView {
            id: list
            model: full.onStoppedTab ? full.widget.inactiveModel : full.widget.activeModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: ContainerDelegate {
                widget: full.widget
            }
        }
    }

    // State: first load
    PlasmaComponents3.BusyIndicator {
        anchors.centerIn: parent
        visible: full.widget.dockerState === "loading"
        running: visible
    }

    // State: Docker works, selected tab is empty
    EmptyView {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: full.ready && list.count === 0
        widget: full.widget
        stoppedTab: full.onStoppedTab
        onShowTabRequested: index => tabs.currentIndex = index
        onClearSearchRequested: full.widget.searchText = ""
    }

    // Typing works as soon as the popup opens
    Connections {
        target: full.widget
        function onExpandedChanged() {
            if (full.widget.expanded) {
                searchField.forceActiveFocus();
            }
        }
    }

    // State: Docker cannot be used
    WarningView {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: full.widget.hasWarning
        widget: full.widget
    }
}
