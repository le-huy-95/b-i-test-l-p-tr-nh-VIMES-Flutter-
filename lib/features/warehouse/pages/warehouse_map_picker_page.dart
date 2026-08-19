import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/features/warehouse/services/reverse_geocoding_service.dart';
import 'package:test_y_app/features/warehouse/services/warehouse_map_search_service.dart';
import 'package:test_y_app/features/warehouse/warehouse_map_pick_result.dart';
import 'package:test_y_app/features/warehouse/widgets/warehouse_map_overlay.dart';
import 'package:test_y_app/features/warehouse/widgets/warehouse_map_search_results.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:test_y_app/shared/widgets/app_search_field.dart';

class WarehouseMapPickerPage extends StatefulWidget {
  const WarehouseMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    ReverseGeocodingService? geocoding,
    WarehouseMapSearchService? searchService,
  })  : _geocoding = geocoding,
        _searchService = searchService;

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final ReverseGeocodingService? _geocoding;
  final WarehouseMapSearchService? _searchService;

  static Future<WarehouseMapPickResult?> open(
    BuildContext context, {
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return Navigator.of(context).push<WarehouseMapPickResult>(
      MaterialPageRoute(
        builder: (_) => WarehouseMapPickerPage(
          initialLatitude: latitude,
          initialLongitude: longitude,
          initialAddress: address,
        ),
      ),
    );
  }

  @override
  State<WarehouseMapPickerPage> createState() => _WarehouseMapPickerPageState();
}

class _WarehouseMapPickerPageState extends State<WarehouseMapPickerPage> {
  static const _fallback = LatLng(10.7769, 106.7009);
  static const _fallbackText = 'Vị trí đã chọn';

  late final ReverseGeocodingService _geocoding;
  late final WarehouseMapSearchService _searchService;
  GoogleMapController? _mapController;
  late LatLng _target;
  String _address = '';
  bool _loadingAddress = false;
  int _lookupToken = 0;
  bool _mapReady = false;
  Timer? _lookupDebounce;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<WarehouseMapSearchResult> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _geocoding = widget._geocoding ?? ReverseGeocodingService();
    _searchService = widget._searchService ?? WarehouseMapSearchService();
    _target = LatLng(
      widget.initialLatitude ?? _fallback.latitude,
      widget.initialLongitude ?? _fallback.longitude,
    );
    _address = widget.initialAddress?.trim() ?? '';
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      await _moveToCurrentLocation();
    }
    _mapReady = true;
    _scheduleAddressLookup();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final next = LatLng(position.latitude, position.longitude);
      _target = next;
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(next, 16),
      );
    } catch (_) {
      // Keep fallback / initial camera.
    }
  }

  Future<void> _lookupAddress(LatLng target) async {
    final token = ++_lookupToken;
    setState(() => _loadingAddress = true);
    String address;
    try {
      address = await _geocoding
          .addressFrom(
            latitude: target.latitude,
            longitude: target.longitude,
          )
          .timeout(const Duration(seconds: 8), onTimeout: () => _fallbackText);
    } catch (_) {
      address = _fallbackText;
    }
    if (!mounted || token != _lookupToken) return;
    setState(() {
      _address = address;
      _loadingAddress = false;
    });
  }

  void _scheduleAddressLookup() {
    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(const Duration(milliseconds: 300), () {
      _lookupAddress(_target);
    });
  }

  void _onSearchChanged(String query) {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
    }
  }

  Future<List<WarehouseMapSearchResult>> _performSearch(String query) {
    return _searchService.search(query);
  }

  Future<void> _selectSearchResult(WarehouseMapSearchResult item) async {
    final next = LatLng(item.location.latitude, item.location.longitude);
    _target = next;
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
      _address = item.label;
      _loadingAddress = false;
    });
    _searchFocus.unfocus();
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(next, 16),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(
      WarehouseMapPickResult(
        address: _address.isEmpty ? 'Vị trí đã chọn' : _address,
        latitude: _target.latitude,
        longitude: _target.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: Text('Chọn địa chỉ')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _target, zoom: 15),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: _onMapCreated,
            onTap: (point) {
              _searchFocus.unfocus();
              setState(() => _showSearchResults = false);
              _mapController?.animateCamera(CameraUpdate.newLatLng(point));
            },
            onCameraMove: (position) => _target = position.target,
            onCameraIdle: () {
              if (_mapReady) _scheduleAddressLookup();
            },
          ),
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 44,
                  color: ColorSkin.primary,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: AppSearchField<WarehouseMapSearchResult>(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    hintText: 'Tìm kiếm địa chỉ...',
                    fillColor: Colors.white,
                    showClearButton: true,
                    loading: false,
                    minimumQueryLength: 3,
                    searchApi: _performSearch,
                    onResultsChanged: (results) {
                      if (!mounted) return;
                      setState(() {
                        _searchResults = results;
                        _showSearchResults = results.isNotEmpty;
                      });
                    },
                    onChanged: _onSearchChanged,
                    onClear: () {
                      setState(() {
                        _searchResults = [];
                        _showSearchResults = false;
                      });
                    },
                  ),
                ),
                WarehouseMapSearchResults(
                  results: _showSearchResults ? _searchResults : const [],
                  onSelected: _selectSearchResult,
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 168,
            child: FloatingActionButton.small(
              onPressed: _moveToCurrentLocation,
              backgroundColor: ColorSkin.white,
              foregroundColor: ColorSkin.primary,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: WarehouseMapOverlay(
              address: _address,
              loadingAddress: _loadingAddress,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}
