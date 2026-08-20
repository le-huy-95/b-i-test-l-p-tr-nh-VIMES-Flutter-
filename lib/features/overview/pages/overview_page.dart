import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/overview/bloc/overview_bloc.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_id.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_slice.dart';
import 'package:test_y_app/features/overview/overview_date_range.dart';
import 'package:test_y_app/features/overview/widgets/overview_chart_card.dart';
import 'package:test_y_app/features/overview/widgets/overview_charts.dart';
import 'package:test_y_app/features/overview/widgets/overview_date_range_bottom_sheet.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverviewBloc, OverviewState>(
      builder: (context, state) {
        if (state is OverviewLoading || state is OverviewInitial) {
          return const Center(
            child: CircularProgressIndicator(color: ColorSkin.primary),
          );
        }
        if (state is OverviewFailure) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ColorSkin.subtitle),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Thử lại',
                    variant: AppButtonVariant.primary,
                    onPressed: () => context.read<OverviewBloc>().add(
                      const OverviewStarted(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is! OverviewReady) {
          return const SizedBox.shrink();
        }

        final authState = context.watch<AuthBloc>().state;
        final selectedTenantName = authState is AuthAuthenticated &&
                authState.tenants.isNotEmpty
            ? authState.tenants
                  .firstWhere(
                    (t) => t.id == authState.selectedTenantId,
                    orElse: () => authState.tenants.first,
                  )
                  .name
            : 'VIMES';
        final chartSections = _buildChartSections(context, state);
        final hasData = state.charts.values.any(
          (slice) => slice.data?.hasVisibleData == true,
        );

        return RefreshIndicator(
          color: ColorSkin.primary,
          onRefresh: () => _onRefresh(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Xin chào, $selectedTenantName',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (!hasData)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _OverviewEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(chartSections),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onRefresh(BuildContext context) async {
    final bloc = context.read<OverviewBloc>();
    bloc.add(const OverviewRefreshed());
    await bloc.stream.firstWhere(
      (state) => state is OverviewReady && !state.isAnyChartLoading,
    );
  }

  List<Widget> _buildChartSections(BuildContext context, OverviewReady state) {
    final sections = <Widget>[];

    void addChart(Widget chart) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 28));
      }
      sections.add(chart);
    }

    final movementSlice = state.slice(OverviewChartId.movement);
    final movementData = movementSlice.data;
    if (_shouldShowChart(movementSlice, movementData)) {
      addChart(
        OverviewMovementDailyColumnChart(
          movement: movementData!.productMovement,
          filter: _filterProps(
            context,
            OverviewChartId.movement,
            movementSlice,
          ),
        ),
      );
    }

    final pendingSlice = state.slice(OverviewChartId.pending);
    final pendingData = pendingSlice.data;
    if (_shouldShowChart(pendingSlice, pendingData)) {
      addChart(
        OverviewPendingColumnChart(
          data: pendingData!,
          filter: _filterProps(context, OverviewChartId.pending, pendingSlice),
        ),
      );
    }

    final topSlice = state.slice(OverviewChartId.topProducts);
    final topData = topSlice.data;
    if (_shouldShowChart(topSlice, topData)) {
      addChart(
        OverviewTopProductsColumnChart(
          movement: topData!.productMovement,
          filter: _filterProps(context, OverviewChartId.topProducts, topSlice),
        ),
      );
    }

    final warehouseSlice = state.slice(OverviewChartId.warehouse);
    final warehouseData = warehouseSlice.data;
    if (warehouseData?.isOrganizationScope == true &&
        _shouldShowChart(warehouseSlice, warehouseData)) {
      addChart(
        OverviewWarehouseColumnChart(
          rows: warehouseData!.warehousesBreakdown,
          filter: _filterProps(
            context,
            OverviewChartId.warehouse,
            warehouseSlice,
          ),
        ),
      );
    }

    return sections;
  }

  bool _shouldShowChart(OverviewChartSlice slice, OrganizationOverview? data) {
    if (slice.isFiltered || slice.isLoading || slice.hasFailure) {
      return true;
    }
    return data != null;
  }

  OverviewChartFilterProps _filterProps(
    BuildContext context,
    OverviewChartId chartId,
    OverviewChartSlice slice,
  ) {
    return OverviewChartFilterProps(
      dateRangeLabel: formatOverviewDateRange(slice.from, slice.to),
      onFilterTap: () => _openFilter(context, chartId, slice),
      isLoading: slice.isLoading,
      errorMessage: slice.errorMessage,
      onRetry: slice.hasFailure
          ? () =>
                context.read<OverviewBloc>().add(OverviewChartRetried(chartId))
          : null,
    );
  }

  Future<void> _openFilter(
    BuildContext context,
    OverviewChartId chartId,
    OverviewChartSlice slice,
  ) async {
    final picked = await OverviewDateRangeBottomSheet.show(
      context,
      initialRange: DateTimeRange(start: slice.from, end: slice.to),
    );
    if (picked == null || !context.mounted) return;

    final (from, to) = normalizeOverviewPickerRange(
      start: picked.start,
      end: picked.end,
    );
    context.read<OverviewBloc>().add(
      OverviewChartFiltered(chartId: chartId, from: from, to: to),
    );
  }
}

class _OverviewEmptyState extends StatelessWidget {
  const _OverviewEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Chưa có dữ liệu tổng quan cho tôi',
          textAlign: TextAlign.center,
          style: TextStyle(color: ColorSkin.subtitle, fontSize: 14),
        ),
      ),
    );
  }
}
