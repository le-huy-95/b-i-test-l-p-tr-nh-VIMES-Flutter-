abstract final class PushNotificationTypes {
  static const stockReceiptPending = 'stock_receipt_pending';
  static const stockReceiptApproved = 'stock_receipt_approved';
  static const stockIssuePending = 'stock_issue_pending';
  static const stockIssueApproved = 'stock_issue_approved';
  static const inviteReceived = 'invite_received';
  static const general = 'general';

  static const stockDocTypes = {
    stockReceiptPending,
    stockReceiptApproved,
    stockIssuePending,
    stockIssueApproved,
  };
}
