import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';

String stockDocumentDisplayCode(StockDocument document) {
  final code = document.code?.trim();
  if (code != null && code.isNotEmpty) return code;

  final prefix = document.documentType == 'stock_receipt' ? 'PN' : 'PX';
  final id = document.documentId.trim();
  if (id.isEmpty) return prefix;

  final suffix = id.length > 6 ? id.substring(id.length - 6) : id;
  return '$prefix-${suffix.toUpperCase()}';
}

String stockDocumentTypeLabel(String type) {
  return switch (type) {
    'stock_issue' => 'Lệnh xuất hàng',
    'stock_receipt' => 'Lệnh nhập hàng',
    _ => type,
  };
}

String stockDocumentCurrentStepLabel(StockDocument document) {
  final stepCode = document.currentStepCode?.trim();
  if (stepCode == null || stepCode.isEmpty) return '—';

  for (final step in document.steps) {
    if (step.stepCode == stepCode && step.stepName.trim().isNotEmpty) {
      return step.stepName;
    }
  }

  return workflowStepLabel(stepCode);
}

String stockDocumentRelativeUpdateLabel(DateTime? updatedAt) {
  if (updatedAt == null) return '—';

  final now = DateTime.now();
  final diff = now.difference(updatedAt);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return '${updatedAt.day.toString().padLeft(2, '0')}/'
      '${updatedAt.month.toString().padLeft(2, '0')}/'
      '${updatedAt.year}';
}
