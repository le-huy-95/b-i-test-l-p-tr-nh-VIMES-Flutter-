import 'package:test_y_app/core/constants/env_config.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static const String baseApi = '/api/v1';

  static const String authBase = '$baseApi/auth';
  static const String authLogin = '$authBase/login';
  static const String authRegister = '$authBase/register';
  static const String authVerifyOtp = '$authBase/verify-otp';
  static const String authResendOtp = '$authBase/resend-otp';
  static const String authLoginGoogle = '$authBase/login/google';
  static const String authRefresh = '$authBase/refresh';
  static const String authInvitationsAccept = '$authBase/invitations/accept';
  static const String authInvitationsDecline = '$authBase/invitations/decline';

  /// Alias — points to new `/auth/refresh` path (was `refresh-token`).
  static const String authRefreshToken = authRefresh;
  static const String authMe = '$authBase/me';
  static const String authTenants = '$authBase/tenants';
  static const String authLogout = '$authBase/logout';
  static const String authRegisterDevice = '$authBase/register-device';
  static const String authForgotPassword = '$authBase/forgot-password';
  static const String authResetPassword = '$authBase/reset-password';

  static const String tenantsCurrentLogo = '$baseApi/tenants/current/logo';
  static const String tenantsCurrentMembers = '$baseApi/tenants/current/members';
  static const String tenantsCurrentInvitations = '$baseApi/tenants/current/invitations';
  static const String tenantsCurrentUsers = '$baseApi/tenants/current/users';

  static const String usersBase = '$baseApi/customers';

  /// Legacy path; prefer [authMe] for auth profile.
  static const String usersMe = '$usersBase/me';

  /// Demo endpoint (JSONPlaceholder) — dùng để test API layer.
  static const String demoPosts = '/posts';
  static String demoPost(String id) => '/posts/$id';

  static const String warehouses = '$baseApi/warehouses';
  static String warehouse(String id) => '$warehouses/$id';
  static String warehouseActivate(String id) => '$warehouses/$id/activate';
  static String warehouseDeactivate(String id) => '$warehouses/$id/deactivate';

  static const String products = '$baseApi/products';
  static String product(String id) => '$products/$id';
  static String productAvailability(String id) => '$products/$id/availability';

  static const String stockIssues = '$baseApi/stock-issues';
  static String stockIssue(String id) => '$stockIssues/$id';
  static const String stockReceipts = '$baseApi/stock-receipts';
  static String stockReceipt(String id) => '$stockReceipts/$id';
  static const String customers = '$baseApi/customers';
  static const String suppliers = '$baseApi/suppliers';
  static const String tenantContacts = '$baseApi/tenant/contacts';

  static const String organizationOverview =
      '$baseApi/reports/organization-overview';

  static const String files = '$baseApi/files';
  static const String documentWorkflows = '$baseApi/document-workflows';
  static String workflowList = documentWorkflows;
  static String workflowDetail(String documentType, String id) =>
      '$documentWorkflows/$documentType/$id';
  static String workflowActions(String documentType, String id) =>
      '$documentWorkflows/$documentType/$id/actions';
  static String workflowAssign(String documentType, String id, String stepId) =>
      '$documentWorkflows/$documentType/$id/steps/$stepId/assignee';
  static String workflowUploadAuthorization(
    String documentType,
    String id,
    String stepId,
  ) =>
      '$documentWorkflows/$documentType/$id/steps/$stepId/authorizations';
  static String workflowTimeline(String documentType, String id) =>
      '$documentWorkflows/$documentType/$id/timeline';
  static String workflowAvailableActions(String documentType, String id) =>
      '$documentWorkflows/$documentType/$id/available-actions';

  static String get notifApiBase => EnvConfig.notificationApiUrl;
  static String get notifUnreadCount => '$notifApiBase/notifications/unread-count';
  static String get notifList => '$notifApiBase/notifications';
  static String get notifMarkRead => '$notifApiBase/notifications/mark-read';
}
