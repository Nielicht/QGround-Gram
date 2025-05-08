#ifndef DRONECONTROLLER_H
#define DRONECONTROLLER_H

#include <QObject>
#include <QString>
#include <QSerialPort>
#include <QVector>
#include <QThread>

/*
 * The DroneController class handles communication with the diab/drones via serial port.
 */
class DroneController : public QObject {
    Q_OBJECT

    // Properties accessible from QML
    Q_PROPERTY(int droneCount READ droneCount NOTIFY droneCountChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStatusChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)

public:
    // Drone status enum
    enum DroneStatus {
        Ready = 0,      // Drone is ready for operation
        NotReady = 1,   // Drone is detected but not ready
        Missing = 2     // Drone is not detected
    };
    Q_ENUM(DroneStatus) // This makes the enum accessible for QML

    // Command codes
    static const quint8 CMD_INIT = 0x31;         // Initialization command
    static const quint8 CMD_DRONE_COUNT = 0x32;  // Drone count response
    static const quint8 CMD_READY = 0x33;        // Ready status notification
    static const quint8 CMD_NOT_READY = 0x34;    // Not ready status notification
    static const quint8 CMD_MISSING = 0x35;      // Missing status notification
    static const quint8 CMD_ARM = 0x36;          // Arm command

    explicit DroneController(QObject *parent = nullptr);
    ~DroneController();

    // Test function for QML verification
    // Returns: Test string
    Q_INVOKABLE QString testFunc();

    // Start communication with drones
    // Returns: Success boolean
    Q_INVOKABLE bool startCommunications();

    // Stop communication with drones
    // Returns: Success boolean
    Q_INVOKABLE bool stopCommunications();

    // Send arm command to a specific drone
    // droneId: The ID of the drone to arm
    // Returns: Success boolean
    Q_INVOKABLE bool sendArm(int droneId);

    // Get the status of a specific drone
    // droneId: The ID of the drone
    // Returns: Status of the drone
    Q_INVOKABLE DroneStatus getDroneStatus(int droneId);

    // Property getters
    int droneCount() const { return m_droneCount; }
    bool isConnected() const { return m_connected; }
    QString statusMessage() const { return m_statusMessage; }

    // Serial port settings configuration
    // portName: The name of the serial port
    // baudRate: The baud rate for the serial port
    void configureSerialPort(const QString &portName, int baudRate = QSerialPort::Baud9600);

signals:
    void droneCountChanged(int count);
    void droneStatusChanged(int droneId, int status);
    void connectionStatusChanged(bool connected);
    void statusMessageChanged(QString message);

private slots:
    void handleReadyRead();
    void handleError(QSerialPort::SerialPortError error);

private:
    // Serial communication
    QSerialPort *m_serialPort;
    QString m_portName = "/dev/ttyUSB0"; // Default port name
    bool sendCommand(const QByteArray &data);

    // States
    enum ReceiveState {
        AwaitingCommand,
        AwaitingData
    };
    ReceiveState m_receiveState;
    quint8 m_currentCommand;

    // Drone states
    int m_droneCount;
    QVector<DroneStatus> m_droneStatus;
    bool m_connected;
    QString m_statusMessage;

    // Helper methods
    void setStatusMessage(const QString &message);
    void updateDroneStatus(int droneId, DroneStatus status);
};

#endif // DRONECONTROLLER_H
