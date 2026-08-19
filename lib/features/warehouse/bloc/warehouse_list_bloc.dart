import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';

// —— Events ——
sealed class WarehouseListEvent extends Equatable {
  const WarehouseListEvent();
  @override
  List<Object?> get props => [];
}

class WarehouseListStarted extends WarehouseListEvent {
  const WarehouseListStarted();
}

class WarehouseListRefreshed extends WarehouseListEvent {
  const WarehouseListRefreshed();
}

class WarehouseListToggleStatus extends WarehouseListEvent {
  const WarehouseListToggleStatus(this.warehouseId);
  final String warehouseId;
  @override
  List<Object?> get props => [warehouseId];
}

class WarehouseListSearchChanged extends WarehouseListEvent {
  const WarehouseListSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

// —— States ——
sealed class WarehouseListState extends Equatable {
  const WarehouseListState();
  @override
  List<Object?> get props => [];
}

class WarehouseListInitial extends WarehouseListState {
  const WarehouseListInitial();
}

class WarehouseListLoading extends WarehouseListState {
  const WarehouseListLoading();
}

class WarehouseListLoaded extends WarehouseListState {
  const WarehouseListLoaded({required this.items, required this.query});

  final List<Warehouse> items;
  final String query;

  List<Warehouse> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (w) =>
              w.name.toLowerCase().contains(q) ||
              w.code.toLowerCase().contains(q) ||
              (w.address?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  List<Object?> get props => [items, query];
}

class WarehouseListFailure extends WarehouseListState {
  const WarehouseListFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

// —— Bloc ——
class WarehouseListBloc extends Bloc<WarehouseListEvent, WarehouseListState> {
  WarehouseListBloc({required WarehouseRepository repository})
    : _repository = repository,
      super(const WarehouseListInitial()) {
    on<WarehouseListStarted>(_onLoad);
    on<WarehouseListRefreshed>(_onRefresh);
    on<WarehouseListSearchChanged>(_onSearch);
    on<WarehouseListToggleStatus>(_onToggleStatus);
  }

  final WarehouseRepository _repository;
  List<Warehouse> _cache = const [];

  Future<void> _onLoad(
    WarehouseListStarted event,
    Emitter<WarehouseListState> emit,
  ) async {
    await _reloadFromApi(emit);
  }

  Future<void> _onRefresh(
    WarehouseListRefreshed event,
    Emitter<WarehouseListState> emit,
  ) async {
    await _reloadFromApi(emit);
  }

  Future<void> _reloadFromApi(Emitter<WarehouseListState> emit) async {
    emit(const WarehouseListLoading());
    try {
      _cache = await _repository.list();
      final query = state is WarehouseListLoaded
          ? (state as WarehouseListLoaded).query
          : '';
      emit(WarehouseListLoaded(items: _cache, query: query));
    } catch (e) {
      emit(WarehouseListFailure(_friendly(e)));
    }
  }

  Future<void> _onToggleStatus(
    WarehouseListToggleStatus event,
    Emitter<WarehouseListState> emit,
  ) async {
    final warehouse = _findCachedWarehouse(event.warehouseId);
    if (warehouse == null) {
      await _reloadFromApi(emit);
      return;
    }
    try {
      if (warehouse.isActive) {
        await _repository.deactivate(event.warehouseId);
      } else {
        await _repository.activate(event.warehouseId);
      }
      await _reloadFromApi(emit);
    } catch (e) {
      emit(WarehouseListFailure(_friendly(e)));
    }
  }

  void _onSearch(
    WarehouseListSearchChanged event,
    Emitter<WarehouseListState> emit,
  ) {
    emit(WarehouseListLoaded(items: _cache, query: event.query));
  }

  Warehouse? _findCachedWarehouse(String warehouseId) {
    for (final warehouse in _cache) {
      if (warehouse.id == warehouseId) return warehouse;
    }
    return null;
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
