import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_y_app/core/firebase/push_notification_handler.dart';
import 'package:test_y_app/core/firebase/push_notification_payload.dart';
import 'package:test_y_app/core/firebase/push_notification_types.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
  });

  group('PushNotificationHandler.stockDocFallbackMessage', () {
    test('includes target id for stock receipt', () {
      const payload = PushNotificationPayload(
        data: {},
        type: PushNotificationTypes.stockReceiptPending,
        targetId: 'doc-123',
      );

      expect(
        PushNotificationHandler.stockDocFallbackMessage(payload),
        'Phiếu nhập doc-123 — chi tiết sẽ có khi module Phiếu ra mắt',
      );
    });

    test('includes target id for stock issue', () {
      const payload = PushNotificationPayload(
        data: {},
        type: PushNotificationTypes.stockIssueApproved,
        targetId: 'ix-9',
      );

      expect(
        PushNotificationHandler.stockDocFallbackMessage(payload),
        'Phiếu xuất ix-9 — chi tiết sẽ có khi module Phiếu ra mắt',
      );
    });
  });

  group('PushNotificationHandler.handle', () {
    test('queues payload until auth is ready', () async {
      final handler = PushNotificationHandler(authRepository: authRepository);

      await handler.handle(const {
        'type': PushNotificationTypes.general,
        'title': 'Hello',
      });

      verifyNever(() => authRepository.isLoggedIn());
    });

    test('defers when user is not logged in', () async {
      when(() => authRepository.isLoggedIn()).thenAnswer((_) async => false);
      final handler = PushNotificationHandler(authRepository: authRepository)
        ..markAuthReady();

      await handler.handle(const {
        'type': PushNotificationTypes.general,
      });

      verify(() => authRepository.isLoggedIn()).called(1);
      verifyNever(() => authRepository.selectTenant(any()));
    });

    test('switches tenant for stock notification', () async {
      when(() => authRepository.isLoggedIn()).thenAnswer((_) async => true);
      when(() => authRepository.selectTenant(any())).thenAnswer((_) async {});

      final handler = PushNotificationHandler(authRepository: authRepository)
        ..markAuthReady();

      await handler.handle(const {
        'type': PushNotificationTypes.stockReceiptPending,
        'tenantId': 'tenant-1',
        'targetId': 'doc-1',
      });

      verify(() => authRepository.selectTenant('tenant-1')).called(1);
    });
  });
}
