import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';

sealed class WarehouseDetailEvent extends Equatable {
  const WarehouseDetailEvent();
  @override
  List<Object?> get props => [];
}

class WarehouseDetailStarted extends WarehouseDetailEvent {
  const WarehouseDetailStarted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class WarehouseDetailToggleStatus extends WarehouseDetailEvent {
  const WarehouseDetailToggleStatus(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

sealed class WarehouseDetailState extends Equatable {
  const WarehouseDetailState();
  @override
  List<Object?> get props => [];
}

class WarehouseDetailInitial extends WarehouseDetailState {
  const WarehouseDetailInitial();
}

class WarehouseDetailLoading extends WarehouseDetailState {
  const WarehouseDetailLoading();
}

class WarehouseDetailLoaded extends WarehouseDetailState {
  const WarehouseDetailLoaded(this.warehouse);
  final Warehouse warehouse;
  @override
  List<Object?> get props => [warehouse];
}

class WarehouseDetailFailure extends WarehouseDetailState {
  const WarehouseDetailFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class WarehouseDetailBloc
    extends Bloc<WarehouseDetailEvent, WarehouseDetailState> {
  WarehouseDetailBloc({required WarehouseRepository repository})
      : _repository = repository,
        super(const WarehouseDetailInitial()) {
    on<WarehouseDetailStarted>(_onStarted);
    on<WarehouseDetailToggleStatus>(_onToggleStatus);
  }

  final WarehouseRepository _repository;

  Future<void> _onStarted(
    WarehouseDetailStarted event,
    Emitter<WarehouseDetailState> emit,
  ) async {
    emit(const WarehouseDetailLoading());
    try {
      final warehouse = await _repository.getById(event.id);
      emit(WarehouseDetailLoaded(warehouse));
    } catch (e) {
      emit(WarehouseDetailFailure(_friendly(e)));
    }
  }

  Future<void> _onToggleStatus(
    WarehouseDetailToggleStatus event,
    Emitter<WarehouseDetailState> emit,
  ) async {
    final current = state;
    if (current is! WarehouseDetailLoaded) return;

    emit(const WarehouseDetailLoading());
    try {
      final Warehouse updated;
      if (current.warehouse.isActive) {
        updated = await _repository.deactivate(event.id);
      } else {
        updated = await _repository.activate(event.id);
      }
      emit(WarehouseDetailLoaded(updated));
    } catch (e) {
      emit(WarehouseDetailLoaded(current.warehouse));
      rethrow;
    }
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
