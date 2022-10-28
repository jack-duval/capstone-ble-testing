// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:ble_testing/widgets.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

String initTime = "";
String dataText = "";
bool isStopped = false;

List<Guid> serviceUUIDs = [
  Guid("4faf183e-1fb5-459e-8fcc-c5c9c331914b"),
  Guid("4FAFC201-1FB5-459E-8FCC-C5C9C331914B")
  // ...
];

FirebaseDatabase database = FirebaseDatabase.instance;
DatabaseReference ref = database.ref("ble_testing/");

// Team Buffer: List of CSV data, each with Service UUID + Timestamp
// List<String> teamBuffer = new List<>();

// take in a service UUID (unique per MCU)
//  Return its data and ACK UUIDs in a List

// Guid serviceUUID --> <String>[dataUUID, ackUUID]
String getDataCharUUID(Guid serviceUUID) {
  // first split given uuid as a string, delimited by "-"
  var splitUUID = serviceUUID.toString().split("-");

  // the data segment is the first segment of the given UUID, incremented by 1
  var dataSegment = int.parse(splitUUID[0], radix: 16) + 1;

  // return a GUID version of the string, re-joined by "-"
  return "${dataSegment.toRadixString(16)}-${splitUUID.sublist(1).join("-")}";
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        onRefresh: () => FlutterBlue.instance.startScan(
            timeout: Duration(seconds: 4)), //, withServices: serviceUUIDs),
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
                                  return ElevatedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => {
                                      //await d.discoverServices(),
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  DeviceScreen(device: d)))
                                    },
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
                            r.device.discoverServices();
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
                onPressed: () => {
                      FlutterBlue.instance
                          .startScan(timeout: Duration(seconds: 4)),
                      //withServices: serviceUUIDs),
                      database
                          .ref('ble_testing/latest_scan')
                          .set(DateTime.now().toString()),
                    });
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  String cleanDateTime(DateTime t) {
    return "${t.year.toString()}-${t.month.toString()}-${t.day.toString()}-${t.hour.toString()}-${t.minute.toString()}-${t.millisecond.toString()}";
  }

  Widget _buildImpactTile(List<BluetoothService> services) {
    BluetoothService mcuService;
    for (int i = 0; i < services.length; i++) {
      if (services[i].uuid == serviceUUIDs[1]) {
        mcuService = services[i];
        var dataCharacteristicUUID = Guid(getDataCharUUID(mcuService.uuid));

        var dataCharacteristic = mcuService.characteristics
            .singleWhere((c) => c.uuid == dataCharacteristicUUID);
        return ServiceTile(
            service: mcuService,
            characteristicTiles: [
              mcuService.characteristics
              //.singleWhere((c) => c.uuid == dataCharacteristicUUID)
            ]
                .map((c) => CharacteristicsTile(
                      dataChar: dataCharacteristic,
                      onDisconnectPressed: () async {
                        isStopped = true;
                        device.disconnect();
                      },
                      onAutoPressed: () async {
                        var read = "";
                        const timeDelta = Duration(milliseconds: 5);
                        var initRelTime = "";
                        DateTime initAbsTime;
                        var initTimestamp = "";

                        initTime = initTimestamp;
                        Timer.periodic(timeDelta, (Timer t) async {
                          if (isStopped) {
                            t.cancel();
                          }
                          read = utf8
                              // maybe try .value! instead of lastValue (not sure what this does)
                              .decode(dataCharacteristic.lastValue)
                              .toString();
                          initAbsTime = DateTime.now();

                          var readSplit = read.split(",");
                          var timeStamp = "";

                          if (read.toString().toLowerCase().contains("emtpy")) {
                            isStopped = true;
                            device.disconnect();
                          }

                          if (readSplit.length == 1) {
                            initRelTime = readSplit[0];
                            //"${now.year.toString()}-${now.month.toString()}-${now.day.toString()}-${now.hour.toString()}-${now.minute.toString()}-${now.millisecond.toString()}";
                          }

                          if (readSplit.length > 1) {
                            var currTime = initAbsTime.add(Duration(
                                milliseconds: int.parse(readSplit[0]) -
                                    int.parse(initRelTime)));
                            timeStamp = cleanDateTime(currTime);
                          }

                          var writeRef = database.ref('ble_testing/$timeStamp');
                          await writeRef
                              .set({"data": readSplit.sublist(1).toString()});
                        });
                      },
                    ))
                .toList());
      }
    }
    return const Text("MCU Service UUID Not found.");
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
                case BluetoothDeviceState.connected:
                  onPressed = () {
                    isStopped = true;
                    device.disconnect();
                  };
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () {
                    device.connect();
                  };
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return TextButton(
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
