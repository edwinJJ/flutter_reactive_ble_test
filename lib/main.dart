import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Reactive BLE Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BLEScanner(),
    );
  }
}

class BLEScanner extends StatefulWidget {
  const BLEScanner({super.key});

  @override
  _BLEScannerState createState() => _BLEScannerState();
}

class _BLEScannerState extends State<BLEScanner> {
  final flutterReactiveBle = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? connectionSubscription;
  StreamSubscription<List<int>>? characteristicSubscription;
  Timer? scanTimer;
  List<DiscoveredDevice> discoveredDevices = [];
  bool isScanning = false;
  DiscoveredDevice? connectedDevice;
  String connectionStatus = 'Disconnected';
  String receivedMessage = '';
  String? connectedDeviceId;
  // bool isReconnecting = false;
  // 예시 UUID - 실제 디바이스의 UUID로 변경해야 합니다.
  // TEST
  // final Uuid serviceUuid = Uuid.parse("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  // final Uuid writeCharacteristicUuid =
  //     Uuid.parse("6e400007-b5a3-f393-e0a9-e50e24dcca9e");
  // final Uuid notifyCharacteristicUuid =
  //     Uuid.parse("6e400006-b5a3-f393-e0a9-e50e24dcca9e"); // 알림을 위한 특성 UUID
  // final Uuid readCharacteristicUuid =
  //     Uuid.parse("6e400004-b5a3-f393-e0a9-e50e24dcca9e"); // 읽기 특성 UUID
  // ECU
  final Uuid serviceUuid = Uuid.parse("0000180d-0000-1000-8000-00805f9b34fb");
  final Uuid writeCharacteristicUuid =
      Uuid.parse("b437b6fa-e40e-424e-8b31-6cd5b4aba99b");
  final Uuid notifyCharacteristicUuid =
      Uuid.parse("6e400006-b5a3-f393-e0a9-e50e24dcca9e"); // 알림을 위한 특성 UUID
  final Uuid readCharacteristicUuid =
      Uuid.parse("6e400004-b5a3-f393-e0a9-e50e24dcca9e"); // 읽기 특성 UUID

  @override
  void initState() {
    super.initState();
    setState(() {
      _requestPermissions();
      connectionSubscription = null;
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification
    ].request();
  }

  void startScan() {
    setState(() {
      discoveredDevices.clear();
      isScanning = true;
    });
    print('@@@@@@@@@@@@@@startScan');
    scanSubscription = flutterReactiveBle.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      print('@@@@@@@@@@@@@@listen : $device');
      if (!discoveredDevices.any((d) => d.id == device.id)) {
        setState(() {
          discoveredDevices.add(device);
        });
      } else {
        // 이미 존재하는 디바이스의 경우, 정보를 업데이트할 수 있습니다.
        int index = discoveredDevices.indexWhere((d) => d.id == device.id);
        if (index != -1) {
          setState(() {
            discoveredDevices[index] = device;
          });
        }
      }
    }, onDone: () {
      // 예외적인 상황을 위한 로그
      print('@@@@@@@@@@@@@@onDone: Scan stream closed unexpectedly');
    }, onError: (error) {
      // 에러 처리를 위한 로그
      print('@@@@@@@@@@@@@@onError: $error');
    });

