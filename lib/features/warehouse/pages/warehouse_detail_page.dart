import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/warehouse/bloc/warehouse_detail_bloc.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';

class WarehouseDetailPage extends StatelessWidget {
  const WarehouseDetailPage({super.key, required this.warehouseId});

  final String warehouseId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final canManage = canManageMasterDataForAuthState(authState);

        return Scaffold(
          appBar: AppHeader(
            title: const Text('Chi tiết Kho'),
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final ok =
                        await context.push<bool>('/warehouses/$warehouseId/edit');
                    if (ok == true && context.mounted) {
                      context
                          .read<WarehouseDetailBloc>()
                          .add(WarehouseDetailStarted(warehouseId));
                    }
                  },
                ),
            ],
          ),
          body: BlocBuilder<WarehouseDetailBloc, WarehouseDetailState>(
            builder: (context, state) {
              if (state is WarehouseDetailLoading ||
                  state is WarehouseDetailInitial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is WarehouseDetailFailure) {
                return Center(child: Text(state.message));
              }
              if (state is! WarehouseDetailLoaded) {
                return const SizedBox.shrink();
              }

              final w = state.warehouse;
              return _DetailContent(
                warehouse: w,
                canManage: canManage,
                warehouseId: warehouseId,
              );
            },
          ),
        );
      },
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.warehouse,
    required this.canManage,
    required this.warehouseId,
  });
  final Warehouse warehouse;
  final bool canManage;
  final String warehouseId;

  static const _defaultTarget = LatLng(10.7769, 106.7009);

  @override
  Widget build(BuildContext context) {
    final hasCoords = warehouse.hasCoordinates;
    final target = hasCoords
        ? LatLng(warehouse.latitude!, warehouse.longitude!)
        : _defaultTarget;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMap(target, hasCoords),
        if (!hasCoords) ...[
          const SizedBox(height: 8),
          _buildWarning('Chưa có toạ độ — đang hiển thị vị trí mặc định (HCM)'),
        ],
        const SizedBox(height: 16),
        _buildHeaderSection(),
        const SizedBox(height: 16),
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildMap(LatLng target, bool hasCoords) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: target,
            zoom: hasCoords ? 15 : 12,
          ),
          markers: hasCoords
              ? {
                  Marker(
                    markerId: MarkerId(warehouse.id),
                    position: target,
                    infoWindow: InfoWindow(title: warehouse.name),
                  ),
                }
              : {},
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          liteModeEnabled: false,
        ),
      ),
    );
  }

  Widget _buildWarning(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorSkin.orangeLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFB8860B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB8860B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ColorSkin.primary, ColorSkin.primarySub],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.warehouse_outlined, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                warehouse.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ColorSkin.title,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _codeChip(warehouse.code),
                  const SizedBox(width: 8),
                  _statusChip(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _codeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColorSkin.tealLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColorSkin.title,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _statusChip() {
    final isActive = warehouse.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? ColorSkin.tealLight : ColorSkin.orangeLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        warehouse.statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isActive ? ColorSkin.primarySub : const Color(0xFFB8860B),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final hasCoords = warehouse.hasCoordinates;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorSkin.border1.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin kho',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorSkin.title,
            ),
          ),
          const SizedBox(height: 12),
          _infoTile(Icons.location_on_outlined, 'Địa chỉ', warehouse.address ?? '—'),
          _infoTile(
            Icons.my_location_outlined,
            'Toạ độ',
            hasCoords
                ? '${warehouse.latitude!.toStringAsFixed(4)}, ${warehouse.longitude!.toStringAsFixed(4)}'
                : '—',
          ),
          _infoTile(
            Icons.phone_outlined,
            'Số điện thoại',
            warehouse.phone ?? '—',
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ColorSkin.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorSkin.subtitle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorSkin.title,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
