import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/tenant/tenant_invitation.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';
import 'package:test_y_app/domain/repositories/tenant_people_repository.dart';

part 'tenant_people_event.dart';
part 'tenant_people_state.dart';

class TenantPeopleBloc extends Bloc<TenantPeopleEvent, TenantPeopleState> {
  TenantPeopleBloc({required TenantPeopleRepository repository})
    : _repository = repository,
      super(const TenantPeopleInitial()) {
    on<TenantPeopleStarted>(_onStarted);
    on<TenantPeopleRefreshed>(_onRefreshed);
    on<TenantPeopleLoadMore>(_onLoadMore);
    on<TenantPeopleSearchChanged>(_onSearchChanged);
    on<TenantPeopleTabChanged>(_onTabChanged);
    on<TenantPeopleCreateInvitationSubmitted>(_onCreateInvitationSubmitted);
    on<TenantPeopleCreateTenantUserSubmitted>(_onCreateTenantUserSubmitted);
    on<TenantPeopleAcceptInvitationSubmitted>(_onAcceptInvitationSubmitted);
    on<TenantPeopleDeclineInvitationSubmitted>(_onDeclineInvitationSubmitted);
  }

  final TenantPeopleRepository _repository;

  Future<void> _loadFirstPage(
    Emitter<TenantPeopleState> emit, {
    String? search,
    TenantPeopleTab tab = TenantPeopleTab.members,
    Map<String, String> overrides = const <String, String>{},
  }) async {
    if (tab == TenantPeopleTab.invitations) {
      final result = await _repository.fetchInvitations(
        page: 1,
        limit: 20,
        search: search,
      );
      emit(
        TenantPeopleLoaded(
          tab: tab,
          members: const [],
          invitations: _applyOverrides(result.items, overrides),
          page: result.page,
          limit: result.limit,
          total: result.total,
          totalPages: result.totalPages,
          search: search,
          invitationStatusOverrides: overrides,
        ),
      );
      return;
    }

    final result = await _repository.fetchMembers(
      page: 1,
      limit: 20,
      search: search,
    );
    emit(
      TenantPeopleLoaded(
        tab: tab,
        members: result.items,
        invitations: const [],
        page: result.page,
        limit: result.limit,
        total: result.total,
        totalPages: result.totalPages,
        search: search,
        invitationStatusOverrides: overrides,
      ),
    );
  }

  Future<void> _onStarted(
    TenantPeopleStarted event,
    Emitter<TenantPeopleState> emit,
  ) async {
    emit(const TenantPeopleLoading());
    try {
      await _loadFirstPage(emit, search: event.search, tab: event.tab);
    } catch (e) {
      emit(TenantPeopleFailure(_friendly(e)));
    }
  }

  Future<void> _onRefreshed(
    TenantPeopleRefreshed event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    final search = current is TenantPeopleLoaded ? current.search : null;
    final tab = current is TenantPeopleLoaded
        ? current.tab
        : TenantPeopleTab.members;
    final overrides = current is TenantPeopleLoaded
        ? current.invitationStatusOverrides
        : const <String, String>{};
    try {
      await _loadFirstPage(
        emit,
        search: search,
        tab: tab,
        overrides: overrides,
      );
    } catch (e) {
      emit(TenantPeopleFailure(_friendly(e)));
    }
  }

  Future<void> _onSearchChanged(
    TenantPeopleSearchChanged event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    final tab = current is TenantPeopleLoaded
        ? current.tab
        : TenantPeopleTab.members;
    final overrides = current is TenantPeopleLoaded
        ? current.invitationStatusOverrides
        : const <String, String>{};
    emit(const TenantPeopleLoading());
    try {
      await _loadFirstPage(
        emit,
        search: event.query.trim().isEmpty ? null : event.query.trim(),
        tab: tab,
        overrides: overrides,
      );
    } catch (e) {
      emit(TenantPeopleFailure(_friendly(e)));
    }
  }

  Future<void> _onTabChanged(
    TenantPeopleTabChanged event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    final overrides = current is TenantPeopleLoaded
        ? current.invitationStatusOverrides
        : const <String, String>{};
    emit(const TenantPeopleLoading());
    try {
      await _loadFirstPage(emit, tab: event.tab, overrides: overrides);
    } catch (e) {
      emit(TenantPeopleFailure(_friendly(e)));
    }
  }

