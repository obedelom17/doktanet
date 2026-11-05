import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'theme.dart';

/// Carte OpenStreetMap intégrée : une ou plusieurs pharmacies (celles qui ont des coordonnées).
class PharmacyMap extends StatelessWidget {
  final List<dynamic> pharmacies;
  final void Function(dynamic pharmacy)? onTap;
  const PharmacyMap({super.key, required this.pharmacies, this.onTap});

  static LatLng? point(dynamic p) {
    final la = double.tryParse('${p['lat']}');
    final ln = double.tryParse('${p['lng']}');
    if (la == null || ln == null) return null;
    return LatLng(la, ln);
  }

  @override
  Widget build(BuildContext context) {
    final pts = <LatLng>[];
    final markers = <Marker>[];
    for (final p in pharmacies) {
      final pt = point(p);
      if (pt == null) continue;
      pts.add(pt);
      markers.add(Marker(
        point: pt,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: onTap == null ? null : () => onTap!(p),
          child: const Icon(Icons.location_on, color: cAccent, size: 44),
        ),
      ));
    }
    final center = pts.isEmpty ? const LatLng(6.1725, 1.2314) : pts.first;
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: pts.isEmpty ? 12 : 15,
        initialCameraFit: pts.length > 1
            ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(48))
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'tg.doktanet.app',
        ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [TextSourceAttribution('© OpenStreetMap')],
        ),
      ],
    );
  }
}
