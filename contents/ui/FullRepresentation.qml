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
                objectName: "searchField"
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
                // Down moves into the list; Enter opens the menu of the first match
                Keys.onDownPressed: full.focusList(0)
                Keys.onReturnPressed: full.openMenuAt(0)
                Keys.onEnterPressed: full.openMenuAt(0)
            }

            PlasmaComponents3.TabBar {
                id: tabs
                objectName: "tabs"
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
            objectName: "containerList"
            model: full.onStoppedTab ? full.widget.inactiveModel : full.widget.activeModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true

            // Keyboard: Up/Down select, Enter/Space/Menu open the row's menu,
            // Left/Right switch tabs, Esc or Up on the first row go back to the search,
            // and typing goes straight into the search field.
            Keys.onUpPressed: event => {
                if (currentIndex <= 0) {
                    searchField.forceActiveFocus();
                } else {
                    decrementCurrentIndex();
                }
            }
            Keys.onReturnPressed: full.openMenuAt(currentIndex)
            Keys.onEnterPressed: full.openMenuAt(currentIndex)
            Keys.onSpacePressed: full.openMenuAt(currentIndex)
            Keys.onMenuPressed: full.openMenuAt(currentIndex)
            Keys.onLeftPressed: tabs.currentIndex = 0
            Keys.onRightPressed: {
                if (full.widget.showInactive) {
                    tabs.currentIndex = 1;
                }
            }
            Keys.onEscapePressed: searchField.forceActiveFocus()
            Keys.onPressed: event => {
                if (event.text.length > 0 && event.text.trim() !== "" && !(event.modifiers & Qt.ControlModifier)) {
                    full.widget.searchText += event.text;
                    searchField.forceActiveFocus();
                    event.accepted = true;
                }
            }

            delegate: ContainerDelegate {
                widget: full.widget
            }
        }
    }

    function focusList(index) {
        if (list.count > 0) {
            list.currentIndex = Math.min(index, list.count - 1);
            list.forceActiveFocus();
        }
    }

    function openMenuAt(index) {
        if (index < 0 || index >= list.count) {
            return;
        }
        focusList(index);
        list.positionViewAtIndex(index, ListView.Contain);
        const item = list.itemAtIndex(index);
        if (item) {
            item.openMenu(true);
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
