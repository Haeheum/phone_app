import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phone_app/manager/bluetooth_manager.dart';

class LocationManager {
  static final LocationManager instance = LocationManager._internal();

  factory LocationManager() => instance;

  LocationManager._internal();

  // 위치 추적기 인스턴스
  final NDefaultMyLocationTracker _myLocationTracker =
      NDefaultMyLocationTracker(onPermissionDenied: (isForeverDenied) {});

  // 위치 권한 상태
  final ValueNotifier<bool> hasLocationPermission = ValueNotifier(false);

  // 현재 위치 스트림
  StreamSubscription<NLatLng>? _locationTrackSubscription;

  // 마지막 위치
  NLatLng? _lastKnownLocation;

  // 위치 권한 요청
  Future<void> requestPermission() async {
    await _myLocationTracker.requestLocationPermission().then((
      locationPermissionStatus,
    ) {
      if (locationPermissionStatus ==
          NDefaultMyLocationTrackerPermissionStatus.granted) {
        hasLocationPermission.value = true;
        startTracking();
      } else {
        hasLocationPermission.value = false;
      }
    });
  }

  // 위치 추적 시작
  void startTracking() {
    _locationTrackSubscription = _myLocationTracker.locationStream.listen((
      location,
    ) {
      if (_lastKnownLocation == location) {
        return;
      }
      _lastKnownLocation = location;
      log(name: "위치", "(${location.latitude}, ${location.longitude})");
      if (BluetoothManager.instance.isBleConnected.value) {
        // todo : 블루투스로 현재 좌표 전송
      }
    });
  }

  // 리소스 해제
  void dispose() {
    _locationTrackSubscription?.cancel();
  }
}
