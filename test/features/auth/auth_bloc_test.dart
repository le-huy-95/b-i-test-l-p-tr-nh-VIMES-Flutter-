import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_event.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

TenantMembership fakeTenant(String id) {
  return TenantMembership(
    id: id,
    code: id.toUpperCase(),
    name: 'Tenant $id',
    role: 'admin',
  );
}

const fakeUser = User(id: 'u1', name: 'User One', email: 'a@b.com');

AuthSession fakeSession(List<TenantMembership> tenants) {
  return AuthSession(
    user: fakeUser,
    tenants: tenants,
    accessToken: 'at',
    refreshToken: 'rt',
  );
}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    when(() => authRepository.selectTenant(any())).thenAnswer((_) async {});
    when(() => authRepository.getSelectedTenantId()).thenAnswer((_) async => null);
  });

  AuthBloc buildBloc() => AuthBloc(
        authRepository: authRepository,
        checkOnCreate: false,
      );

  group('AuthSessionEstablished', () {
    blocTest<AuthBloc, AuthState>(
      '1 tenant → AuthAuthenticated + selectTenant called',
      build: buildBloc,
      act: (bloc) => bloc.add(AuthSessionEstablished(fakeSession([fakeTenant('t1')]))),
      expect: () => [
        isA<AuthAuthenticated>()
            .having((s) => s.user.id, 'user.id', 'u1')
            .having((s) => s.selectedTenantId, 'selectedTenantId', 't1')
            .having((s) => s.tenants.length, 'tenants.length', 1),
      ],
      verify: (_) {
        verify(() => authRepository.selectTenant('t1')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      '2 tenants no saved → AuthNeedsTenant',
      build: buildBloc,
      act: (bloc) => bloc.add(
            AuthSessionEstablished(
              fakeSession([fakeTenant('t1'), fakeTenant('t2')]),
            ),
          ),
      expect: () => [
        isA<AuthNeedsTenant>()
            .having((s) => s.user.id, 'user.id', 'u1')
            .having((s) => s.tenants.length, 'tenants.length', 2),
      ],
      verify: (_) {
        verifyNever(() => authRepository.selectTenant(any()));
      },
    );
  });

  group('AuthTenantSelected', () {
    blocTest<AuthBloc, AuthState>(
      'selectTenant → AuthAuthenticated',
      build: buildBloc,
      seed: () => AuthNeedsTenant(
        user: fakeUser,
        tenants: [fakeTenant('t1'), fakeTenant('t2')],
      ),
      act: (bloc) => bloc.add(const AuthTenantSelected('t2')),
      expect: () => [
        isA<AuthAuthenticated>()
            .having((s) => s.selectedTenantId, 'selectedTenantId', 't2')
            .having((s) => s.user.id, 'user.id', 'u1')
            .having((s) => s.tenants.map((t) => t.id).toList(), 'tenant ids', [
              't1',
              't2',
            ]),
      ],
      verify: (_) {
        verify(() => authRepository.selectTenant('t2')).called(1);
      },
    );
  });
}
