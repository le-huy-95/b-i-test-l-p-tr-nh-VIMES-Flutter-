import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/core/firebase/push_notification_payload.dart';

void main() {
  group('PushNotificationPayload', () {
    test('fromRemoteMessage uses notification block', () {
      final message = RemoteMessage(
        notification: const RemoteNotification(
          title: 'Phiếu nhập chờ duyệt',
          body: 'PN-2026-001',
        ),
        data: const {
          'type': 'stock_receipt_pending',
          'tenantId': 't1',
          'targetId': 'doc1',
        },
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.title, 'Phiếu nhập chờ duyệt');
      expect(payload.body, 'PN-2026-001');
      expect(payload.type, 'stock_receipt_pending');
      expect(payload.tenantId, 't1');
      expect(payload.targetId, 'doc1');
      expect(payload.hasDisplayContent, isTrue);
    });

    test('fromRemoteMessage falls back to data title/body', () {
      final message = RemoteMessage(
        data: const {
          'type': 'general',
          'title': 'Thông báo',
          'body': 'Nội dung data-only',
        },
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.title, 'Thông báo');
      expect(payload.body, 'Nội dung data-only');
      expect(payload.type, 'general');
      expect(payload.hasDisplayContent, isTrue);
    });

    test('hasDisplayContent is false when empty', () {
      const payload = PushNotificationPayload(data: {'type': 'general'});
      expect(payload.hasDisplayContent, isFalse);
    });
  });
}
