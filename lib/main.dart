//geolocator 버전

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // runApp 실행 이전이면 필요

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
  // 위치 권한 상태
  late LocationPermission _locationPermission;

  // 위치 정보 스트림 구독
  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  // 위치 정보 구독중
  bool _locationListening = false;

  // ===== 블루투스 관련 필드 ===============

  // 목표 서비스 UUID
  final String targetServiceUUID = "asdf";

  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  List<ScanResult> _scanResults = [];

  // BLE 준비됨
  bool _bleListening = false;

  // BLE 연결됨
  bool _bleConnected = false;

  // ===== 필드 끝 ========================

  // 위치 권한 요청
  Future<void> _handleLocationPermission() async {
    // 위치 서비스(GPS) 활성화 확인 및 요청
    bool serviceEnabled;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    log(name: "디버그", "위치 권한 서비스 활성화: $serviceEnabled");
    if (!serviceEnabled) {
      return;
    }

    // 위치 권한 확인 및 요청
    _locationPermission = await Geolocator.requestPermission();
    log(name: "디버그", "위치 권한 상태: $_locationPermission");

    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await Geolocator.requestPermission();
      if (_locationPermission == LocationPermission.always ||
          _locationPermission == LocationPermission.whileInUse) {
        log(name: "디버그", "위치 권한 거부");
        return;
      }
    }
    log(name: "디버그", "위치 권한 영구 거부");
    return;
  }

  // 위치 정보 수신 시작/중지 토글
  Future<void> _toggleLocationListening() async {
    if (_positionSubscription == null) {
      log(name: "디버그", "위치 정보 수신 시작");
      // 위치 변경 감지 스트림 구독 시작
      _positionSubscription = Geolocator.getPositionStream().listen(
        (Position? position) {
          setState(() {
            _locationListening = true;
            _currentPosition = position;
          });

          /* todo
          if(_bleConnected){
            데이타 전송
          }
          */
        },
        onError: (e) {
          log(name: "디버그", "위치 정보 수신 실패");
          setState(() {
            _locationListening = false;
          });
        },
        cancelOnError: true,
      );
    } else {
      log(name: "디버그", "위치 정보 수신 중지");
      _positionSubscription!.cancel();
      _positionSubscription = null;
      setState(() {
        _locationListening = false;
      });
    }
  }

  void _toggleBleListening() {
    if (_scanResultsSubscription == null && _isScanningSubscription == null) {
      log(name: "디버그", "블루투스 정보 수신 시작");
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          if (mounted) {
            setState(() => _scanResults = results);
          }

          /* todo
            해당 디바이스 검색시 연결 후 mtu 설정후
            _bleConnected = true;

           */
        },
        onError: (e) {
          log(name: "디버그", "BLE 스캔 결과 스트림 등록 실패: $e");
          return;
        },
      );

      _isScanningSubscription = FlutterBluePlus.isScanning.listen(
        (state) {},
        onError: (e) {
          log(name: "디버그", "BLE 스캔 스트림 등록 실패: $e");
          return;
        },
      );

      setState(() {
        _bleListening = true;
      });
    } else {
      log(name: "디버그", "위치 정보 수신 중지");
      _scanResultsSubscription!.cancel();
      _isScanningSubscription!.cancel();
      _scanResultsSubscription = null;
      _isScanningSubscription = null;
      setState(() {
        _bleListening = false;
      });
    }
  }

  // BLE 기기 검색 시작
  Future<void> _runBleScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    _scanResults.clear();

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

  @override
  Widget build(BuildContext context) {
    // ===== 지도 관련 필드 ===================
    final safeAreaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [DrawerHeader(child: Text('순서대로 누르세요'))],
        ),
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          contentPadding: safeAreaPadding,
          // 화면의 SafeArea에 중요 지도 요소가 들어가지 않도록 설정하는 Padding. 필요한 경우에만 사용하세요.
          initialCameraPosition: NCameraPosition(
            target: NLatLng(0, 0),
            zoom: 14,
          ),
          locationButtonEnable: true,
        ),
        onMapReady: (controller) async {
            NLatLng? myLocation = await controller.myLocationTracker
                .startLocationService();
            controller.updateCamera(
              NCameraUpdate.withParams(target: myLocation),
            );
            final marker = NMarker(
              id: "my_location", // Required
              position: myLocation ?? NLatLng(0, 0), // Required
              caption: NOverlayCaption(text: "현재 위치"), // Optional
            );
            controller.addOverlay(marker);
          },
        onMapTapped: (nPoint, nLatLng) {},
      ),
      // body: SingleChildScrollView(
      //   child: Center(
      //     child: Column(
      //       spacing: 16,
      //       mainAxisAlignment: MainAxisAlignment.center,
      //       children: [
      //         TextButton(
      //           onPressed: _handleLocationPermission,
      //           child: const Text("1. 위치 권한 요청"),
      //         ),
      //         TextButton(
      //           onPressed: _toggleLocationListening,
      //           child: Text("2. 위치 정보 수신 ${_locationListening ? "중지" : "시작"}"),
      //         ),
      //         Text(
      //           "3. 위치 데이터: "
      //           "${_currentPosition != null ? "${_currentPosition!.latitude}, ${_currentPosition!.longitude}" : "없음"}",
      //         ),
      //         TextButton(
      //           onPressed: _toggleBleListening,
      //           child: Text("4. BLE 정보 수신 준비 ${_bleListening ? "중지" : "시작"}"),
      //         ),
      //         TextButton(onPressed: _runBleScan, child: Text("5. BLE 검색 시작")),
      //         TextButton(onPressed: _tryBleConnect, child: Text("6. BLE 연결 상태: ${_bleConnected ? "연결됨" : "미연결"}"),),
      //         Text("7. 검색 결과: ${_scanResults.toString()}"),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }

  @override
  void dispose() {
    // 위젯 종료 시 구독 취소
    _positionSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showAlertDialog({
    required BuildContext context,
    required String title,
    required String content,
    VoidCallback? onPressed,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
                onPressed?.call();
              },
            ),
          ],
        );
      },
    );
  }
}
