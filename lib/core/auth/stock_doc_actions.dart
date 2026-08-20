import 'package:test_y_app/core/auth/tenant_permissions.dart';

enum StockDocAction { submit, approve, reject, skip, proxySign, complete, cancel, clone }

const stockWorkflowStepStatuses = <String>{
  'pending',
  'waiting',
  'in_review',
  'approved',
  'delegated',
  'rejected',
  'skipped',
  'cancelled',
};

const stockDocumentStatuses = <String>{
  'draft',
  'in_review',
  'pending_approval',
  'approved',
  'rejected',
  'completed',
  'cancelled',
};

String stockDocStatusLabel(String status) {
  return switch (status) {
    'draft' => 'Nháp',
    'pending' => 'Chờ duyệt',
    'waiting' => 'Chờ duyệt',
    'in_review' => 'Đang duyệt',
    'pending_approval' => 'Chờ duyệt',
    'approved' => 'Đã duyệt',
    'delegated' => 'Đã ủy quyền',
    'rejected' => 'Từ chối',
    'skipped' => 'Bỏ qua',
    'completed' => 'Hoàn tất',
    'cancelled' => 'Đã hủy',
    _ => status,
  };
}

String issueTypeLabel(String type) {
  return switch (type) {
    'sale' => 'Xuất bán',
    'internal_use' => 'Nội bộ',
    'return_to_supplier' => 'Trả NCC',
    'disposal' => 'Tiêu hủy',
    _ => type,
  };
}

String workflowStepLabel(String stepCode) {
  return switch (stepCode) {
    'step_1' => 'Bước 1',
    'step_2' => 'Bước 2',
    'step_3' => 'Bước 3',
    'step_4' => 'Bước 4',
    'creator' => 'Người tạo',
    'reviewer' => 'Người duyệt',
    'approver' => 'Người phê duyệt',
    'accountant' => 'Kế toán',
    'warehouse' => 'Thủ kho',
    _ => _humanizeStepCode(stepCode),
  };
}

String _humanizeStepCode(String stepCode) {
  final normalized = stepCode.trim();
  if (normalized.isEmpty) return '—';
  return normalized
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

bool isWorkflowStepActive(String status) {
  return status == 'pending' ||
      status == 'waiting' ||
      status == 'in_review' ||
      status == 'delegated';
}

List<StockDocAction> visibleReceiptActions({
  required String status,
  required String role,
}) {
  return _visible(status: status, role: role, includeClone: true);
}

List<StockDocAction> visibleIssueActions({
  required String status,
  required String role,
}) {
  return _visible(status: status, role: role, includeClone: false);
}

List<StockDocAction> _visible({
  required String status,
  required String role,
  required bool includeClone,
}) {
  final actions = <StockDocAction>[];
  final isDraft = status == 'draft';
  final isReview = status == 'pending_approval' || status == 'in_review';
  final isApproved = status == 'approved';
  final isRejected = status == 'rejected';

  if (isDraft) {
    if (canCreateOrSubmitStockDoc(role)) actions.add(StockDocAction.submit);
    if (canCancelStockDoc(role)) actions.add(StockDocAction.cancel);
  }

  if (isReview) {
    if (canApproveOrCompleteStockDoc(role)) {
      actions.add(StockDocAction.approve);
      actions.add(StockDocAction.reject);
    }
    if (canCancelStockDoc(role)) actions.add(StockDocAction.cancel);
  }

  if (isApproved) {
    if (canApproveOrCompleteStockDoc(role)) {
      actions.add(StockDocAction.complete);
    }
    if (canCancelStockDoc(role)) actions.add(StockDocAction.cancel);
  }

  if (isRejected && includeClone && canCreateOrSubmitStockDoc(role)) {
    actions.add(StockDocAction.clone);
  }

  return actions;
}

String workflowActionLabel(StockDocAction action) {
  return switch (action) {
    StockDocAction.submit => 'Gửi duyệt',
    StockDocAction.approve => 'Phê duyệt',
    StockDocAction.reject => 'Từ chối',
    StockDocAction.skip => 'Bỏ qua',
    StockDocAction.proxySign => 'Ký thay',
    StockDocAction.complete => 'Hoàn tất',
    StockDocAction.cancel => 'Hủy phiếu',
    StockDocAction.clone => 'Tạo lại',
  };
}

String workflowActionCode(StockDocAction action) {
  return switch (action) {
    StockDocAction.submit => 'submit',
    StockDocAction.approve => 'approve',
    StockDocAction.reject => 'reject',
    StockDocAction.skip => 'skip',
    StockDocAction.proxySign => 'proxy_sign',
    StockDocAction.complete => 'complete',
    StockDocAction.cancel => 'cancel',
    StockDocAction.clone => 'submit',
  };
}
