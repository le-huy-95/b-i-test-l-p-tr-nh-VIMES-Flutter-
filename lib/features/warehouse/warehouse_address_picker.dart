import 'package:flutter/widgets.dart';
import 'package:test_y_app/features/warehouse/warehouse_map_pick_result.dart';

typedef WarehouseAddressPicker =
    Future<WarehouseMapPickResult?> Function(
      BuildContext context, {
      double? latitude,
      double? longitude,
      String? address,
    });
