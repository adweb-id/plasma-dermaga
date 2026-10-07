import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

// "About Dermaga", opened from the panel icon's right-click menu.
// Name, version, author and links come from metadata.json.
ColumnLayout {
    id: about

    required property var widget

    readonly property var meta: Plasmoid.metaData

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Kirigami.Units.iconSizes.enormous
        implicitHeight: Kirigami.Units.iconSizes.enormous
        source: Qt.resolvedUrl("../icons/dermaga-logo.svg").toString()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Kirigami.Heading {
            Layout.fillWidth: true
            level: 2
            horizontalAlignment: Text.AlignHCenter
            text: about.meta.name
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: i18n("Version %1", about.meta.version)
            opacity: 0.7
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: about.meta.description
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        text: i18n("%1 · License %2", about.meta.copyrightText, about.meta.license)
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Button {
            icon.name: "internet-services"
            text: i18n("Source code")
            onClicked: Qt.openUrlExternally(about.meta.website)
        }

        PlasmaComponents3.Button {
            icon.name: "tools-report-bug"
            text: i18n("Report a bug")
            onClicked: Qt.openUrlExternally(about.meta.bugReportUrl)
        }
    }

    PlasmaComponents3.Button {
        Layout.alignment: Qt.AlignHCenter
        flat: true
        icon.name: "go-previous"
        text: i18n("Back")
        onClicked: about.widget.showAbout = false
    }
}
