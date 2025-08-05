import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phone_app/view/naver_map_widget.dart';
import 'package:phone_app/view/show_current_warning_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterNaverMap().init(
    clientId: 'g34s5gobge',
    onAuthFailed: (ex) {
      switch (ex) {
        case NQuotaExceededException(:final message):
          log(name: "디버그", "사용량 초과 : $message");
          break;
        case NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException():
          log(name: "디버그", "인증 실패 : $ex");
          break;
      }
    },
  );
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ===== 위치 관련 필드 ===================
  final NDefaultMyLocationTracker _nDefaultMyLocationTracker =
      NDefaultMyLocationTracker();

  // 위치 권한 허용 여부
  final ValueNotifier<bool> _hasLocationPermission = ValueNotifier(false);

  // 현재 위치 상태 구독
  StreamSubscription<NLatLng>? _locationTrackSubscription;

  // 마지막 위치
  NLatLng? _lastKnownLocation;

  // ===== 블루투스 관련 필드 ===============
  // 목표 서비스 UUID
  final String targetServiceUUID = "asdf";

  // 블루투스 On/Off 상태 구독
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;

  // 블루투스 스캔 중 상태 구독
  StreamSubscription<bool>? _isScanningSubscription;

  // 블루투스 스캔 결과물 상태 구독
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  // 블루투스 스캔 결과물
  List<ScanResult> _scanResults = [];

  // BLE On/Off 여부
  final ValueNotifier<bool> _isBleOn = ValueNotifier(false);

  // BLE 스캔중 여부
  final ValueNotifier<bool> _isBleScanning = ValueNotifier(false);

  // BLE 연결됨
  bool _bleConnected = false;

  // ===== 필드 끝 ========================

  // BLE 기기 검색 시작
  Future<void> _runBleScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    _scanResults.clear();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() => _scanResults = results);
      }
    });
    FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);

    try {
      await FlutterBluePlus.startScan(
        androidUsesFineLocation: true,
        timeout: const Duration(seconds: 15),
        withNames: [
          // todo
        ],
        withServices: [
          // Guid("180f"), // todo
        ],
      );
    } catch (e) {
      log(name: "디버그", "BLE 검색 실패: $e");
      return;
    }
  }

  //BLE 연결 시도
  Future<void> _tryBleConnect() async {
    BluetoothDevice device = _scanResults
        .firstWhere((scanResult) => scanResult.device.platformName == "")
        .device;
    await device.connect(
      timeout: const Duration(seconds: 35),
      mtu: 50,
      autoConnect: true,
    );
    device.connectionState.listen((connectionState) {
      if (connectionState == BluetoothConnectionState.connected) {
        _bleConnected = true;
      } else {
        _bleConnected = false;
      }
    });
  }

  void _requestLocationPermission() async {
    NDefaultMyLocationTrackerPermissionStatus permissionStatus =
        await _nDefaultMyLocationTracker.requestLocationPermission();
    if (permissionStatus == NDefaultMyLocationTrackerPermissionStatus.granted) {
      _hasLocationPermission.value = true;
      _locationTrackSubscription = _nDefaultMyLocationTracker.locationStream
          .listen((myNLatLng) {
            if (_lastKnownLocation == myNLatLng) {
              return;
            }
            _lastKnownLocation = myNLatLng;

            log(name: "위치", "(${myNLatLng.latitude}, ${myNLatLng.longitude})");
            if (_bleConnected) {
              // todo : 블루투스로 현재 좌표 전송
            }
          });
    }
  }

  void _requestBlePermission() async {
    await FlutterBluePlus.turnOn();
  }

  @override
  void initState() {
    super.initState();

    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((
      bleState,
    ) {
      if (bleState == BluetoothAdapterState.on) {
        _isBleOn.value = true;
      } else {
        _isBleOn.value = false;
        _requestBlePermission();
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isBleScanning.value = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    _requestLocationPermission();

    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [DrawerHeader(child: Text('순서대로 누르세요'))],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: _hasLocationPermission,
        builder: (_, hasLocationPermission, _) {
          return hasLocationPermission
              ? ValueListenableBuilder(
                  valueListenable: _isBleOn,
                  builder: (_, isBleOn, _) {
                    return isBleOn
                        ? NaverMapWidget()
                        : ShowCurrentWarning(
                            message: '블루투스가 꺼져 있어요',
                            onPressed: _requestBlePermission,
                          );
                  },
                )
              : ShowCurrentWarning(
                  message: '위치 권한이 필요해요',
                  onPressed: _requestLocationPermission,
                );
        },
      ),
    );
  }

  @override
  void dispose() {
    // 위젯 종료 시 구독 취소
    _bluetoothStateSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _locationTrackSubscription?.cancel();

    super.dispose();
  }
}
