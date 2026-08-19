import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';

sealed class WarehouseFormEvent extends Equatable {
  const WarehouseFormEvent();
  @override
  List<Object?> get props => [];
}

class WarehouseFormLoadExisting extends WarehouseFormEvent {
  const WarehouseFormLoadExisting(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class WarehouseFormSubmitted extends WarehouseFormEvent {
  const WarehouseFormSubmitted({
    required this.code,
    required this.name,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
  });

  final String code;
  final String name;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => [code, name, address, phone, latitude, longitude];
}

sealed class WarehouseFormState extends Equatable {
  const WarehouseFormState();
  @override
  List<Object?> get props => [];
}

class WarehouseFormInitial extends WarehouseFormState {
  const WarehouseFormInitial({this.existing});
  final Warehouse? existing;
  @override
  List<Object?> get props => [existing];
}

class WarehouseFormLoading extends WarehouseFormState {
  const WarehouseFormLoading();
}

class WarehouseFormSubmitting extends WarehouseFormState {
  const WarehouseFormSubmitting();
}

class WarehouseFormSuccess extends WarehouseFormState {
  const WarehouseFormSuccess(this.warehouse);
  final Warehouse warehouse;
  @override
  List<Object?> get props => [warehouse];
}

class WarehouseFormFailure extends WarehouseFormState {
  const WarehouseFormFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class WarehouseFormBloc extends Bloc<WarehouseFormEvent, WarehouseFormState> {
  WarehouseFormBloc({
    required WarehouseRepository repository,
    this.warehouseId,
  })  : _repository = repository,
        super(const WarehouseFormInitial()) {
    on<WarehouseFormLoadExisting>(_onLoad);
    on<WarehouseFormSubmitted>(_onSubmit);
  }

  final WarehouseRepository _repository;
  final String? warehouseId;

  Future<void> _onLoad(
    WarehouseFormLoadExisting event,
    Emitter<WarehouseFormState> emit,
  ) async {
    emit(const WarehouseFormLoading());
    try {
      final existing = await _repository.getById(event.id);
      emit(WarehouseFormInitial(existing: existing));
    } catch (e) {
      emit(WarehouseFormFailure(_friendly(e)));
    }
  }

  Future<void> _onSubmit(
    WarehouseFormSubmitted event,
    Emitter<WarehouseFormState> emit,
  ) async {
    emit(const WarehouseFormSubmitting());
    try {
      final body = <String, dynamic>{
        'code': event.code.trim(),
        'name': event.name.trim(),
        if (event.address != null && event.address!.trim().isNotEmpty)
          'address': event.address!.trim(),
        if (event.phone != null && event.phone!.trim().isNotEmpty)
          'phone': event.phone!.trim(),
        if (event.latitude != null) 'latitude': event.latitude,
        if (event.longitude != null) 'longitude': event.longitude,
      };
      final Warehouse result;
      if (warehouseId == null) {
        result = await _repository.create(body);
      } else {
        result = await _repository.update(warehouseId!, body);
      }
      emit(WarehouseFormSuccess(result));
    } catch (e) {
      emit(WarehouseFormFailure(_friendly(e)));
    }
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
