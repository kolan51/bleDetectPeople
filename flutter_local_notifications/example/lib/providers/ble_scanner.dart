// ignore_for_file: strict_raw_type, inference_failure_on_function_return_type

import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:meta/meta.dart';

import '../functions/reactive_state.dart';

class BleScanner implements ReactiveState<BleScannerState> {
  BleScanner({
    required FlutterReactiveBle ble,
    required Function(String message) logMessage,
  })  : _ble = ble,
        _logMessage = logMessage;

  double distanceLimit = 1;
  String log = '';
  final FlutterReactiveBle _ble;
  final void Function(String message) _logMessage;
  final StreamController<BleScannerState> _stateStreamController =
      StreamController<BleScannerState>();

  List<DiscoveredDevice> _devices = <DiscoveredDevice>[];
  Map<String, int> _devicesRssiMap = <String, int>{};

  List<DiscoveredDevice> getDevices() => _devices;
  String getLog() => log;

  Map<String, int> getDevicesRssi() => _devicesRssiMap;

  double setDistanceLimit(double distance) => distanceLimit = distance;
  double getDistanceLimit() => distanceLimit;

  List<DiscoveredDevice> clearDevices() => _devices = <DiscoveredDevice>[];
  Map<String, int> clearDevicesRssi() => _devicesRssiMap = <String, int>{};

  @override
  Stream<BleScannerState> get state => _stateStreamController.stream;

  //List<Uuid> serviceIds argument to filter by service
  void startScan() {
    _logMessage('Start ble discovery');
    _devices = <DiscoveredDevice>[];
    _devicesRssiMap = <String, int>{};
    _subscription?.cancel();
    _subscription = _ble.scanForDevices(withServices: <Uuid>[]).listen(
        (DiscoveredDevice device) {
      final int knownDeviceIndex =
          _devices.indexWhere((DiscoveredDevice d) => d.id == device.id);
      if (knownDeviceIndex >= 0) {
        _devices[knownDeviceIndex] = device;
        _devicesRssiMap.update(device.name, (int value) => device.rssi);
      } else {
        _devices.add(device);
        _devicesRssiMap.putIfAbsent(device.name, () => device.rssi);
      }
      log += '${device.name} ${device.rssi}\n';
      _pushState();
    }, onError: (Object e) => _logMessage('Device scan fails with error: $e'));
    _pushState();
  }

  void _pushState() {
    _stateStreamController.add(
      BleScannerState(
        discoveredDevices: _devices,
        scanIsInProgress: _subscription != null,
      ),
    );
  }

  Future<void> stopScan() async {
    log = '';
    _logMessage('Stop ble discovery');

    await _subscription?.cancel();
    _subscription = null;
    _pushState();
  }

  Future<void> dispose() async {
    await _stateStreamController.close();
  }

  StreamSubscription<dynamic>? _subscription;
}

@immutable
class BleScannerState {
  const BleScannerState({
    required this.discoveredDevices,
    required this.scanIsInProgress,
  });

  final List<DiscoveredDevice> discoveredDevices;
  final bool scanIsInProgress;
}
