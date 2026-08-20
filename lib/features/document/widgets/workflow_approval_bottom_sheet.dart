import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/data/datasources/api_services/tenant_people_api_service.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';

/// Request object for step-level workflow actions.
/// Mirrors [WorkflowActionDialog] in behavior but renders as a bottom sheet.
class WorkflowActionRequest {
  const WorkflowActionRequest({
    required this.action,
    this.note,
    this.proxySignerId,
    this.authorizationIds = const [],
  });

  final String action;
  final String? note;
  final String? proxySignerId;
  final List<String> authorizationIds;

  Map<String, dynamic> toBody() => {
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    if (proxySignerId != null && proxySignerId!.trim().isNotEmpty)
      'proxySignerId': proxySignerId!.trim(),
    if (authorizationIds.isNotEmpty) 'authorizationIds': authorizationIds,
  };
}

class WorkflowApprovalBottomSheet extends StatefulWidget {
  const WorkflowApprovalBottomSheet({
    super.key,
    required this.stepName,
    required this.stepId,
    required this.actions,
    required this.onSubmit,
    this.fileRepository,
  });

  final String stepName;
  final String stepId;

  /// Actions available for this step, e.g. ['approve', 'reject', 'skip', 'proxy_sign'].
  final List<String> actions;
  final Future<void> Function(
    String action,
    String? note,
    String? proxySignerId,
    List<String> authorizationIds,
  )
  onSubmit;
  final FileRepository? fileRepository;

  static Future<void> show(
    BuildContext context, {
    required String stepName,
    required String stepId,
    required List<String> actions,
    required Future<void> Function(
      String action,
      String? note,
      String? proxySignerId,
      List<String> authorizationIds,
    )
    onSubmit,
    FileRepository? fileRepository,
  }) {
    return AppBottomSheetService.show<void>(
      context: context,
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      content: WorkflowApprovalBottomSheet(
        stepName: stepName,
        stepId: stepId,
        actions: actions,
        onSubmit: onSubmit,
        fileRepository: fileRepository,
      ),
      actions: const [],
    );
  }

  @override
  State<WorkflowApprovalBottomSheet> createState() =>
      _WorkflowApprovalBottomSheetState();
}

