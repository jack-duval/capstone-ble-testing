// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class ScanResultTile extends StatelessWidget {
  const ScanResultTile({Key? key, required this.result, this.onTap})
      : super(key: key);

  final ScanResult result;
  final VoidCallback? onTap;

  Widget _buildTitle(BuildContext context) {
    if (result.device.name.length > 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.device.name,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            result.device.id.toString(),
            style: Theme.of(context).textTheme.caption,
          )
        ],
      );
    } else {
      return Text(result.device.id.toString());
    }
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.caption),
          SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .caption
                  ?.apply(color: Colors.black),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]'
        .toUpperCase();
  }

  String getNiceManufacturerData(Map<int, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add(
          '${id.toRadixString(16).toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  String getNiceServiceData(Map<String, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add('${id.toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: _buildTitle(context),
      leading: Text(result.rssi.toString()),
      trailing: ElevatedButton(
        child: Text('CONNECT'),
        onPressed: (result.advertisementData.connectable) ? onTap : null,
      ),
      children: <Widget>[
        _buildAdvRow(
            context, 'Complete Local Name', result.advertisementData.localName),
        _buildAdvRow(context, 'Tx Power Level',
            '${result.advertisementData.txPowerLevel ?? 'N/A'}'),
        _buildAdvRow(context, 'Manufacturer Data',
            getNiceManufacturerData(result.advertisementData.manufacturerData)),
        _buildAdvRow(
            context,
            'Service UUIDs',
            (result.advertisementData.serviceUuids.isNotEmpty)
                ? result.advertisementData.serviceUuids.join(', ').toUpperCase()
                : 'N/A'),
        _buildAdvRow(context, 'Service Data',
            getNiceServiceData(result.advertisementData.serviceData)),
      ],
    );
  }
}

class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<CharacteristicsTile> characteristicTiles;

  const ServiceTile(
      {Key? key, required this.service, required this.characteristicTiles})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (characteristicTiles.length > 0) {
      return ExpansionTile(
        initiallyExpanded: true,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Service'),
            Text('0x${service.uuid.toString().toUpperCase().substring(4, 8)}',
                style: Theme.of(context).textTheme.bodyText1?.copyWith(
                    color: Theme.of(context).textTheme.caption?.color))
          ],
        ),
        children: characteristicTiles,
      );
    } else {
      return ListTile(
        title: Text('Service'),
        subtitle:
            Text('0x${service.uuid.toString().toUpperCase().substring(4, 8)}'),
      );
    }
  }
}

class CharacteristicsTile extends StatelessWidget {
  final BluetoothCharacteristic dataChar;

  final VoidCallback? onAutoPressed;
  final VoidCallback? onDisconnectPressed;

  const CharacteristicsTile({
    Key? key,
    required this.dataChar,
    required this.onAutoPressed,
    required this.onDisconnectPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
        stream: dataChar.value,
        initialData: dataChar.lastValue,
        builder: (c, snapshot) {
          final value = snapshot.data;
          ;
          return ExpansionTile(
            title: ListTile(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Data Characteristic'),
                  Text('0x${dataChar.uuid.toString().toUpperCase()}',
                      style: Theme.of(context).textTheme.bodyText1?.copyWith(
                          color: Theme.of(context).textTheme.caption?.color))
                ],
              ),
              subtitle: Text(utf8.decode(value!).toString()),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.thumb_up,
                      color:
                          Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                  onPressed: onAutoPressed,
                ),
                IconButton(
                    onPressed: onDisconnectPressed,
                    icon: Icon(Icons.thumb_down),
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
              ],
            ),
          );
        });
  }
}

class CharacteristicModTile extends StatelessWidget {
  final BluetoothCharacteristic char;
  final List<DescriptorTile> descTiles;
  final VoidCallback? onAutoPressed;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;
  final VoidCallback? onNotificationPressed;

  const CharacteristicModTile(
      {Key? key,
      required this.char,
      required this.descTiles,
      required this.onAutoPressed,
      required this.onReadPressed,
      required this.onWritePressed,
      required this.onNotificationPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
        stream: char.value,
        initialData: char.lastValue,
        builder: (c, snapshot) {
          final value = snapshot.data;
          return ExpansionTile(
            title: ListTile(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Characteristic'),
                  Text('0x${char.uuid.toString().toUpperCase()}',
                      style: Theme.of(context).textTheme.bodyText1?.copyWith(
                          color: Theme.of(context).textTheme.caption?.color))
                ],
              ),
              subtitle: Text(utf8.decode(value!).toString()),
              contentPadding: EdgeInsets.all(0.0),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: Icon(
                    Icons.file_download,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                  ),
                  onPressed: onReadPressed,
                ),
                IconButton(
                  icon: Icon(Icons.file_upload,
                      color:
                          Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                  onPressed: onWritePressed,
                ),
                IconButton(
                  icon: Icon(
                      char.isNotifying ? Icons.sync_disabled : Icons.sync,
                      color:
                          Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                  onPressed: onNotificationPressed,
                ),
                IconButton(
                  icon: Icon(Icons.thumb_up,
                      color:
                          Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                  onPressed: onAutoPressed,
                )
              ],
            ),
            children: descTiles,
          );
        });
  }
}

class DescriptorTile extends StatelessWidget {
  final BluetoothDescriptor descriptor;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;

  const DescriptorTile(
      {Key? key,
      required this.descriptor,
      this.onReadPressed,
      this.onWritePressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Descriptor'),
          Text('0x${descriptor.uuid.toString().toUpperCase().substring(4, 8)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  ?.copyWith(color: Theme.of(context).textTheme.caption?.color))
        ],
      ),
      subtitle: StreamBuilder<List<int>>(
        stream: descriptor.value,
        initialData: descriptor.lastValue,
        builder: (c, snapshot) => Text(snapshot.data.toString()),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.file_download,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
            onPressed: onReadPressed,
          ),
          IconButton(
            icon: Icon(
              Icons.file_upload,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
            onPressed: onWritePressed,
          )
        ],
      ),
    );
  }
}

class AdapterStateTile extends StatelessWidget {
  const AdapterStateTile({Key? key, required this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent,
      child: ListTile(
        title: Text(
          'Bluetooth adapter is ${state.toString().substring(15)}',
          style: Theme.of(context).primaryTextTheme.subtitle1,
        ),
        trailing: Icon(
          Icons.error,
          color: Theme.of(context).primaryTextTheme.subtitle1?.color,
        ),
      ),
    );
  }
}
