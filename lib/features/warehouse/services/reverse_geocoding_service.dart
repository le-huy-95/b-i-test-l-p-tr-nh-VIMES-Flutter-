import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:test_y_app/features/warehouse/warehouse_map_pick_result.dart';

class ReverseGeocodingService {
  ReverseGeocodingService({Geocoding? geocoding})
    : _geocoding = geocoding ?? Geocoding(locale: const Locale('vi', 'VN'));

  final Geocoding _geocoding;

  Future<String> addressFrom({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final marks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (marks.isEmpty) return 'Vị trí đã chọn';
      final place = marks.first;
      final composed = composeWarehouseAddress([
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.country,
      ]);
      return composed.isEmpty ? 'Vị trí đã chọn' : composed;
    } catch (_) {
      return 'Vị trí đã chọn';
    }
  }
}