class _WorkflowApprovalBottomSheetState
    extends State<WorkflowApprovalBottomSheet> {
  final _noteController = TextEditingController();
  final _peopleApi = TenantPeopleApiService();
  bool _submitting = false;
  String? _error;

  // Proxy sign state
  bool _loadingMembers = false;
  List<TenantMember> _members = const [];
  String? _proxySignerId;

  // Authorization files state
  bool _uploadingAuthorization = false;
  final List<String> _authorizationIds = [];
  final List<String> _authorizationNames = [];

  bool get _hasApprove => widget.actions.contains('approve');
  bool get _hasReject => widget.actions.contains('reject');
  bool get _hasSkip => widget.actions.contains('skip');
  bool get _hasProxySign => widget.actions.contains('proxy_sign');

  @override
  void initState() {
    super.initState();
    if (_hasSkip) {
      _noteController.text =
          'Bỏ qua bước giao hàng (không có người giao hàng ngoài)';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (_members.isNotEmpty || _loadingMembers) return;
    setState(() => _loadingMembers = true);
    try {
      final result = await _peopleApi.fetchMembers(page: 1, limit: 200);
      if (!mounted) return;
      setState(() {
        _members = result.items.where((m) => m.isActive).toList();
        _loadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingMembers = false;
      });
    }
  }

  Future<void> _pickAuthorizationFiles() async {
    final repo = widget.fileRepository;
    if (repo == null) return;

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;

    setState(() {
      _uploadingAuthorization = true;
      _error = null;
    });

    try {
      final uploadedIds = <String>[];
      final uploadedNames = <String>[];
      for (final file in picked.files) {
        final uploaded = await repo.upload(file, kind: 'authorization');
        uploadedIds.add(uploaded.id);
        uploadedNames.add(uploaded.originalName);
      }
      if (!mounted) return;
      setState(() {
        _authorizationIds
          ..clear()
          ..addAll(uploadedIds);
        _authorizationNames
          ..clear()
          ..addAll(uploadedNames);
      });
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _uploadingAuthorization = false);
    }
  }

  String? _validateSubmit(String action) {
    if (action == 'reject' && _noteController.text.trim().isEmpty) {
      return 'Vui lòng nhập lý do từ chối';
    }
    if (action == 'skip' && _noteController.text.trim().isEmpty) {
      return 'Vui lòng nhập lý do bỏ qua';
    }
    if (action == 'proxy_sign') {
      if (_proxySignerId == null || _proxySignerId!.isEmpty) {
        return 'Vui lòng chọn người duyệt thay';
      }
      if (_authorizationIds.isEmpty) {
        return 'Vui lòng upload chứng từ ủy quyền';
      }
    }
    return null;
  }

  Future<void> _handleSubmit(String action) async {
    if (_submitting) return;

    // Load members when proxy sign is triggered
    if (action == 'proxy_sign' && _members.isEmpty) {
      _loadMembers();
      // Show validation if still no selection after loading attempt
      if (_proxySignerId == null && !_loadingMembers) return;
    }

    final validationError = _validateSubmit(action);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() => _submitting = true);
    _error = null;
    try {
      await widget.onSubmit(
        action,
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        _proxySignerId,
        _authorizationIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _memberLabel(TenantMember member) {
    final parts = <String>[
      if ((member.name ?? '').trim().isNotEmpty) member.name!.trim(),
      if ((member.email ?? '').trim().isNotEmpty) member.email!.trim(),
      if ((member.phone ?? '').trim().isNotEmpty) member.phone!.trim(),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorSkin.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ColorSkin.grey3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hành động — ${widget.stepName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),

                // Proxy signer selection
                if (_hasProxySign) ...[
                  const Text(
                    'Ký thay',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingMembers)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_members.isEmpty)
                    OutlinedButton(
                      onPressed: _loadMembers,
                      child: const Text('Tải danh sách người duyệt'),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _proxySignerId,
                      decoration: const InputDecoration(
                        labelText: 'Người duyệt thay',
                      ),
                      items: [
                        for (final member in _members)
                          DropdownMenuItem(
                            value: member.userId,
                            child: Text(_memberLabel(member)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _proxySignerId = value),
                    ),
                  const SizedBox(height: 12),

                  // Authorization files
                  const Text(
                    'Chứng từ ủy quyền',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _uploadingAuthorization
                        ? null
                        : _pickAuthorizationFiles,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _authorizationNames.isEmpty
                          ? 'Chọn và upload chứng từ'
                          : 'Đã upload ${_authorizationNames.length} file',
                    ),
                  ),
                  if (_authorizationNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final name in _authorizationNames)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(name)),
                          ],
                        ),
                      ),
                  ],
                  if (_uploadingAuthorization) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                ],

                // Note field
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: _hasSkip || _hasProxySign
                        ? 'Lý do (*)'
                        : 'Ghi chú',
                    hintText: 'Nhập ghi chú (tuỳ chọn)',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: ColorSkin.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Action buttons
                if (_hasProxySign) ...[
                  // Proxy sign - single button
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Ký thay',
                      onPressed: _submitting
                          ? null
                          : () => _handleSubmit('proxy_sign'),
                      variant: AppButtonVariant.primary,
                      isLoading: _submitting,
                    ),
                  ),
                ] else if (_hasApprove || _hasReject) ...[
                  // Approve/Reject buttons
                  Row(
                    children: [
                      if (_hasReject)
                        Expanded(
                          child: AppButton(
                            label: 'Từ chối',
                            onPressed: _submitting
                                ? null
                                : () => _handleSubmit('reject'),
                            variant: AppButtonVariant.outlined,
                            isLoading: _submitting,
                          ),
                        ),
                      if (_hasReject && _hasApprove) const SizedBox(width: 12),
                      if (_hasApprove)
                        Expanded(
                          child: AppButton(
                            label: 'Phê duyệt',
                            onPressed: _submitting
                                ? null
                                : () => _handleSubmit('approve'),
                            variant: AppButtonVariant.primary,
                            isLoading: _submitting,
                          ),
                        ),
                    ],
                  ),
                ],

                if (_hasSkip) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Bỏ qua bước này',
                      onPressed: _submitting
                          ? null
                          : () => _handleSubmit('skip'),
                      variant: AppButtonVariant.outlined,
                      isLoading: _submitting,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
