import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';

abstract final class OverviewCardMetrics {
  static const double bodyHeight = 168;
}

class OverviewChartFilterProps {
  const OverviewChartFilterProps({
    required this.dateRangeLabel,
    required this.onFilterTap,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final String dateRangeLabel;
  final VoidCallback onFilterTap;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
}

class OverviewChartCard extends StatelessWidget {
  const OverviewChartCard({
    super.key,
    required this.title,
    required this.child,
    this.unit,
    this.unitAboveTitle = false,
    this.trailing,
    this.filter,
    this.bodyHeight = OverviewCardMetrics.bodyHeight,
  });

  final String title;
  final String? unit;
  final bool unitAboveTitle;
  final Widget? child;
  final Widget? trailing;
  final OverviewChartFilterProps? filter;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final hasUnit = unit != null;
    final unitStyle = const TextStyle(
      fontSize: 11,
      height: 1.15,
      fontWeight: FontWeight.w500,
      color: ColorSkin.subtitle,
    );
    final titleStyle = const TextStyle(
      fontSize: 15,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: ColorSkin.title,
    );
    final filterProps = filter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUnit && unitAboveTitle) ...[
                    Text(
                      unit!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: unitStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ] else ...[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    if (hasUnit && !unitAboveTitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Đơn vị: $unit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: unitStyle,
                      ),
                    ],
                  ],
                  if (filterProps != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      filterProps.dateRangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                        color: ColorSkin.subtitle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (filterProps != null || trailing != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filterProps != null)
                    _OverviewFilterButton(onTap: filterProps.onFilterTap),
                  if (filterProps != null && trailing != null)
                    const SizedBox(width: 4),
                  ?trailing,
                ],
              ),
          ],
        ),
        if (filterProps?.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            filterProps!.errorMessage!,
            style: const TextStyle(fontSize: 12, color: ColorSkin.error),
          ),
          if (filterProps.onRetry != null) ...[
            const SizedBox(height: 8),
            AppButton(
              label: 'Thử lại',
              variant: AppButtonVariant.outlined,
              height: 36,
              onPressed: filterProps.onRetry,
            ),
          ],
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: bodyHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              if (filterProps?.isLoading ?? false)
                Container(
                  alignment: Alignment.center,
                  color: ColorSkin.white.withValues(alpha: 0.72),
                  child: const CircularProgressIndicator(
                    color: ColorSkin.primary,
                    strokeWidth: 2.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewFilterButton extends StatelessWidget {
  const _OverviewFilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorSkin.tealLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.calendar_month_outlined,
            size: 20,
            color: ColorSkin.primary,
          ),
        ),
      ),
    );
  }
}

class OverviewLegendDot extends StatelessWidget {
  const OverviewLegendDot({
    super.key,
    required this.color,
    required this.label,
    this.value,
  });

  final Color color;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          value == null ? label : '$label · $value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: ColorSkin.subtitle,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class OverviewEmptyChart extends StatelessWidget {
  const OverviewEmptyChart(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: ColorSkin.subtitle, fontSize: 13),
      ),
    );
  }
}

Color overviewStatusColor(String status) {
  return switch (status) {
    'completed' => ColorSkin.primary,
    'pending_approval' => ColorSkin.secondary1,
    'draft' => ColorSkin.subtitle,
    'approved' => ColorSkin.primarySub,
    'rejected' => ColorSkin.error,
    'cancelled' => ColorSkin.subtitle.withValues(alpha: 0.55),
    _ => ColorSkin.border1,
  };
}

String overviewStatusLabel(String status) {
  return switch (status) {
    'completed' => 'Hoàn tất',
    'pending_approval' => 'Chờ duyệt',
    'draft' => 'Nháp',
    'approved' => 'Đã duyệt',
    'rejected' => 'Từ chối',
    'cancelled' => 'Đã hủy',
    _ => status,
  };
}
