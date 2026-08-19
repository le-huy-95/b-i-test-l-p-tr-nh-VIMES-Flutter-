import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/features/overview/overview_formatters.dart';

class OverviewKpiSection extends StatelessWidget {
  const OverviewKpiSection({super.key, required this.data});

  final OrganizationOverview data;

  @override
  Widget build(BuildContext context) {
    if (data.isOrganizationScope) {
      final inventory = data.inventory;
      return Column(
        children: [
          _HeroMetric(
            label: 'Giá trị tồn kho',
            value: formatVnd(inventory?.estimatedStockValue ?? '0'),
            hint:
                '${inventory?.skuCount ?? 0} SKU · ${data.organization.warehouseCount} kho',
            icon: Icons.account_balance_wallet_outlined,
            tint: ColorSkin.tealLight,
            accent: ColorSkin.primary,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _KpiTile(
                  label: 'Cảnh báo',
                  value: '${data.alertCount}',
                  hint: inventory == null
                      ? ' '
                      : '${inventory.lowStockCount} sắp hết · ${inventory.expiryAlertCount} hết hạn',
                  icon: Icons.warning_amber_rounded,
                  tint: ColorSkin.orangeLight,
                  accent: ColorSkin.secondary1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiTile(
                  label: 'Chờ duyệt',
                  value: '${data.pendingApprovalCount}',
                  hint: ' ',
                  icon: Icons.pending_actions_outlined,
                  tint: ColorSkin.tealLight,
                  accent: ColorSkin.primary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final receipts = data.documents.stockReceipts;
    final issues = data.documents.stockIssues;
    return Column(
      children: [
        _HeroMetric(
          label: 'Phiếu của tôi',
          value: '${data.pendingApprovalCount}',
          hint: 'đang chờ duyệt',
          icon: Icons.pending_actions_outlined,
          tint: ColorSkin.orangeLight,
          accent: ColorSkin.secondary1,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: 'Nháp',
                value: '${receipts.draft + issues.draft}',
                hint: ' ',
                icon: Icons.edit_note_outlined,
                tint: ColorSkin.tealLight,
                accent: ColorSkin.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                label: 'Hoàn tất',
                value: '${receipts.completed + issues.completed}',
                hint: ' ',
                icon: Icons.check_circle_outline,
                tint: ColorSkin.tealLight,
                accent: ColorSkin.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.accent,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorSkin.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorSkin.subtitle,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: ColorSkin.title,
                    ),
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorSkin.subtitle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.accent,
    this.hint = ' ',
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorSkin.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorSkin.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: ColorSkin.subtitle),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ColorSkin.title,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: ColorSkin.subtitle),
          ),
        ],
      ),
    );
  }
}
