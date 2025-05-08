#include "DroneController.h"
#include <QDebug>

DroneController::DroneController(QObject *parent)
: QObject(parent)
, m_serialPort(nullptr)
, m_receiveState(AwaitingCommand)
, m_droneCount(0)
, m_connected(false)
, m_statusMessage("Disconnected")
{
    // Initialize serial port - keeping original initialization pattern
    m_serialPort = new QSerialPort(this);

    // Connect signals
    connect(m_serialPort, &QSerialPort::readyRead, this, &DroneController::handleReadyRead);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, &DroneController::handleError);
}

DroneController::~DroneController() {
    if (m_serialPort && m_serialPort->isOpen()) {
        m_serialPort->close();
    }
    // No need to delete m_serialPort as it's a child QObject that will be cleaned up
}

QString DroneController::testFunc() {
    return "Hello world!";
}

void DroneController::configureSerialPort(const QString &portName, int baudRate) {
    m_portName = portName;

    // Only configure if the serial port exists
    if (m_serialPort) {
        m_serialPort->setBaudRate(baudRate);
        m_serialPort->setDataBits(QSerialPort::Data8);
        m_serialPort->setParity(QSerialPort::NoParity);
        m_serialPort->setStopBits(QSerialPort::OneStop);
        m_serialPort->setFlowControl(QSerialPort::NoFlowControl);
    }
}

bool DroneController::startCommunications() {
    qDebug() << "Starting communications with drone...";

    // Close port if already open
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }

    // Configure the serial port - maintaining the original configuration
    m_serialPort->setPortName(m_portName);
    m_serialPort->setBaudRate(QSerialPort::Baud9600);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    // Try to open the serial port
    if (!m_serialPort->open(QIODevice::ReadWrite)) {
        setStatusMessage("Failed to open port " + m_portName + ": " + m_serialPort->errorString());
        m_connected = false;
        emit connectionStatusChanged(false);
        return false;
    }

    // Keep the original timing - critical for Arduino communication
    QThread::sleep(2);

    // Clear any pending data
    m_serialPort->clear();

    // Send initialization bytes with original values
    QByteArray initCommand;
    initCommand += static_cast<char>(CMD_INIT);
    initCommand += static_cast<char>(0x00);

    qDebug() << "Sending init command:" << "0x" + initCommand.toHex(' ').replace(" ", " 0x");

    bool success = m_serialPort->write(initCommand) == 2;

    if (success) {
        // Force flush the write buffer
        m_serialPort->flush();

        // Maintain original wait timing
        QThread::sleep(2);

        setStatusMessage("Waiting for DiAB response...");
        m_connected = true;
        emit connectionStatusChanged(true);

        // At this point, the Arduino should send back the drone count
        // and enter its active state, which our handleReadyRead will process
    } else {
        qDebug() << "Failed to send initialization command";
        setStatusMessage("Failed to initialize communication");
        m_connected = false;
        emit connectionStatusChanged(false);
    }

    return success;
}

bool DroneController::stopCommunications() {
    if (m_serialPort && m_serialPort->isOpen()) {
        m_serialPort->close();
        m_connected = false;
        emit connectionStatusChanged(false);
        setStatusMessage("Disconnected");
        return true;
    }
    return false;
}

DroneController::DroneStatus DroneController::getDroneStatus(int droneId) {
    if (droneId >= 0 && droneId < m_droneCount) {
        return m_droneStatus[droneId];
    }
    return Missing; // If non existent, default to missing
}

bool DroneController::sendCommand(const QByteArray &data) {
    if (!m_serialPort || !m_serialPort->isOpen()) {
        qDebug() << "Cannot send command - port not open";
        return false;
    }

    qint64 bytesWritten = m_serialPort->write(data);
    if (bytesWritten == -1) {
        qDebug() << "Write error:" << m_serialPort->errorString();
        return false;
    } else if (bytesWritten != data.size()) {
        qDebug() << "Failed to write all data";
        return false;
    }

    // Wait for data to be written
    if (!m_serialPort->waitForBytesWritten(1000)) {
        qDebug() << "Timeout waiting for write";
        return false;
    }

    return true;
}

void DroneController::handleReadyRead() {
    // Read available data
    while (m_serialPort->bytesAvailable() >= 1) {
        // Read one byte at a time
        char byte;
        if (m_serialPort->read(&byte, 1) != 1) {
            continue;
        }

        // Process based on current state
        if (m_receiveState == AwaitingCommand) {
            // This is a command byte
            m_currentCommand = static_cast<quint8>(byte);
            m_receiveState = AwaitingData;
        } else {
            // This is a data byte, process based on command
            quint8 data = static_cast<quint8>(byte);

            // Use the constants defined in the header for command comparison
            switch (m_currentCommand) {
                case CMD_DRONE_COUNT:  // Drone count message (0x32)
                    m_droneCount = data;
                    m_droneStatus.resize(m_droneCount);
                    for (int i = 0; i < m_droneCount; i++) {
                        m_droneStatus[i] = Missing;  // Initialize all to Missing (2)
                    }
                    setStatusMessage(QString("Connected - %1 drones available").arg(m_droneCount));
                    emit droneCountChanged(m_droneCount);
                    break;

                case CMD_READY:  // Ready drone message (0x33)
                    updateDroneStatus(data, Ready);
                    break;

                case CMD_NOT_READY:  // NotReady drone message (0x34)
                    updateDroneStatus(data, NotReady);
                    break;

                case CMD_MISSING:  // Missing drone message (0x35)
                    updateDroneStatus(data, Missing);
                    break;

                default:
                    qDebug() << "Unknown command received:" << m_currentCommand;
                    break;
            }

            // Reset to await next command
            m_receiveState = AwaitingCommand;
        }
    }
}

void DroneController::updateDroneStatus(int droneId, DroneStatus status) {
    // Helper function to reduce code duplication but preserving behavior
    if (droneId < m_droneCount) {
        m_droneStatus[droneId] = status;
        emit droneStatusChanged(droneId, static_cast<int>(status));

        QString statusStr;
        switch(status) {
            case Ready: statusStr = "Ready"; break;
            case NotReady: statusStr = "Not Ready"; break;
            case Missing: statusStr = "Missing"; break;
        }
        qDebug() << "Drone" << droneId << "is" << statusStr;
    }
}

bool DroneController::sendArm(int droneId) {
    if (!m_serialPort || !m_serialPort->isOpen() || droneId >= m_droneCount) {
        qDebug() << "Invalid drone ID or not connected";
        return false;
    }

    // Create arm command using the constant
    QByteArray command;
    command.append(static_cast<char>(CMD_ARM));  // 0x42
    command.append(static_cast<char>(droneId));

    qDebug() << "Sending arm command for drone" << droneId;
    return sendCommand(command);
}

void DroneController::handleError(QSerialPort::SerialPortError error) {
    if (error == QSerialPort::NoError) {
        return;
    }

    setStatusMessage(QString("Serial error: %1").arg(m_serialPort->errorString()));

    if (error != QSerialPort::NotOpenError && m_serialPort->isOpen()) {
        stopCommunications();
    }
}

void DroneController::setStatusMessage(const QString &message) {
    if (m_statusMessage != message) {
        m_statusMessage = message;
        emit statusMessageChanged(m_statusMessage);
    }
}
