import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class BluetoothManager {
  static final BluetoothManager instance = BluetoothManager._internal();

  factory BluetoothManager() => instance;

  BluetoothManager._internal();

  // 목표 서비스 UUID
  static const String targetServiceUUID =
      "00001819-0000-1000-8000-00805F9B34FB";
  static const String currentCharacteristicUUID =
      "00001819-0000-1000-8000-00805F9B34FC";
  static const String destinationCharacteristicUUID =
      "00001819-0000-1000-8000-00805F9B34FD";

  // 블루투스 On/Off 상태
  final ValueNotifier<bool> isBleOn = ValueNotifier(false);

  // 스캔 중 상태
  final ValueNotifier<bool> isBleScanning = ValueNotifier(false);

  // BLE 연결 상태
  final ValueNotifier<bool> isBleConnected = ValueNotifier(false);

  // 스캔 결과
  final ValueNotifier<List<ScanResult>> scanResults = ValueNotifier([]);

  // 블루투스 상태 및 스캔 상태 구독
  late final StreamSubscription<BluetoothAdapterState>
  _bluetoothStateSubscription;
  late final StreamSubscription<bool> _isScanningSubscription;

  // 대상 기기 서비스
  List<BluetoothService> services = [];

  // 초기화 (initState에서 호출)
  void initialize() {
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      log(name: "디버그", "블루투스 상태 : $state");
      isBleOn.value = state == BluetoothAdapterState.on;
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      isBleScanning.value = state;
    });
  }

  // 블루투스 켜기 (권한 요청)
  Future<void> turnOn() async {
    await FlutterBluePlus.turnOn();
  }

  // BLE 기기 검색 시작
  Future<void> startScan() async {
    await stopScan();
    scanResults.value = [];
    final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults.value = results.toList();
    });
    FlutterBluePlus.cancelWhenScanComplete(scanSubscription);

    try {
      await FlutterBluePlus.startScan(
        androidUsesFineLocation: true,
        timeout: const Duration(seconds: 15),
        withServices: [
          Guid(targetServiceUUID)
        ],
      );
    } catch (e) {
      log(name: "블루투스", "스캔 실패: $e");
    }
  }

  // BLE 기기 검색 취소
  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  // BLE 기기 연결 시도
  Future<void> tryConnect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 35));
      device.connectionState.listen((connectionState) async {
        services = await device.discoverServices();
        isBleConnected.value =
            connectionState == BluetoothConnectionState.connected;
      });
    } catch (e) {
      log(name: "블루투스", "연결 실패: $e");
    }
  }

  Future<void> sendCurrentLocation(NLatLng currentLocation) async {
    BluetoothService myService = services.firstWhere((s) {
      return s.uuid.toString().contains("1819");
    });

    String data = "${currentLocation.latitude},${currentLocation.longitude}";

    BluetoothCharacteristic c = myService.characteristics.firstWhere((c) {
      log(name: "현재위치전송", "UUID: ${c.uuid}, data: $data");
      return c.uuid == Guid(currentCharacteristicUUID);
    });
    c.write(stringToListInt(data), withoutResponse: true);
  }

  Future<void> sendDestination(NLatLng destination) async {
    debugPrint("services: $services}");
    BluetoothService myService = services.firstWhere((s) {
      return s.uuid.toString().contains("1819");
    });

    String data = "${destination.latitude},${destination.longitude}";

    BluetoothCharacteristic c = myService.characteristics.firstWhere((c) {
      log(name: "목적지위치전송", "UUID: ${c.uuid}, data: $data");
      return c.uuid == Guid(destinationCharacteristicUUID);
    });
    c.write(stringToListInt(data), withoutResponse: true);
  }

  // 리소스 해제
  void dispose() {
    _bluetoothStateSubscription.cancel();
    _isScanningSubscription.cancel();
  }

  List<int> stringToListInt(String input) {
    return utf8.encode(input);
  }
}
