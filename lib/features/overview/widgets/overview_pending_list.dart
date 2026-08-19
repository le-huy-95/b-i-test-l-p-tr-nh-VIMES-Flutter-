import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/features/overview/overview_formatters.dart';
import 'package:test_y_app/features/overview/widgets/overview_chart_card.dart';

class OverviewPendingList extends StatelessWidget {
  const OverviewPendingList({super.key, required this.items});

  final List<PendingDocument> items;

  @override
  Widget build(BuildContext context) {
    return OverviewChartCard(
      title: 'Phiếu chờ duyệt',
      child: items.isEmpty
          ? const OverviewEmptyChart('Không có phiếu chờ duyệt')
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) => _PendingTile(item: items[index]),
            ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.item});

  final PendingDocument item;

  @override
  Widget build(BuildContext context) {
    final isReceipt = item.kind == PendingDocumentKind.receipt;
    final meta = [
      if (item.warehouseName != null && item.warehouseName!.isNotEmpty)
        item.warehouseName,
      if (item.partnerName != null && item.partnerName!.isNotEmpty)
        item.partnerName,
      _docTypeLabel(item),
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isReceipt ? ColorSkin.tealLight : ColorSkin.orangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isReceipt ? Icons.move_to_inbox_outlined : Icons.outbox_outlined,
              color: isReceipt ? ColorSkin.primary : ColorSkin.secondary1,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColorSkin.title,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorSkin.subtitle,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isReceipt ? 'Nhập' : 'Xuất',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isReceipt ? ColorSkin.primary : ColorSkin.secondary1,
                ),
              ),
              if (item.totalAmount != null)
                Text(
                  formatVnd(item.totalAmount!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorSkin.subtitle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _docTypeLabel(PendingDocument item) {
  final type = item.type ?? '';
  return switch (type) {
    'purchase' => 'Nhập mua',
    'customer_return' => 'Khách trả',
    'sale' => 'Xuất bán',
    'internal_use' => 'Nội bộ',
    'return_to_supplier' => 'Trả NCC',
    'disposal' => 'Tiêu hủy',
    '' => '',
    _ => type,
  };
}