  Future<void> _onLoadMore(
    TenantPeopleLoadMore event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    if (current is! TenantPeopleLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    try {
      if (current.tab == TenantPeopleTab.invitations) {
        final result = await _repository.fetchInvitations(
          page: current.page + 1,
          limit: current.limit,
          search: current.search,
        );
        emit(
          current.copyWith(
            invitations: [
              ...current.invitations,
              ..._applyOverrides(
                result.items,
                current.invitationStatusOverrides,
              ),
            ],
            page: result.page,
            limit: result.limit,
            total: result.total,
            totalPages: result.totalPages,
            isLoadingMore: false,
          ),
        );
        return;
      }

      final result = await _repository.fetchMembers(
        page: current.page + 1,
        limit: current.limit,
        search: current.search,
      );
      emit(
        current.copyWith(
          members: [...current.members, ...result.items],
          page: result.page,
          limit: result.limit,
          total: result.total,
          totalPages: result.totalPages,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(current.copyWith(isLoadingMore: false, error: _friendly(e)));
    }
  }

  Future<void> _onCreateInvitationSubmitted(
    TenantPeopleCreateInvitationSubmitted event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    if (current is! TenantPeopleLoaded) return;
    emit(current.copyWith(isBusy: true, clearError: true));
    try {
      final result = await _repository.createInvitation(
        email: event.email,
        role: event.role,
      );
      await _loadFirstPage(
        emit,
        search: current.search,
        tab: TenantPeopleTab.invitations,
        overrides: current.invitationStatusOverrides,
      );
      final refreshed = state;
      if (refreshed is TenantPeopleLoaded) {
        emit(
          refreshed.copyWith(
            isBusy: false,
            recentMessage: 'Đã gửi lời mời đến ${result.email}',
            recentInviteLink: result.inviteLink,
            clearError: true,
          ),
        );
      }
    } catch (e) {
      emit(current.copyWith(isBusy: false, error: _friendly(e)));
    }
  }

  Future<void> _onCreateTenantUserSubmitted(
    TenantPeopleCreateTenantUserSubmitted event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    if (current is! TenantPeopleLoaded) return;
    emit(current.copyWith(isBusy: true, clearError: true));
    try {
      await _repository.createTenantUser(
        email: event.email,
        phone: event.phone,
        name: event.name,
        password: event.password,
        role: event.role,
        warehouseIds: event.warehouseIds,
      );
      await _loadFirstPage(
        emit,
        search: current.search,
        tab: TenantPeopleTab.members,
        overrides: current.invitationStatusOverrides,
      );
      final refreshed = state;
      if (refreshed is TenantPeopleLoaded) {
        emit(
          refreshed.copyWith(
            isBusy: false,
            recentMessage: 'Đã tạo user nội bộ mới',
            clearError: true,
          ),
        );
      }
    } catch (e) {
      emit(current.copyWith(isBusy: false, error: _friendly(e)));
    }
  }

  Future<void> _onAcceptInvitationSubmitted(
    TenantPeopleAcceptInvitationSubmitted event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    if (current is! TenantPeopleLoaded) return;
    emit(current.copyWith(isBusy: true, clearError: true));
    try {
      await _repository.acceptInvitation(invitationId: event.invitation.id);
      await _loadFirstPage(
        emit,
        search: current.search,
        tab: TenantPeopleTab.invitations,
        overrides: current.invitationStatusOverrides,
      );
      final refreshed = state;
      if (refreshed is TenantPeopleLoaded) {
        emit(
          _withInvitationStatus(
            refreshed,
            event.invitation.id,
            'accepted',
          ).copyWith(
            isBusy: false,
            recentMessage: 'Đã gia nhập tổ chức ${event.invitation.tenantName}',
            clearError: true,
          ),
        );
      }
    } catch (e) {
      emit(current.copyWith(isBusy: false, error: _friendly(e)));
    }
  }

  Future<void> _onDeclineInvitationSubmitted(
    TenantPeopleDeclineInvitationSubmitted event,
    Emitter<TenantPeopleState> emit,
  ) async {
    final current = state;
    if (current is! TenantPeopleLoaded) return;
    emit(current.copyWith(isBusy: true, clearError: true));
    try {
      await _repository.declineInvitation(invitationId: event.invitation.id);
      await _loadFirstPage(
        emit,
        search: current.search,
        tab: TenantPeopleTab.invitations,
        overrides: current.invitationStatusOverrides,
      );
      final refreshed = state;
      if (refreshed is TenantPeopleLoaded) {
        emit(
          _withInvitationStatus(
            refreshed,
            event.invitation.id,
            'declined',
          ).copyWith(
            isBusy: false,
            recentMessage:
                'Đã từ chối lời mời từ ${event.invitation.tenantName}',
            clearError: true,
          ),
        );
      }
    } catch (e) {
      emit(current.copyWith(isBusy: false, error: _friendly(e)));
    }
  }

  /// Overrides the status of an invitation locally so the UI reflects the
  /// latest accept/decline action even if the re-fetched list still returns
  /// a stale `pending` status from the server. The override persists across
  /// subsequent loads/tab switches until the page is recreated.
  TenantPeopleLoaded _withInvitationStatus(
    TenantPeopleLoaded state,
    String invitationId,
    String status,
  ) {
    final overrides = Map<String, String>.of(state.invitationStatusOverrides);
    overrides[invitationId] = status;
    final invitations = _applyOverrides(state.invitations, overrides);
    return state.copyWith(
      invitations: invitations,
      invitationStatusOverrides: overrides,
    );
  }

  List<TenantInvitation> _applyOverrides(
    List<TenantInvitation> invitations,
    Map<String, String> overrides,
  ) {
    if (overrides.isEmpty) return invitations;
    return invitations.map((invitation) {
      final status = overrides[invitation.id];
      if (status == null || status == invitation.status) return invitation;
      return invitation.copyWith(status: status);
    }).toList();
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
