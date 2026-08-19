import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/features/warehouse/services/warehouse_map_search_service.dart';

class WarehouseMapSearchResults extends StatelessWidget {
  const WarehouseMapSearchResults({
    super.key,
    required this.results,
    required this.onSelected,
  });

  final List<WarehouseMapSearchResult> results;
  final ValueChanged<WarehouseMapSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: results.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: ColorSkin.grey3),
          itemBuilder: (context, index) {
            final item = results[index];
            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.location_on_outlined,
                color: ColorSkin.primary,
                size: 20,
              ),
              title: Text(
                item.label,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${item.location.latitude.toStringAsFixed(5)}, ${item.location.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () => onSelected(item),
            );
          },
        ),
      ),
    );
  }
}
