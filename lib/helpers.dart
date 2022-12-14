import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:firebase_database/firebase_database.dart';
import 'globals.dart' as globals;

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

  Map<String, num> packetize(List<String> data) {
    Map<String, num> ret = {};

    if (data.length == 1) {
      if (data[0].contains("empty")) {
        return {};
      } else {
        return {"init_time": int.parse(data[0])};
      }
    } else {
      var currAccel = 1;
      for (int i = 1; i < 10; i += 3) {
        ret["x$currAccel"] = double.parse(data[i]);
        ret["y$currAccel"] = double.parse(data[i + 1]);
        ret["z$currAccel"] = double.parse(data[i + 2]);
        ret["magnitude$currAccel"] = sqrt(pow(ret["x$currAccel"]!, 2) +
            pow(ret["y$currAccel"]!, 2) +
            pow(ret["z$currAccel"]!, 2));
        currAccel++;
      }

      if (data.length == 11) {
        ret["hr"] = int.parse(data[10]);
      }

      ret["impact"] = (ret["magnitude1"]! > globals.IMPACT_THRESHOLD ||
              ret["magnitude2"]! > globals.IMPACT_THRESHOLD ||
              ret["magnitude3"]! > globals.IMPACT_THRESHOLD)
          ? 1
          : 0;

      //ret["HR"] = int.parse(data[10]);
      return ret;
    }
  }

  void deviceReadWrite(
      Timer t,
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
      // isStopped = true;
      var writeRef =
          database.ref('IMPACT_BUFFER/${mcuService.uuid.toString()}/');

      for (var r in currBuffer.keys.toList()) {
        writeRef.update({r: currBuffer[r]});
      }

      print(currBuffer);
      currBuffer.clear();

      isStopped = true;
      // t.cancel();
      // device.disconnect();
    }

    // If we see a split length of 1, it means we're at the first packet
    //  this means we're seeing the boot timestamp, save it.
    if (readSplit.length == 1 && !read.toLowerCase().contains("empty")) {
      // initRelTime = readSplit[0];
      // initAbsTime = DateTime.now();
      read = utf8
          // maybe try .value! instead of lastValue (not sure what this does)
          .decode(dataCharacteristic.lastValue)
          .toString();
    }

    var currTime = DateTime.now();
    // Clean it up into a format that firebase accepts
    var timeStamp = cleanDateTime(currTime);

    var packet = packetize(readSplit);
    // currBuffer[timeStamp] = packet;

    var writeRef =
        database.ref('impact_testing_throw/${mcuService.uuid.toString()}/');
    writeRef.update({timeStamp: packet});
  }
}
