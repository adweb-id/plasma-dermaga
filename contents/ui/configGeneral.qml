import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_showInactive: inactiveCheck.checked
    property alias cfg_showImage: imageCheck.checked
    property alias cfg_showStatus: statusCheck.checked
    property alias cfg_showPorts: portsCheck.checked
    property alias cfg_showIp: ipCheck.checked
    property alias cfg_notifyDocker: notifyDockerCheck.checked
    property alias cfg_notifyContainers: notifyContainersCheck.checked

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Refresh interval (seconds):")
            from: 2
            to: 60
        }

        QQC2.CheckBox {
            id: inactiveCheck
            Kirigami.FormData.label: i18n("Containers:")
            text: i18n("Show stopped containers")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: imageCheck
            Kirigami.FormData.label: i18n("Show in each row:")
            text: i18n("Image")
        }

        QQC2.CheckBox {
            id: statusCheck
            text: i18n("Status (uptime or exit code)")
        }

        QQC2.CheckBox {
            id: portsCheck
            text: i18n("Published ports")
        }

        QQC2.CheckBox {
            id: ipCheck
            text: i18n("IP address")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: notifyDockerCheck
            Kirigami.FormData.label: i18n("Notify when:")
            text: i18n("The Docker service stops or starts again")
        }

        QQC2.CheckBox {
            id: notifyContainersCheck
            text: i18n("A container crashes or becomes unhealthy")
        }
    }
}
