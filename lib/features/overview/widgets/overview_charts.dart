import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/features/overview/overview_formatters.dart';
import 'package:test_y_app/features/overview/widgets/overview_chart_card.dart';

const _kDocumentUnit = 'phiếu';

const _axisTickStyle = TextStyle(fontSize: 10, color: ColorSkin.subtitle);
const _xLabelStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w600,
  color: ColorSkin.subtitle,
);

final _chartBorder = FlBorderData(show: false);

double _yInterval(double maxY) => maxY <= 0 ? 1 : maxY / 4;

double _yMax(double maxY) => maxY <= 0 ? 1 : maxY * 1.2;

bool _showYTick(double value, double maxY) {
  if (value < -0.001) return false;
  return value <= _yMax(maxY) + 0.001;
}

Widget _yTickLabel(double value) {
  if (value.abs() < 0.001) {
    return const Text('0', style: _axisTickStyle);
  }
  return Text(_compact(value), style: _axisTickStyle);
}

FlGridData _overviewGrid(double maxY) => FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: _yInterval(maxY),
  getDrawingHorizontalLine: (_) =>
      FlLine(color: ColorSkin.grey3, strokeWidth: 1),
);

AxisTitles _overviewLeftAxis({
  required double maxY,
  double reservedSize = 36,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: reservedSize,
      interval: _yInterval(maxY),
      getTitlesWidget: (value, meta) {
        if (!_showYTick(value, maxY)) return const SizedBox.shrink();
        return _yTickLabel(value);
      },
    ),
  );
}

AxisTitles _overviewBottomAxis({
  required List<String> labels,
  double reservedSize = 26,
  bool skipOddWhenMany = false,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: labels.isNotEmpty,
      reservedSize: reservedSize,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.round();
        if (value != index.toDouble() || index < 0 || index >= labels.length) {
          return const SizedBox.shrink();
        }
        if (skipOddWhenMany && labels.length > 14 && index.isOdd) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            labels[index],
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _xLabelStyle,
          ),
        );
      },
    ),
  );
}

/// Biến động nhập / xuất — column chart 2 cột / ngày (30 ngày).
class OverviewMovementDailyColumnChart extends StatelessWidget {
  const OverviewMovementDailyColumnChart({
    super.key,
    required this.movement,
    this.filter,
  });

  final ProductMovement movement;
  final OverviewChartFilterProps? filter;

  @override
  Widget build(BuildContext context) {
    final days = movement.resolvedDailyMovement;

    return OverviewChartCard(
      title: 'Biến động Nhập / xuất',
      bodyHeight: 240,
      filter: filter,
      child: days.isEmpty
          ? const OverviewEmptyChart('Chưa có biến động trong khoảng thời gian')
          : _DailyMovementColumnChart(days: days),
    );
  }
}

/// Phiếu chờ duyệt — column chart.
class OverviewPendingColumnChart extends StatelessWidget {
  const OverviewPendingColumnChart({
    super.key,
    required this.data,
    this.filter,
  });

  final OrganizationOverview data;
  final OverviewChartFilterProps? filter;

  @override
  Widget build(BuildContext context) {
    final receiptPending = data.documents.stockReceipts.pendingApproval
        .toDouble();
    final issuePending = data.documents.stockIssues.pendingApproval.toDouble();

    return OverviewChartCard(
      title: 'Chờ duyệt',
      filter: filter,
      child: receiptPending <= 0 && issuePending <= 0
          ? const OverviewEmptyChart('Không có phiếu chờ duyệt')
          : _DualColumnChart(
              labels: const ['Phiếu nhập', 'Phiếu xuất'],
              values: [receiptPending, issuePending],
              colors: const [ColorSkin.primary, ColorSkin.secondary1],
              unit: _kDocumentUnit,
            ),
    );
  }
}

/// Top sản phẩm — column chart, toggle Nhập / Xuất (một loại mỗi lần).
class OverviewTopProductsColumnChart extends StatefulWidget {
  const OverviewTopProductsColumnChart({
    super.key,
    required this.movement,
    this.filter,
  });

  final ProductMovement movement;
  final OverviewChartFilterProps? filter;

  @override
  State<OverviewTopProductsColumnChart> createState() =>
      _OverviewTopProductsColumnChartState();
}

