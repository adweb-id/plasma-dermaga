import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.extras as PlasmaExtras

import "docker.js" as Docker

// One full-popup message per reason Docker cannot be used,
// each with the single action that fixes it.
PlasmaExtras.PlaceholderMessage {
    id: warning

    required property var widget
    readonly property string kind: widget.dockerState

    iconName: {
        switch (kind) {
        case "noPermission": return "object-locked";
        case "daemonDown": return "system-shutdown";
        default: return "dialog-warning";
        }
    }

    text: {
        switch (kind) {
        case "notInstalled": return i18n("Docker is not installed");
        case "noPermission": return i18n("No permission to use Docker");
        case "daemonDown": return i18n("Docker service is not running");
        default: return i18n("Docker returned an error");
        }
    }

    explanation: {
        switch (kind) {
        case "notInstalled":
            return i18n("The docker command was not found on this system.");
        case "noPermission":
            return i18n("Your user is not in the docker group. Run this command, then log out and back in:\n%1", Docker.PERMISSION_FIX);
        case "daemonDown":
            return i18n("The Docker daemon is stopped, so containers cannot be listed. You will be asked for your password.");
        default:
            return widget.errorText;
        }
    }

    helpfulAction: QQC2.Action {
        icon.name: {
            switch (warning.kind) {
            case "notInstalled": return "internet-services";
            case "noPermission": return "edit-copy";
            case "daemonDown": return "media-playback-start";
            default: return "view-refresh";
            }
        }
        text: {
            switch (warning.kind) {
            case "notInstalled": return i18n("Open install guide");
            case "noPermission": return i18n("Copy command");
            case "daemonDown": return i18n("Start Docker");
            default: return i18n("Try again");
            }
        }
        onTriggered: {
            switch (warning.kind) {
            case "notInstalled": warning.widget.openGuide(); break;
            case "noPermission": warning.widget.copyPermissionFix(); break;
            case "daemonDown": warning.widget.startService(); break;
            default: warning.widget.refresh();
            }
        }
    }
}
