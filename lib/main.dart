// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:ble_testing/widgets.dart';

Map<String, String> dataBuffer = new Map();

String initTime = "";
String dataText = "";
bool isStopped = false;

// Team Buffer: List of CSV data, each with Service UUID + Timestamp
// List<String> teamBuffer = new List<>();

void main() {
  runApp(FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subtitle1
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data ==
                                    BluetoothDeviceState.connected) {
                                  return RaisedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map(
                        (r) => ScanResultTile(
                          result: r,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            r.device.connect();
                            isStopped = false;
                            return DeviceScreen(device: r.device);
                          })),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _ackBytes() {
    return utf8.encode("1");
  }

  void logData(String data) async {
    var key = "";
    var value = "";

    var splitData = data.split(',');
    key = splitData[0];
    value = splitData.sublist(1).toString();

    dataBuffer.putIfAbsent(key, () => value);
  }

  Widget _buildImpactTile(List<BluetoothService> services) {
    BluetoothService mcuService;
    for (int i = 0; i < services.length; i++) {
      if (services[i].uuid.toString() ==
          "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
        mcuService = services[i];

        var dataCharacteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
        var ackCharacteristicUUID = "ad79d3e8-8f69-4086-b0f4-4aa46cf28000";
        var dataCharacteristic = mcuService.characteristics
            .singleWhere((c) => c.uuid.toString() == dataCharacteristicUUID);
        var ackCharacteristic = mcuService.characteristics
            .singleWhere((c) => c.uuid.toString() == ackCharacteristicUUID);

        return ServiceTile(
            service: mcuService,
            characteristicTiles: [
              mcuService.characteristics.singleWhere(
                  (c) => c.uuid.toString() == dataCharacteristicUUID)
            ]
                .map((c) => CharacteristicsTile(
                      ackChar: ackCharacteristic,
                      dataChar: dataCharacteristic,
                      onDisconnectPressed: () async {
                        isStopped = true;
                        ackCharacteristic.write(utf8.encode("0"));
                        device.disconnect();
                      },
                      onAutoPressed: () async {
                        var read = "";
                        const timeDelta = Duration(milliseconds: 10);
                        var initTimestamp = utf8
                            .decodeStream(dataCharacteristic.read().asStream())
                            .toString();

                        initTime = initTimestamp;
                        Timer.periodic(timeDelta, (Timer t) async {
                          if (isStopped) {
                            t.cancel();
                          }

                          ackCharacteristic.write(_ackBytes(),
                              withoutResponse: false);
                          read = utf8
                              .decodeStream(
                                  dataCharacteristic.read().asStream())
                              .toString();

                          if (read.toString().contains("emtpy")) {
                            isStopped = true;
                            ackCharacteristic.write(utf8.encode("0"));
                            device.disconnect();
                          } else {
                            logData(read.toString());
                            print(read.toString);
                            // print("\n");
                            // print(dataBuffer.toString());
                          }
                        });

                        // logData(read);
                        // read;
                        // print(read);
                        //read;
                      },
                    ))
                .toList());
      }
    }
    return Text("MCU Service UUID Not found.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                // Disconnect with Disconnect ACK of "0"
                case BluetoothDeviceState.connected:
                  onPressed = () async {
                    isStopped = true;
                    List<BluetoothService> services =
                        await device.discoverServices();
                    for (var s in services) {
                      if (s.uuid.toString() ==
                          "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
                        var characteristics = s.characteristics;
                        for (var c in characteristics) {
                          if (c.uuid.toString() ==
                              "ad79d3e8-8f69-4086-b0f4-4aa46cf28000") {
                            await c.write(utf8.encode("0"));
                          }
                        }
                      }
                    }

                    device.disconnect();
                  };
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        ?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      const IconButton(
                        icon: SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: const Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return Column(
                  children: [
                    _buildImpactTile(snapshot.data!),
                    Text(initTime),
                    Text(dataText),
                  ],
                  //children: _buildServiceTiles(snapshot.data!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
