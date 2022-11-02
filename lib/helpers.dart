import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:firebase_database/firebase_database.dart';

class Utils {
  bool isStopped = false;
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

    ret["HR"] = int.parse(data[10]);
    return ret;
  }

  void deviceReadWrite(
      BluetoothDevice device,
      BluetoothService mcuService,
      BluetoothCharacteristic dataCharacteristic,
      FirebaseDatabase database,
      String initTime,
      Map<String, List<String>> helmetBuffer) async {
    var read = "";
    const timeDelta = Duration(milliseconds: 5);

    var initRelTime = "";
    DateTime initAbsTime = DateTime.now();
    var initTimestamp = "";

    initTime = initTimestamp;
    Timer.periodic(timeDelta, (Timer t) async {
      // Begin time-based loop with timeDelta above. Break if isStopped == True
      if (isStopped) {
        t.cancel();
      }

      // Read the current value of the data characteristic
      read = utf8
          // maybe try .value! instead of lastValue (not sure what this does)
          .decode(dataCharacteristic.lastValue)
          .toString();

      // Split the read value, delimited by commas
      var readSplit = read.split(",");

      // Init current timestamp to ""
      var timeStamp = "";

      if (device.name.toString().contains("!")) {
        // we have an impact, highest priroity interrupt (more than disconnect)
        // current handling: write to impacts sheet in DB with timestamp, serviceUUID
        var writeRef =
            database.ref('impact/impacts/${mcuService.uuid.toString()}/');
        var currTime = initAbsTime.add(Duration(
            milliseconds: int.parse(readSplit[0]) - int.parse(initRelTime)));
        timeStamp = cleanDateTime(currTime);
        writeRef.update({timeStamp: "1"});
      }

      // If we've reached the end of the queue, disconnect
      if (read.toString().toLowerCase().contains("emtpy")) {
        isStopped = true;

        // Write helmet buffer to D

        // assuming helmetBuffer is Map<timeStamp, packet>, m
        // for each timestamp (t) in buffer:
        // await writeRef.update({t: m[t]})
        device.disconnect();
      }

      // If we see a split length of 1, it means we're at the first packet
      //  this means we're seeing the boot timestamp, save it.
      if (readSplit.length == 1) {
        initRelTime = readSplit[0];
        initAbsTime = DateTime.now();
      }

      // Otherwise, we have a complete packet. set the current actual time =
      //  = (current relative timestamp - init relative timestamp) + init absolute time
      // if (readSplit.length > 1) {
      else {
        var currTime = initAbsTime.add(Duration(
            milliseconds: int.parse(readSplit[0]) - int.parse(initRelTime)));

        // Clean it up into a format that firebase accepts
        timeStamp = cleanDateTime(currTime);
        // Add timestamp to buffer
        helmetBuffer[timeStamp] = readSplit.sublist(1);

        // use packetize function to map values to a json-friendly format
        var packet = packetize(readSplit);

        // Write to the database!
        var writeRef = database.ref('impact/${mcuService.uuid.toString()}/');
        await writeRef.update({timeStamp: packet});
      }
    });
  }
}