class _OverviewTopProductsColumnChartState
    extends State<OverviewTopProductsColumnChart> {
  late bool _imported;

  @override
  void initState() {
    super.initState();
    _imported = widget.movement.topImportedProducts.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant OverviewTopProductsColumnChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasImported = widget.movement.topImportedProducts.isNotEmpty;
    final hasExported = widget.movement.topExportedProducts.isNotEmpty;
    if (_imported && !hasImported && hasExported) {
      _imported = false;
    } else if (!_imported && !hasExported && hasImported) {
      _imported = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImported = widget.movement.topImportedProducts.isNotEmpty;
    final hasExported = widget.movement.topExportedProducts.isNotEmpty;
    final products = _imported
        ? widget.movement.topImportedProducts
        : widget.movement.topExportedProducts;
    final color = _imported ? ColorSkin.primary : ColorSkin.secondary1;
    final legendLabel = _imported ? 'Nhập' : 'Xuất';

    return OverviewChartCard(
      title: 'Top sản phẩm',
      bodyHeight: 240,
      filter: widget.filter,
      trailing: hasImported && hasExported
          ? _SegmentToggle(
              imported: _imported,
              onChanged: (v) => setState(() => _imported = v),
            )
          : null,
      child: products.isEmpty
          ? OverviewEmptyChart(
              _imported ? 'Chưa có sản phẩm nhập' : 'Chưa có sản phẩm xuất',
            )
          : _CategoryColumnChart(
              key: ValueKey(_imported),
              labels: [
                for (final p in products) _shortLabel(p.sku, p.name),
              ],
              values: [
                for (final p in products) double.tryParse(p.totalQty) ?? 0,
              ],
              color: color,
              legendLabel: legendLabel,
            ),
    );
  }
}

/// Nhập / xuất theo kho — column chart 2 cột / kho (org scope).
class OverviewWarehouseColumnChart extends StatelessWidget {
  const OverviewWarehouseColumnChart({
    super.key,
    required this.rows,
    this.filter,
  });

  final List<WarehouseBreakdown> rows;
  final OverviewChartFilterProps? filter;

  @override
  Widget build(BuildContext context) {
    final groups = rows.take(6).toList();
    final labels = [for (final row in groups) row.warehouse.code];
    final imported = [
      for (final row in groups)
        double.tryParse(row.productMovement.totalImportedQty) ?? 0,
    ];
    final exported = [
      for (final row in groups)
        double.tryParse(row.productMovement.totalExportedQty) ?? 0,
    ];
    final hasData = imported.any((v) => v > 0) || exported.any((v) => v > 0);

    return OverviewChartCard(
      title: 'Nhập / xuất theo kho',
      bodyHeight: 240,
      filter: filter,
      child: groups.isEmpty || !hasData
          ? const OverviewEmptyChart('Chưa có biến động theo kho')
          : _GroupedDualColumnChart(
              labels: labels,
              imported: imported,
              exported: exported,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared chart primitives
// ---------------------------------------------------------------------------

class _DailyMovementColumnChart extends StatelessWidget {
  const _DailyMovementColumnChart({required this.days});

  final List<DailyMovementPoint> days;

  static const _slotWidth = 40.0;
  static const _barWidth = 8.0;
  static const _barsSpace = 3.0;
  static const _yAxisWidth = 32.0;

  @override
  Widget build(BuildContext context) {
    final imported = [for (final day in days) _parseQty(day.importedQty)];
    final exported = [for (final day in days) _parseQty(day.exportedQty)];
    final labels = [for (final day in days) _formatDayLabel(day.date)];
    final maxY = [
      ...imported,
      ...exported,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    final chartWidth = _yAxisWidth + days.length * _slotWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            OverviewLegendDot(color: ColorSkin.primary, label: 'Nhập'),
            OverviewLegendDot(color: ColorSkin.secondary1, label: 'Xuất'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: chartWidth,
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            minY: 0,
                            maxY: _yMax(maxY),
                            gridData: _overviewGrid(maxY),
                            borderData: _chartBorder,
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(),
                              rightTitles: const AxisTitles(),
                              bottomTitles: const AxisTitles(),
                              leftTitles: _overviewLeftAxis(
                                maxY: maxY,
                                reservedSize: _yAxisWidth,
                              ),
                            ),
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                direction: TooltipDirection.auto,
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                tooltipMargin: 8,
                                tooltipBorderRadius: BorderRadius.circular(8),
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                getTooltipColor: (_) => ColorSkin.title,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final dayLabel = groupIndex < labels.length
                                      ? labels[groupIndex]
                                      : '';
                                  final kind = rodIndex == 0 ? 'Nhập' : 'Xuất';
                                  return BarTooltipItem(
                                    '$dayLabel\n$kind ${formatQty(rod.toY.toString())}',
                                    const TextStyle(
                                      color: ColorSkin.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  );
                                },
                              ),
                            ),
                            barGroups: [
                              for (var i = 0; i < days.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barsSpace: _barsSpace,
                                  barRods: [
                                    BarChartRodData(
                                      toY: imported[i],
                                      width: _barWidth,
                                      color: ColorSkin.primary,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                    BarChartRodData(
                                      toY: exported[i],
                                      width: _barWidth,
                                      color: ColorSkin.secondary1,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 22,
                        child: Padding(
                          padding: const EdgeInsets.only(left: _yAxisWidth),
                          child: Row(
                            children: [
                              for (var i = 0; i < days.length; i++)
                                SizedBox(
                                  width: _slotWidth,
                                  child: days.length > 14 && i.isOdd
                                      ? const SizedBox.shrink()
                                      : Text(
                                          labels[i],
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _xLabelStyle,
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DualColumnChart extends StatelessWidget {
  const _DualColumnChart({
    required this.labels,
    required this.values,
    required this.colors,
    required this.unit,
  });

  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final String unit;

  String _formatValue(double value) => formatCountWithUnit(value, unit);

  @override
  Widget build(BuildContext context) {
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: _yMax(maxY),
        gridData: _overviewGrid(maxY),
        borderData: _chartBorder,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: _overviewLeftAxis(maxY: maxY),
          bottomTitles: _overviewBottomAxis(labels: labels),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => ColorSkin.title,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                _formatValue(rod.toY),
                const TextStyle(
                  color: ColorSkin.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 32,
                  color: colors[i],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryColumnChart extends StatelessWidget {
  const _CategoryColumnChart({
    super.key,
    required this.labels,
    required this.values,
    required this.color,
    required this.legendLabel,
  });

  final List<String> labels;
  final List<double> values;
  final Color color;
  final String legendLabel;

  static const _minSlotWidth = 52.0;
  static const _yAxisWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);
    final count = labels.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final naturalWidth = _yAxisWidth + count * _minSlotWidth;
        final fillsViewport = naturalWidth <= viewportWidth;
        final chartWidth = fillsViewport ? viewportWidth : naturalWidth;
        final slotWidth = count == 0
            ? _minSlotWidth
            : fillsViewport
            ? (viewportWidth - _yAxisWidth) / count
            : _minSlotWidth;
        final barWidth = (slotWidth * 0.52).clamp(22.0, 36.0);

        final chartBody = SizedBox(
          width: chartWidth,
          height: constraints.maxHeight,
          child: Column(
            children: [
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    minY: 0,
                    maxY: _yMax(maxY),
                    gridData: _overviewGrid(maxY),
                    borderData: _chartBorder,
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: const AxisTitles(),
                      leftTitles: _overviewLeftAxis(
                        maxY: maxY,
                        reservedSize: _yAxisWidth,
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        direction: TooltipDirection.auto,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        tooltipMargin: 8,
                        tooltipBorderRadius: BorderRadius.circular(8),
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        getTooltipColor: (_) => ColorSkin.title,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final name = groupIndex < labels.length
                              ? labels[groupIndex]
                              : '';
                          return BarTooltipItem(
                            '$legendLabel · $name\n${formatQty(rod.toY.toString())}',
                            const TextStyle(
                              color: ColorSkin.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < values.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: values[i],
                              width: barWidth,
                              color: color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 22,
                child: Padding(
                  padding: const EdgeInsets.only(left: _yAxisWidth),
                  child: Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        SizedBox(
                          width: slotWidth,
                          child: Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _xLabelStyle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (fillsViewport) {
          return chartBody;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: chartBody,
        );
      },
    );
  }
}

class _GroupedDualColumnChart extends StatelessWidget {
  const _GroupedDualColumnChart({
    required this.labels,
    required this.imported,
    required this.exported,
  });

  final List<String> labels;
  final List<double> imported;
  final List<double> exported;

  static const _minSlotWidth = 52.0;
  static const _barsSpace = 3.0;
  static const _yAxisWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    final maxY = [
      ...imported,
      ...exported,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    final count = labels.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            OverviewLegendDot(color: ColorSkin.primary, label: 'Nhập'),
            OverviewLegendDot(color: ColorSkin.secondary1, label: 'Xuất'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.maxWidth;
              final naturalWidth = _yAxisWidth + count * _minSlotWidth;
              final fillsViewport = naturalWidth <= viewportWidth;
              final chartWidth = fillsViewport ? viewportWidth : naturalWidth;
              final slotWidth = count == 0
                  ? _minSlotWidth
                  : fillsViewport
                  ? (viewportWidth - _yAxisWidth) / count
                  : _minSlotWidth;
              final barWidth = (slotWidth * 0.22).clamp(8.0, 18.0);

              final chartBody = SizedBox(
                width: chartWidth,
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          minY: 0,
                          maxY: _yMax(maxY),
                          gridData: _overviewGrid(maxY),
                          borderData: _chartBorder,
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            bottomTitles: const AxisTitles(),
                            leftTitles: _overviewLeftAxis(
                              maxY: maxY,
                              reservedSize: _yAxisWidth,
                            ),
                          ),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              direction: TooltipDirection.auto,
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              tooltipMargin: 8,
                              tooltipBorderRadius: BorderRadius.circular(8),
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              getTooltipColor: (_) => ColorSkin.title,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                final name = groupIndex < labels.length
                                    ? labels[groupIndex]
                                    : '';
                                final kind = rodIndex == 0 ? 'Nhập' : 'Xuất';
                                return BarTooltipItem(
                                  '$name\n$kind ${formatQty(rod.toY.toString())}',
                                  const TextStyle(
                                    color: ColorSkin.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                );
                              },
                            ),
                          ),
                          barGroups: [
                            for (var i = 0; i < count; i++)
                              BarChartGroupData(
                                x: i,
                                barsSpace: _barsSpace,
                                barRods: [
                                  BarChartRodData(
                                    toY: imported[i],
                                    width: barWidth,
                                    color: ColorSkin.primary,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: exported[i],
                                    width: barWidth,
                                    color: ColorSkin.secondary1,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 22,
                      child: Padding(
                        padding: const EdgeInsets.only(left: _yAxisWidth),
                        child: Row(
                          children: [
                            for (var i = 0; i < labels.length; i++)
                              SizedBox(
                                width: slotWidth,
                                child: Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _xLabelStyle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (fillsViewport) {
                return chartBody;
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: chartBody,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SegmentToggle extends StatelessWidget {
  const _SegmentToggle({required this.imported, required this.onChanged});

  final bool imported;
  final ValueChanged<bool> onChanged;

  static const _segmentWidth = 56.0;
  static const _height = 32.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _segmentWidth * 2 + 6,
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ColorSkin.tealLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: imported
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: _segmentWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: ColorSkin.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Row(
                children: [
                  _SegmentToggleItem(
                    label: 'Nhập',
                    selected: imported,
                    width: _segmentWidth,
                    onTap: () {
                      if (!imported) onChanged(true);
                    },
                  ),
                  _SegmentToggleItem(
                    label: 'Xuất',
                    selected: !imported,
                    width: _segmentWidth,
                    onTap: () {
                      if (imported) onChanged(false);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentToggleItem extends StatelessWidget {
  const _SegmentToggleItem({
    required this.label,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? ColorSkin.primary : ColorSkin.subtitle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDayLabel(String isoDate) {
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return isoDate;
  return DateFormat('dd/MM').format(dt.toLocal());
}

String _shortLabel(String sku, String name) {
  if (sku.isNotEmpty) return sku.length > 8 ? sku.substring(0, 8) : sku;
  if (name.length <= 8) return name;
  return name.substring(0, 8);
}

String _compact(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}tr';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

double _parseQty(String raw) => double.tryParse(raw) ?? 0;

bool overviewHasMovementData(ProductMovement movement) {
  final daily = movement.resolvedDailyMovement;
  if (daily.isNotEmpty) {
    return daily.any(
      (day) => _parseQty(day.importedQty) > 0 || _parseQty(day.exportedQty) > 0,
    );
  }
  return _parseQty(movement.totalImportedQty) > 0 ||
      _parseQty(movement.totalExportedQty) > 0;
}

bool overviewHasPendingData(OrganizationOverview data) {
  return data.documents.stockReceipts.pendingApproval > 0 ||
      data.documents.stockIssues.pendingApproval > 0;
}

bool overviewHasTopProductsData(ProductMovement movement) {
  return movement.topImportedProducts.isNotEmpty ||
      movement.topExportedProducts.isNotEmpty;
}

bool overviewHasWarehouseData(List<WarehouseBreakdown> rows) {
  for (final row in rows.take(6)) {
    if (_parseQty(row.productMovement.totalImportedQty) > 0 ||
        _parseQty(row.productMovement.totalExportedQty) > 0) {
      return true;
    }
  }
  return false;
}
