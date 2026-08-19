part of 'tenant_people_bloc.dart';

sealed class TenantPeopleState {
  const TenantPeopleState();
}

class TenantPeopleInitial extends TenantPeopleState {
  const TenantPeopleInitial();
}

class TenantPeopleLoading extends TenantPeopleState {
  const TenantPeopleLoading();
}

class TenantPeopleFailure extends TenantPeopleState {
  const TenantPeopleFailure(this.message);

  final String message;
}

class TenantPeopleLoaded extends TenantPeopleState {
  const TenantPeopleLoaded({
    required this.tab,
    required this.members,
    required this.invitations,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.search,
    this.isLoadingMore = false,
    this.isBusy = false,
    this.error,
    this.recentMessage,
    this.recentInviteLink,
    this.invitationStatusOverrides = const {},
  });

  final TenantPeopleTab tab;
  final List<TenantMember> members;
  final List<TenantInvitation> invitations;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final String? search;
  final bool isLoadingMore;
  final bool isBusy;
  final String? error;
  final String? recentMessage;
  final String? recentInviteLink;

  /// Statuses of invitations that were acted on locally (e.g. accepted /
  /// declined) so the UI keeps reflecting the result even if the re-fetched
  /// list returns a stale `pending` status from the server.
  final Map<String, String> invitationStatusOverrides;

  bool get hasMore => page < totalPages;

  TenantPeopleLoaded copyWith({
    TenantPeopleTab? tab,
    List<TenantMember>? members,
    List<TenantInvitation>? invitations,
    int? page,
    int? limit,
    int? total,
    int? totalPages,
    String? search,
    bool? isLoadingMore,
    bool? isBusy,
    String? error,
    String? recentMessage,
    String? recentInviteLink,
    Map<String, String>? invitationStatusOverrides,
    bool clearError = false,
  }) {
    return TenantPeopleLoaded(
      tab: tab ?? this.tab,
      members: members ?? this.members,
      invitations: invitations ?? this.invitations,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      search: search ?? this.search,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      recentMessage: recentMessage,
      recentInviteLink: recentInviteLink,
      invitationStatusOverrides:
          invitationStatusOverrides ?? this.invitationStatusOverrides,
    );
  }
}
