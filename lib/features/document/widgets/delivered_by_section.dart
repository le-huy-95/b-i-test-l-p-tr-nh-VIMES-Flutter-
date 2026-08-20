import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/select_field.dart';
import 'package:test_y_app/features/document/widgets/partner_select_dialog.dart';

class DeliveredBySection extends StatelessWidget {
  const DeliveredBySection({
    super.key,
    required this.contactId,
    required this.contactOptions,
    required this.onContactSelected,
    required this.onCreatePressed,
    this.onBeforeOpen,
  });

  final String? contactId;
  final List<PartnerSelectDialogItem> contactOptions;
  final ValueChanged<String?> onContactSelected;
  final VoidCallback onCreatePressed;
  final Future<List<PartnerSelectDialogItem>> Function()? onBeforeOpen;

  @override
  Widget build(BuildContext context) {
    final isEmpty = contactOptions.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelectField<PartnerSelectDialogItem>(
          label: 'Người giao hàng',
          value: contactId,
          hint: isEmpty ? 'Chưa có người giao hàng' : 'Chọn người giao hàng',
          bottomSheetTitle: 'Người giao hàng',
          searchHint: 'Tìm theo tên, SĐT, công ty',
          items: contactOptions,
          actionLabel: 'Thêm người giao hàng',
          onAction: onCreatePressed,
          onBeforeOpen: onBeforeOpen,
          onChanged: onContactSelected,
        ),
        if (isEmpty) ...[
          const SizedBox(height: 8),
          AppButton(
            label: 'Thêm người giao hàng',
            onPressed: onCreatePressed,
            variant: AppButtonVariant.outlined,
            icon: const Icon(Icons.person_add_outlined, size: 18),
          ),
        ],
      ],
    );
  }
}
