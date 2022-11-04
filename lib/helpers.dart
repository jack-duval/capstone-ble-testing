import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:firebase_database/firebase_database.dart';

class Utils {
  bool isStopped = false;
  Map<String, Map<String, Object>> currBuffer = {};

  void deviceDisconnect(BluetoothDevice device) async {
    device.disconnect();

    return;
  }

  bool getIsStopped() {
    return isStopped;
  }

  void setIsStopped(bool newVal) {
    isStopped = newVal;
  }

  String cleanDateTime(DateTime t) {
    return "${t.year.toString()}-${t.month.toString()}-${t.day.toString()}-${t.hour.toString()}-${t.minute.toString()}-${t.millisecond.toString()}";
  }

  Map<String, Object> packetize(List<String> data) {
    Map<String, Object> ret = {};

    var currMCU = 1;
    for (int i = 1; i < 10; i += 3) {
      ret["x$currMCU"] = double.parse(data[i]);
      ret["y$currMCU"] = double.parse(data[i + 1]);
      ret["z$currMCU"] = double.parse(data[i + 2]);
      currMCU++;
    }

    //ret["HR"] = int.parse(data[10]);
    return ret;
  }

  void deviceReadWrite(
    BluetoothDevice device,
    BluetoothService mcuService,
    BluetoothCharacteristic dataCharacteristic,
    FirebaseDatabase database,
    String initTime,
    Map<String, List<String>> helmetBuffer,
    bool isStopped) 
  async {
    var read = "";
    // var initRelTime = "";
    // const timeDelta = Duration(milliseconds: 1000);
    var initTimestamp =
        utf8.decodeStream(dataCharacteristic.read().asStream()).toString();

    initTime = initTimestamp;
    // var initAbsTime = DateTime.now();
    // print("is Stopped: ${isStopped}\n");

    read = utf8
        // maybe try .value! instead of lastValue (not sure what this does)
        .decode(dataCharacteristic.lastValue)
        .toString();

    print(read);

    var readSplit = read.split(',');

    // If we've reached the end of the queue, disconnect
    if (read.toString().toLowerCase().contains("emtpy")) {
      isStopped = true;
      // var writeRef =
      //     database.ref('IMPACT_BUFFER/${mcuService.uuid.toString()}/');

      // for (var r in currBuffer.keys) {
      //   writeRef.update({r: currBuffer[r]});
      // }
      // currBuffer.clear();
      // // Write helmet buffer to D

      // // assuming helmetBuffer is Map<timeStamp, packet>, m
      // // for each timestamp (t) in buffer:
      // // await writeRef.update({t: m[t]})
      // isStopped = true;
      device.disconnect();
    }

    // If we see a split length of 1, it means we're at the first packet
    //  this means we're seeing the boot timestamp, save it.
    if (readSplit.length == 1) {
      // initRelTime = readSplit[0];
      // initAbsTime = DateTime.now();
      read = utf8
          // maybe try .value! instead of lastValue (not sure what this does)
          .decode(dataCharacteristic.lastValue)
          .toString();
    }

    var currTime = DateTime.now();

    // var currTime = initAbsTime.add(
    //     Duration(milliseconds: int.parse(readSplit[0]) - int.parse(initRelTime)));

    // Clean it up into a format that firebase accepts
    var timeStamp = cleanDateTime(currTime);

    var packet = packetize(readSplit);

    currBuffer[timeStamp] = packet;

    var writeRef = database.ref('impact/${mcuService.uuid.toString()}/');
    writeRef.update({timeStamp: packet});
  }

  void oldACKlessRW(
      BluetoothDevice device,
      BluetoothService mcuService,
      BluetoothCharacteristic dataCharacteristic,
      FirebaseDatabase database,
      String initTime,
      Map<String, List<String>> helmetBuffer,
      bool isStopped) async {
    var read = "";
    // var initRelTime = "";
    // const timeDelta = Duration(milliseconds: 1000);
    var initTimestamp =
        utf8.decodeStream(dataCharacteristic.read().asStream()).toString();

    initTime = initTimestamp;
    // var initAbsTime = DateTime.now();
    // print("is Stopped: ${isStopped}\n");

    read = utf8
        // maybe try .value! instead of lastValue (not sure what this does)
        .decode(dataCharacteristic.lastValue)
        .toString();

    print(read);

    var readSplit = read.split(',');

    // If we've reached the end of the queue, disconnect
    if (read.toString().toLowerCase().contains("emtpy")) {
      isStopped = true;
      // var writeRef =
      //     database.ref('IMPACT_BUFFER/${mcuService.uuid.toString()}/');

      // for (var r in currBuffer.keys) {
      //   writeRef.update({r: currBuffer[r]});
      // }
      // currBuffer.clear();
      // // Write helmet buffer to D

      // // assuming helmetBuffer is Map<timeStamp, packet>, m
      // // for each timestamp (t) in buffer:
      // // await writeRef.update({t: m[t]})
      // isStopped = true;
      device.disconnect();
    }

    // If we see a split length of 1, it means we're at the first packet
    //  this means we're seeing the boot timestamp, save it.
    if (readSplit.length == 1) {
      // initRelTime = readSplit[0];
      // initAbsTime = DateTime.now();
      read = utf8
          // maybe try .value! instead of lastValue (not sure what this does)
          .decode(dataCharacteristic.lastValue)
          .toString();
    }

    var currTime = DateTime.now();

    // var currTime = initAbsTime.add(
    //     Duration(milliseconds: int.parse(readSplit[0]) - int.parse(initRelTime)));

    // Clean it up into a format that firebase accepts
    var timeStamp = cleanDateTime(currTime);

    var packet = packetize(readSplit);

    currBuffer[timeStamp] = packet;

    var writeRef = database.ref('impact/${mcuService.uuid.toString()}/');
    writeRef.update({timeStamp: packet});
  }
}
