import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MCUScreen());
}

class MCUScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMPACT',
      debugShowCheckedModeBanner: false,
      home: MCU(),
      theme: ThemeData.light(),
    );
  }
}

class MCU extends StatefulWidget {
  @override
  _MCUState createState() => _MCUState();
}

class _MCUState extends State<MCU> {
  final String SERVICE_UUID =
      "4fafc201-1fb5-459e-8fcc-c5c9c331914b".toUpperCase();
  final String DATA_CHARACTERISTIC_UUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8".toUpperCase();
  final String ACK_CHARACTERISTIC_UUID =
      "ad79d3e8-8f69-4086-b0f4-4aa46cf28000".toUpperCase();
  final String DEVICE_NAME = "IMPACT";

  FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult>? scanSubscription;

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? dataCharacteristic;
  BluetoothCharacteristic? ackCharacteristic;

  String connectionText = "";

  @override
  void initState() {
    super.initState();
    startScan();
  }

  startScan() {
    setState(() {
      connectionText = "Starting Scan";
    });

    scanSubscription = flutterBlue.scan().listen((ScanResult) {
      if (ScanResult.device.name == DEVICE_NAME) {
        print("MCU FOUND...");
        stopScan();
        setState(() {
          connectionText = "Found MCU";
        });
        targetDevice = ScanResult.device;
        connectToDevice();
      }
    }, onDone: () => stopScan());
  }

  stopScan() {
    scanSubscription?.cancel();
    scanSubscription = null;
  }

  connectToDevice() async {
    if (targetDevice == null) return;

    setState(() {
      connectionText = "Connecting to MCU";
    });

    await targetDevice!.connect();
    print("DEVICE CONNECTED");
    setState(() {
      connectionText = "Device Connected";
    });

    discoverServices();
  }

  disconnectFromDevice() {
    if (targetDevice == null) return;

    targetDevice!.disconnect();

    setState(() {
      connectionText = "Device Disconnected";
    });
  }

  discoverServices() async {
    if (targetDevice == null) return;

    List<BluetoothService> services = await targetDevice!.discoverServices();
    services.forEach((s) {
      if (s.uuid.toString().toUpperCase() == SERVICE_UUID) {
        s.characteristics.forEach((c) {
          if (c.uuid.toString().toUpperCase() == ACK_CHARACTERISTIC_UUID) {
            ackCharacteristic = c;
            writeData("1");
            setState(() {
              connectionText = "Sent ACK";
            });
          }
        });

        s.characteristics.forEach((c) {
          if (c.uuid.toString().toUpperCase() == DATA_CHARACTERISTIC_UUID) {
            dataCharacteristic = c;
            print(c.read());
            setState(() {
              connectionText = "reading${c.read().toString()}";
            });
          }
        });
      }
    });
  }

  writeData(String data) async {
    if (ackCharacteristic == null) return;

    List<int> bytes = utf8.encode(data);
    await ackCharacteristic!.write(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(connectionText),
      ),
      body: Container(
        child: dataCharacteristic == null
            ? Center(
                child: Text(
                "Waiting",
                style: TextStyle(fontSize: 20, color: Colors.black),
              ))
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[Text("reading${dataCharacteristic!.read().toString()}")],
              ),
      ),
    );
  }
}
