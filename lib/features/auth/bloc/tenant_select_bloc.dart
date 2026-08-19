import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_event.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_state.dart';

class TenantSelectBloc extends Bloc<TenantSelectEvent, TenantSelectState> {
  TenantSelectBloc({
    required AuthRepository authRepository,
    List<TenantMembership> tenants = const [],
  })  : _authRepository = authRepository,
        super(TenantSelectInitial(tenants: tenants)) {
    on<TenantSelectLoadRequested>(_onLoadRequested);
    on<TenantSelectRefreshRequested>(_onRefreshRequested);
    on<TenantSelectCreateRequested>(_onCreateRequested);
  }

  final AuthRepository _authRepository;

  List<TenantMembership> get _tenants => switch (state) {
        TenantSelectInitial(:final tenants) => tenants,
        TenantSelectRefreshing(:final tenants) => tenants,
        TenantSelectLoading(:final tenants) => tenants,
        TenantSelectSelected(:final tenants) => tenants,
        TenantSelectCreated(:final tenants) => tenants,
        TenantSelectFailure(:final tenants) => tenants,
      };

  void _onLoadRequested(
    TenantSelectLoadRequested event,
    Emitter<TenantSelectState> emit,
  ) {
    emit(TenantSelectInitial(tenants: List.unmodifiable(event.tenants)));
  }

  Future<void> _onRefreshRequested(
    TenantSelectRefreshRequested event,
    Emitter<TenantSelectState> emit,
  ) async {
    final current = _tenants;
    emit(TenantSelectRefreshing(tenants: current));
    try {
      final fresh = await _authRepository.fetchMyTenants();
      emit(TenantSelectInitial(tenants: List.unmodifiable(fresh)));
    } catch (e) {
      emit(
        TenantSelectFailure(
          tenants: current,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCreateRequested(
    TenantSelectCreateRequested event,
    Emitter<TenantSelectState> emit,
  ) async {
    final current = _tenants;
    emit(TenantSelectLoading(tenants: current));
    try {
      final result = await _authRepository.createTenantWithLogo(
        code: event.code,
        name: event.name,
        logoFilePath: event.logoFilePath,
      );
      final updated = [...current, result.tenant];
      emit(
        TenantSelectCreated(
          tenants: updated,
          created: result.tenant,
          logoUploadWarning: result.logoUploadWarning,
        ),
      );
    } catch (e) {
      emit(TenantSelectFailure(tenants: current, message: e.toString()));
    }
  }
}
