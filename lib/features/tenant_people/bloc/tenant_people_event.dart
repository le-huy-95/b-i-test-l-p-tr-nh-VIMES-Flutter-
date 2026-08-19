part of 'tenant_people_bloc.dart';

enum TenantPeopleTab { members, invitations }

sealed class TenantPeopleEvent {
  const TenantPeopleEvent();
}

class TenantPeopleStarted extends TenantPeopleEvent {
  const TenantPeopleStarted({this.search, this.tab = TenantPeopleTab.members});

  final String? search;
  final TenantPeopleTab tab;
}

class TenantPeopleRefreshed extends TenantPeopleEvent {
  const TenantPeopleRefreshed();
}

class TenantPeopleLoadMore extends TenantPeopleEvent {
  const TenantPeopleLoadMore();
}

class TenantPeopleSearchChanged extends TenantPeopleEvent {
  const TenantPeopleSearchChanged(this.query);

  final String query;
}

class TenantPeopleTabChanged extends TenantPeopleEvent {
  const TenantPeopleTabChanged(this.tab);

  final TenantPeopleTab tab;
}

class TenantPeopleCreateInvitationSubmitted extends TenantPeopleEvent {
  const TenantPeopleCreateInvitationSubmitted({
    required this.email,
    required this.role,
  });

  final String email;
  final String role;
}

class TenantPeopleCreateTenantUserSubmitted extends TenantPeopleEvent {
  const TenantPeopleCreateTenantUserSubmitted({
    required this.password,
    required this.role,
    this.email,
    this.phone,
    this.name,
    this.warehouseIds,
  });

  final String? email;
  final String? phone;
  final String? name;
  final String password;
  final String role;
  final List<String>? warehouseIds;
}

class TenantPeopleAcceptInvitationSubmitted extends TenantPeopleEvent {
  const TenantPeopleAcceptInvitationSubmitted({required this.invitation});

  final TenantInvitation invitation;
}

class TenantPeopleDeclineInvitationSubmitted extends TenantPeopleEvent {
  const TenantPeopleDeclineInvitationSubmitted({required this.invitation});

  final TenantInvitation invitation;
}
