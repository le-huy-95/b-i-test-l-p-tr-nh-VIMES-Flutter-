import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/domain/repositories/create_tenant_with_logo_result.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_bloc.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_event.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

TenantMembership fakeTenant(String id, {String? logoUrl}) {
  return TenantMembership(
    id: id,
    code: id.toUpperCase(),
    name: 'Tenant $id',
    role: 'admin',
    logoUrl: logoUrl,
  );
}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
  });

  TenantSelectBloc buildBloc({List<TenantMembership> tenants = const []}) {
    return TenantSelectBloc(
      authRepository: authRepository,
      tenants: tenants,
    );
  }

  group('TenantSelectRefreshRequested', () {
    blocTest<TenantSelectBloc, TenantSelectState>(
      'refresh empty response keeps existing tenants',
      build: () {
        when(() => authRepository.fetchMyTenants()).thenAnswer((_) async => []);
        return buildBloc(tenants: [fakeTenant('t1')]);
      },
      act: (bloc) => bloc.add(const TenantSelectRefreshRequested()),
      expect: () => [
        isA<TenantSelectRefreshing>(),
        isA<TenantSelectInitial>()
            .having((s) => s.tenants.first.id, 'tenant id', 't1')
            .having((s) => s.tenants.length, 'count', 1),
      ],
    );

    blocTest<TenantSelectBloc, TenantSelectState>(
      'refresh success updates tenant list',
      build: () {
        when(() => authRepository.fetchMyTenants()).thenAnswer(
          (_) async => [fakeTenant('t1', logoUrl: 'http://x/logo.png')],
        );
        return buildBloc(tenants: [fakeTenant('old')]);
      },
      act: (bloc) => bloc.add(const TenantSelectRefreshRequested()),
      expect: () => [
        isA<TenantSelectRefreshing>()
            .having((s) => s.tenants.length, 'old count', 1),
        isA<TenantSelectInitial>()
            .having((s) => s.tenants.first.id, 'fresh id', 't1')
            .having((s) => s.tenants.first.logoUrl, 'logoUrl', 'http://x/logo.png'),
      ],
    );

    blocTest<TenantSelectBloc, TenantSelectState>(
      'refresh failure keeps old tenants',
      build: () {
        when(() => authRepository.fetchMyTenants())
            .thenThrow(Exception('Network error'));
        return buildBloc(tenants: [fakeTenant('t1')]);
      },
      act: (bloc) => bloc.add(const TenantSelectRefreshRequested()),
      expect: () => [
        isA<TenantSelectRefreshing>(),
        isA<TenantSelectFailure>()
            .having((s) => s.tenants.first.id, 'tenant id', 't1')
            .having((s) => s.message, 'message', contains('Network error')),
      ],
    );
  });

  group('TenantSelectCreateRequested', () {
    blocTest<TenantSelectBloc, TenantSelectState>(
      'create with logo adds tenant to list',
      build: () {
        when(
          () => authRepository.createTenantWithLogo(
            code: any(named: 'code'),
            name: any(named: 'name'),
            logoFilePath: any(named: 'logoFilePath'),
          ),
        ).thenAnswer(
          (_) async => CreateTenantWithLogoResult(
            tenant: fakeTenant('new', logoUrl: 'http://x/new.png'),
          ),
        );
        return buildBloc(tenants: [fakeTenant('t1')]);
      },
      act: (bloc) => bloc.add(
        const TenantSelectCreateRequested(
          code: 'NEW',
          name: 'New Org',
          logoFilePath: '/tmp/logo.png',
        ),
      ),
      expect: () => [
        isA<TenantSelectLoading>(),
        isA<TenantSelectCreated>()
            .having((s) => s.tenants.length, 'count', 2)
            .having((s) => s.created.id, 'created id', 'new'),
      ],
    );
  });
}