    // 20초 후에 자동으로 스캔을 중지합니다.
    scanTimer = Timer(const Duration(seconds: 10), () {
      stopScan();
      print('@@@@@@@@@@@@@@Scan stopped after 10 seconds');
    });
  }

  void stopScan() {
    setState(() {
      scanSubscription?.cancel();
      scanSubscription = null;
      scanTimer?.cancel();
      scanTimer = null;
      isScanning = false;
    });
  }

  void connectToDevice(DiscoveredDevice device) {
    print('@@@@@@@@@@@@@@Connecting to device: ${device.name}');
    connectionSubscription?.cancel();
    connectionSubscription = flutterReactiveBle
        .connectToDevice(
            id: device.id, connectionTimeout: const Duration(seconds: 5))
        .listen((connectionState) {
      print(
          '@@@@@@@@@@@@@@Connection state: ${connectionState.connectionState}');
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        print('@@@@@@@@@@@@@@Connected to device: ${device.name}');
        setState(() {
          connectionStatus = 'connected!';
          receivedMessage = '';
          connectedDeviceId = device.id;
          // isReconnecting = false;
        });
        // 연결 후 잠시 대기
        Future.delayed(const Duration(seconds: 2), () {
          // subscribeToNotifications(device.id);
        });
      } else if (connectionState.connectionState ==
          DeviceConnectionState.disconnected) {
        print('@@@@@@@@@@@@@@Disconnected from device: ${device.name}');
        setState(() {
          connectionStatus = 'Disconnected';
          connectedDeviceId = '';
          receivedMessage = '';
        });
        // if (!isReconnecting) {
        // reconnect(device);
        // }
      }
    }, onError: (Object error) {
      print('@@@@@@@@@@@@@@Connection error: $error');
      // if (!isReconnecting) {
      // reconnect(device);
      // }
    });
  }

  // void reconnect(DiscoveredDevice device) {
  //   if (isReconnecting) return;
  //   print('Attempting to reconnect to device: ${device.id}');
  //   setState(() {
  //     isReconnecting = true;
  //   });
  //   Future.delayed(const Duration(seconds: 2), () {
  //     connectToDevice(DiscoveredDevice(
  //         id: device.id,
  //         name: '',
  //         serviceData: const {},
  //         manufacturerData: const [],
  //         rssi: 0));
  //   });
  //   // Future.delayed(const Duration(seconds: 2), connectToDevice(device));
  // }

  void subscribeToNotifications(String deviceId) {
    print('@@@@@@@@@@@@@@subscribeToNotifications');
    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: notifyCharacteristicUuid,
      deviceId: deviceId,
    );
    characteristicSubscription = flutterReactiveBle
        .subscribeToCharacteristic(characteristic)
        .listen((data) {
      final receivedData = utf8.decode(data);
      print('@@@@@@@@@@@@@@Received: $receivedData');
      setState(() {
        receivedMessage = receivedData;
      });
    }, onDone: () {
      print('@@@@@@@@@@@@@@Notification onDone');
    }, onError: (dynamic error) {
      print('@@@@@@@@@@@@@@Notification error: $error');
    });
  }

  Future<void> readCharacteristic() async {
    if (connectedDeviceId == null) {
      print('No device connected');
      return;
    }

    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: readCharacteristicUuid,
      deviceId: connectedDeviceId!,
    );

    try {
      final response =
          await flutterReactiveBle.readCharacteristic(characteristic);
      final readData = utf8.decode(response);
      print('@@@@@@@@@@@@@@Read: $readData');
      setState(() {
        receivedMessage = readData;
      });
    } catch (e) {
      print('@@@@@@@@@@@@@@Error reading characteristic: $e');
    }
  }

  Future<void> sendWifiConnectMessage() async {
    if (!mounted) return;
    print('@@@@@@@@@@@@@@sendWifiConnectMessage');

    if (connectedDeviceId == null) {
      print('@@@@@@@@@@@@@@No device connected');
      return;
    }

    // if (!(await checkConnectionStatus())) {
    //   print('@@@@@@@@@@@@@@Device not connected');
    //   return;
    // }

    final message = {
      "category": "wifi",
      "info": {
        "action": "connect",
        "ssid": "KT_GiGA_5G_16D0",
        "psk": "xde3hd6985"
      }
    };

    final jsonMessage = jsonEncode(message);
    final data = utf8.encode(jsonMessage);

    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: writeCharacteristicUuid,
      deviceId: connectedDeviceId!,
    );
    print('@@@@@@@@@@@@@@characteristic : $characteristic');
    try {
      await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
          value: data);
      print('@@@@@@@@@@@@@@Message sent successfully');
    } catch (error) {
      print('@@@@@@@@@@@@@@Error sending message: $error');
    }
  }

  @override
  void dispose() {
    stopScan();
    connectionSubscription?.cancel();
    characteristicSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE WiFi Connect'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? stopScan : startScan,
            child: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
          ),
          Text('Connection Status: $connectionStatus'),
          Text('Received Message: $receivedMessage'),
          Text('connectedDeviceId: $connectedDeviceId'),
          Expanded(
            child: ListView.builder(
              itemCount: discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = discoveredDevices[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text(device.id),
                  onTap: () => connectToDevice(device),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed:
                connectedDeviceId != null ? sendWifiConnectMessage : null,
            child: const Text('Send WiFi Connect Message'),
          ),
          ElevatedButton(
            onPressed: readCharacteristic,
            child: const Text('Read Characteristic'),
          ),
        ],
      ),
    );
  }
}
