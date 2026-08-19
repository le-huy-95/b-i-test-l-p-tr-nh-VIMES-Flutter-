import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';

class WarehouseMapOverlay extends StatelessWidget {
  const WarehouseMapOverlay({
    super.key,
    required this.address,
    required this.loadingAddress,
    required this.onConfirm,
  });

  final String address;
  final bool loadingAddress;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final effectiveAddress = address.isEmpty
        ? 'Di chuyển bản đồ để chọn vị trí'
        : address;

    return Material(
      color: ColorSkin.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Địa chỉ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ColorSkin.subtitle,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    effectiveAddress,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (loadingAddress) ...[
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColorSkin.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Chọn địa chỉ này',
              variant: AppButtonVariant.primary,
              expand: true,
              isLoading: loadingAddress,
              onPressed: loadingAddress ? null : onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}
