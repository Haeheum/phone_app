import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

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
          SnackBar(
            content: Text('Latitude: ${nLatLng.latitude}\nLongitude: ${nLatLng.longitude}'),
            action: SnackBarAction(label: "목적지 전송", onPressed: () {
              // todo : 블루투스로
            }),
          ),
        );
      },
    );
  }

}
