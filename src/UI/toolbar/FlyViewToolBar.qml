/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Controllers
import QGroundControl.diab  // diab

Rectangle {
    id:     _root
    width:  parent.width
    height: ScreenTools.toolbarHeight
    color:  qgcPal.toolbarBackground

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: qgcPal.brandingPurple

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         1
        color:          "black"
        visible:        qgcPal.globalTheme === QGCPalette.Light
    }

    Rectangle {
        anchors.fill: viewButtonRow
        
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;                                     color: _mainStatusBGColor }
            GradientStop { position: currentButton.x + currentButton.width; color: _mainStatusBGColor }
            GradientStop { position: 1;                                     color: _root.color }
        }
    }

    RowLayout {
        id:                     viewButtonRow
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        spacing:                ScreenTools.defaultFontPixelWidth / 2

        QGCToolBarButton {
            id:                     currentButton
            Layout.preferredHeight: viewButtonRow.height
            icon.source:            "/res/QGCLogoFull.svg"
            logo:                   true
            onClicked:              mainWindow.showToolSelectDialog()
        }

        MainStatusIndicator {
            id: mainStatusIndicator
            Layout.preferredHeight: viewButtonRow.height
        }

        QGCButton {
            id:                 disconnectButton
            text:               qsTr("Disconnect")
            onClicked:          _activeVehicle.closeVehicle()
            visible:            _activeVehicle && _communicationLost
        }
    }

    QGCFlickable {
        id:                     toolsFlickable
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * ScreenTools.largeFontPointRatio * 1.5
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth / 2
        anchors.left:           viewButtonRow.right
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.right:          parent.right
        contentWidth:           toolIndicators.width
        flickableDirection:     Flickable.HorizontalFlick

        FlyViewToolBarIndicators { id: toolIndicators }
    }

    DroneController {
        id: droneController
    }

    QGCToolBarButton {
        id: diabutton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 150
        Layout.preferredHeight: viewButtonRow.height
        Layout.preferredWidth: 30
        icon.source: "/qmlimages/RidIconYellow.svg"
        text: qsTr("Open DiAB")
        onClicked: {
            diaVentana.open()
        }
    }

    Popup {
        id: diaVentana
        width: 400
        height: 300
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        anchors.centerIn: Overlay.overlay

        Connections {
            target: droneController

            function onDroneCountChanged(count) {
                listaDrones.clear()
                for (var i = 0; i < count; i++) {
                    listaDrones.append({
                        id: i,
                        status: 2,  // Default to Missing (2)
                    name: "Drone " + (i+1)
                    })
                }
            }

            function onDroneStatusChanged(droneId, status) {  // Changed parameter name from 'active' to 'status'
                if (droneId < listaDrones.count) {
                    listaDrones.setProperty(droneId, "status", status)  // Changed property name from 'active' to 'status'
                }
            }
        }

        // Model for drone list
        ListModel {
            id: listaDrones
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Text {
                id: statusText
                text: "Initializing..."
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#f0f0f0"
                border.color: "#c0c0c0"

                ListView {
                    anchors.fill: parent
                    anchors.margins: 5
                    model: listaDrones
                    clip: true

                    delegate: Rectangle {
                        width: parent.width
                        height: 60
                        // Change color based on status instead of active boolean
                        color: {
                            switch(model.status) {
                                case 0: return "#d0f0d0";  // Ready - green background
                                case 1: return "#f0e0c0";  // NotReady - amber background
                                case 2: return "#f0d0d0";  // Missing - red background
                                default: return "#e0e0e0";  // Unknown - gray background
                            }
                        }
                        border.color: "#a0a0a0"
                        radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 5

                            // Row for drone information
                            Row {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: name
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.bold: true
                                }

                                Text {
                                    // Replace with tristate text
                                    text: {
                                        switch(model.status) {
                                            case 0: return "READY";
                                            case 1: return "NOT READY";
                                            case 2: return "MISSING";
                                            default: return "UNKNOWN";
                                        }
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    // Update color to match status
                                    color: {
                                        switch(model.status) {
                                            case 0: return "green";
                                            case 1: return "orange";
                                            case 2: return "red";
                                            default: return "gray";
                                        }
                                    }
                                }
                            }

                            // Row for buttons - simplify to just ARM button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                // ARM button (renamed from TAKEOFF)
                                QGCButton {
                                    text: "ARM"
                                    enabled: model.status === 0  // Only enabled for READY drones
                                    Layout.fillWidth: true
                                    opacity: enabled ? 1.0 : 0.5
                                    onClicked: {
                                        droneController.sendArm(id)
                                    }
                                }

                                // LAND button is removed completely
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                QGCButton {
                    text: "Connect"
                    enabled: !droneController.isConnected
                    onClicked: droneController.startCommunications()
                    Layout.fillWidth: true
                }

                QGCButton {
                    text: "Disconnect"
                    enabled: droneController.isConnected
                    onClicked: droneController.stopCommunications()
                    Layout.fillWidth: true
                }

                QGCButton {
                    text: "Close"
                    onClicked: diaVentana.close()
                    Layout.fillWidth: true
                }
            }
        }

        onOpened: {
            // Automatically connect when opened
            droneController.startCommunications()
        }

        onClosed: {
            // Disconnect when closed
            droneController.stopCommunications()
        }
    }

    // DIAB END

    //-------------------------------------------------------------------------
    //-- Branding Logo
    Image {
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.margins:        ScreenTools.defaultFontPixelHeight * 0.66
        visible:                _activeVehicle && !_communicationLost && x > (toolsFlickable.x + toolsFlickable.contentWidth + ScreenTools.defaultFontPixelWidth)
        fillMode:               Image.PreserveAspectFit
        source:                 _outdoorPalette ? _brandImageOutdoor : _brandImageIndoor
        mipmap:                 true

        property bool   _outdoorPalette:        qgcPal.globalTheme === QGCPalette.Light
        property bool   _corePluginBranding:    QGroundControl.corePlugin.brandImageIndoor.length != 0
        property string _userBrandImageIndoor:  QGroundControl.settingsManager.brandImageSettings.userBrandImageIndoor.value
        property string _userBrandImageOutdoor: QGroundControl.settingsManager.brandImageSettings.userBrandImageOutdoor.value
        property bool   _userBrandingIndoor:    QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageIndoor.length != 0
        property bool   _userBrandingOutdoor:   QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageOutdoor.length != 0
        property string _brandImageIndoor:      brandImageIndoor()
        property string _brandImageOutdoor:     brandImageOutdoor()

        function brandImageIndoor() {
            if (_userBrandingIndoor) {
                return _userBrandImageIndoor
            } else {
                if (_userBrandingOutdoor) {
                    return _userBrandImageOutdoor
                } else {
                    if (_corePluginBranding) {
                        return QGroundControl.corePlugin.brandImageIndoor
                    } else {
                        return _activeVehicle ? _activeVehicle.brandImageIndoor : ""
                    }
                }
            }
        }

        function brandImageOutdoor() {
            if (_userBrandingOutdoor) {
                return _userBrandImageOutdoor
            } else {
                if (_userBrandingIndoor) {
                    return _userBrandImageIndoor
                } else {
                    if (_corePluginBranding) {
                        return QGroundControl.corePlugin.brandImageOutdoor
                    } else {
                        return _activeVehicle ? _activeVehicle.brandImageOutdoor : ""
                    }
                }
            }
        }
    }

    // Small parameter download progress bar
    Rectangle {
        anchors.bottom: parent.bottom
        height:         _root.height * 0.05
        width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
        color:          qgcPal.colorGreen
        visible:        !largeProgressBar.visible
    }

    // Large parameter download progress bar
    Rectangle {
        id:             largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         parent.height
        color:          qgcPal.window
        visible:        _showLargeProgress

        property bool _initialDownloadComplete: _activeVehicle ? _activeVehicle.initialConnectComplete : true
        property bool _userHide:                false
        property bool _showLargeProgress:       !_initialDownloadComplete && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
            color:          qgcPal.colorGreen
        }

        QGCLabel {
            anchors.centerIn:   parent
            text:               qsTr("Downloading")
            font.pointSize:     ScreenTools.largeFontPointSize
        }

        QGCLabel {
            anchors.margins:    _margin
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            text:               qsTr("Click anywhere to hide")

            property real _margin: ScreenTools.defaultFontPixelWidth / 2
        }

        MouseArea {
            anchors.fill:   parent
            onClicked:      largeProgressBar._userHide = true
        }
    }
}
