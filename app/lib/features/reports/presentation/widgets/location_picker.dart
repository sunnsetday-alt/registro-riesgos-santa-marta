import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../map/widgets/map_layers.dart';

/// Mapa para ubicar el reporte.
///
/// El marcador queda fijo en el centro: el ciudadano arrastra el mapa (o toca
/// un punto) para corregir la ubicación obtenida por GPS.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.position,
    required this.onChanged,
    required this.onLocateMe,
    this.locating = false,
    this.accuracy,
  });

  final LatLng position;
  final ValueChanged<LatLng> onChanged;
  final VoidCallback onLocateMe;
  final bool locating;
  final double? accuracy;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _controller = MapController();
  bool _ready = false;
  LatLng? _lastExternal;

  @override
  void didUpdateWidget(covariant LocationPicker old) {
    super.didUpdateWidget(old);
    // Si la posición cambió desde afuera (GPS), centrar el mapa.
    if (_ready && widget.position != _lastExternal && widget.position != old.position) {
      final center = _controller.camera.center;
      if ((center.latitude - widget.position.latitude).abs() > 1e-6 ||
          (center.longitude - widget.position.longitude).abs() > 1e-6) {
        _controller.move(widget.position, 17);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: SizedBox(
          height: 240,
          child: Stack(children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: widget.position,
                initialZoom: 16,
                minZoom: 11,
                onMapReady: () {
                  _ready = true;
                  // El GPS pudo responder antes de que el mapa estuviera listo.
                  _controller.move(widget.position, 16);
                },
                onTap: (_, latLng) {
                  _controller.move(latLng, _controller.camera.zoom);
                  _emit(latLng);
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) _emit(camera.center);
                },
              ),
              children: [baseTileLayer()],
            ),
            // Marcador fijo en el centro (la punta señala la ubicación).
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.location_on_rounded, size: 48, color: AppColors.coral),
                ),
              ),
            ),
            mapAttribution(),
            Positioned(
              right: 10,
              bottom: 10,
              child: FloatingActionButton.small(
                heroTag: 'locate_me',
                onPressed: widget.locating ? null : widget.onLocateMe,
                backgroundColor: Colors.white,
                child: widget.locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded, color: AppColors.ocean),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.pan_tool_alt_outlined, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Mueve el mapa o toca un punto para ajustar. '
            '${Formatters.coords(widget.position.latitude, widget.position.longitude)}'
            '${widget.accuracy != null ? ' (±${widget.accuracy!.round()} m)' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ]),
    ]);
  }

  void _emit(LatLng p) {
    _lastExternal = p;
    widget.onChanged(p);
  }
}
