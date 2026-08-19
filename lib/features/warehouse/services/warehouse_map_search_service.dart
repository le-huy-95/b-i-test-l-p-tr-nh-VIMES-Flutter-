import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:test_y_app/features/warehouse/services/reverse_geocoding_service.dart';

class WarehouseMapSearchResult {
  const WarehouseMapSearchResult({
    required this.location,
    required this.label,
  });

  final geo.Location location;
  final String label;
}

class WarehouseMapSearchService {
  WarehouseMapSearchService({
    geo.Geocoding? geocoding,
    ReverseGeocodingService? reverseGeocodingService,
  })  : _geocoding = geocoding ?? geo.Geocoding(locale: const Locale('vi', 'VN')),
        _reverseGeocodingService =
            reverseGeocodingService ?? ReverseGeocodingService();

  final geo.Geocoding _geocoding;
  final ReverseGeocodingService _reverseGeocodingService;

  Future<List<WarehouseMapSearchResult>> search(String query) async {
    final locations = await _geocoding.locationFromAddress(query);
    final limited = locations.take(5).toList();
    final results = <WarehouseMapSearchResult>[];

    for (final location in limited) {
      final label = await _resolveLabel(location);
      results.add(WarehouseMapSearchResult(location: location, label: label));
    }

    return results;
  }

  Future<String> _resolveLabel(geo.Location location) async {
    try {
      final address = await _reverseGeocodingService.addressFrom(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      final trimmed = address.trim();
      if (trimmed.isNotEmpty && trimmed != 'Vị trí đã chọn') {
        return trimmed;
      }
    } catch (_) {
      // Fall back to coordinates below.
    }
    return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
  }
}
