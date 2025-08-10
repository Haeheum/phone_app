import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phone_app/manager/bluetooth_manager.dart';
import 'package:phone_app/manager/location_manager.dart';

class NaverMapWidget extends StatelessWidget {
  const NaverMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final safeAreaPadding = MediaQuery.paddingOf(context);
    NaverMapController? mapController;

    return NaverMap(
      options: NaverMapViewOptions(
        contentPadding: safeAreaPadding,
        initialCameraPosition: NCameraPosition(target: NLatLng(0, 0), zoom: 14),
        locationButtonEnable: true,
      ),
      onMapReady: (controller) async {
        mapController = controller;

        NLatLng? myLocation = await controller.myLocationTracker
            .startLocationService();
        controller.updateCamera(NCameraUpdate.withParams(target: myLocation));

        final marker = NMarker(
          id: "origin", // Required
          position: myLocation ?? NLatLng(0, 0), // Required
          caption: NOverlayCaption(text: "출발지"), // Optional
        );
        controller.addOverlay(marker);
      },
      onMapTapped: (nPoint, nLatLng) {
        final marker = NMarker(
          id: "destination", // Required
          position: nLatLng, // Required
          caption: NOverlayCaption(text: "목적지"), // Optional
        );
        mapController!.addOverlay(marker);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          BluetoothManager.instance.isBleConnected.value
              ? SnackBar(
                  content: Text(
                    'Latitude: ${nLatLng.latitude}\nLongitude: ${nLatLng.longitude}',
                  ),
                  action: SnackBarAction(
                    label: "목적지 전송",
                    onPressed: () async{
                      final lastKnownLocation = LocationManager.instance.lastKnownLocation;
                      if(lastKnownLocation != null){
                        BluetoothManager.instance.sendCurrentLocation(lastKnownLocation);
                      }
                      BluetoothManager.instance.sendDestination(nLatLng);
                    },
                  ),
                )
              : SnackBar(
                  content: Text("블루투스 기기를 연결해 주세요"),
                  showCloseIcon: true,
                ),
        );
      },
    );
  }
}
