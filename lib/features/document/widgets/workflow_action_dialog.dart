import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:test_y_app/data/datasources/api_services/tenant_people_api_service.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class WorkflowActionRequest {
  const WorkflowActionRequest({
    required this.action,
    required this.stepId,
    this.note,
    this.proxySignerId,
    this.authorizationIds = const [],
  });

  final String action;
  final String stepId;
  final String? note;
  final String? proxySignerId;
  final List<String> authorizationIds;

  Map<String, dynamic> toBody() => {
        'action': action,
        'stepId': stepId,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        if (proxySignerId != null && proxySignerId!.trim().isNotEmpty)
          'proxySignerId': proxySignerId!.trim(),
        if (authorizationIds.isNotEmpty) 'authorizationIds': authorizationIds,
      };
}

class WorkflowActionDialog extends StatefulWidget {
  const WorkflowActionDialog({
    super.key,
    required this.title,
    required this.stepId,
    required this.action,
    required this.fileRepository,
    required this.needsProxy,
    required this.needsAuthorization,
    required this.needsNote,
  });

  final String title;
  final String stepId;
  final String action;
  final FileRepository fileRepository;
  final bool needsProxy;
  final bool needsAuthorization;
  final bool needsNote;

  static Future<WorkflowActionRequest?> show(
    BuildContext context, {
    required String title,
    required String stepId,
    required String action,
    required FileRepository fileRepository,
    bool needsProxy = false,
    bool needsAuthorization = false,
    bool needsNote = false,
  }) {
    return showDialog<WorkflowActionRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WorkflowActionDialog(
        title: title,
        stepId: stepId,
        action: action,
        fileRepository: fileRepository,
        needsProxy: needsProxy,
        needsAuthorization: needsAuthorization,
        needsNote: needsNote,
      ),
    );
  }

  @override
  State<WorkflowActionDialog> createState() => _WorkflowActionDialogState();
}

class _WorkflowActionDialogState extends State<WorkflowActionDialog> {
  final _noteController = TextEditingController();
  final _peopleApi = TenantPeopleApiService();
  bool _loadingMembers = true;
  bool _uploadingAuthorization = false;
  List<TenantMember> _members = const [];
  String? _proxySignerId;
  final List<String> _authorizationIds = [];
  final List<String> _authorizationNames = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (!widget.needsProxy) {
      if (!mounted) return;
      setState(() => _loadingMembers = false);
      return;
    }
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
        final uploaded = await widget.fileRepository.upload(file, kind: 'authorization');
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
      SimpleSnackbarService.showError(message);
    } finally {
      if (mounted) setState(() => _uploadingAuthorization = false);
    }
  }

  void _submit() {
    if (widget.needsProxy && (_proxySignerId == null || _proxySignerId!.isEmpty)) {
      setState(() => _error = 'Vui lòng chọn người duyệt khác');
      return;
    }
    if (widget.needsAuthorization && _authorizationIds.isEmpty) {
      setState(() => _error = 'Vui lòng chọn chứng từ ủy quyền');
      return;
    }
    Navigator.of(context).pop(
      WorkflowActionRequest(
        action: widget.action,
        stepId: widget.stepId,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        proxySignerId: _proxySignerId,
        authorizationIds: List<String>.from(_authorizationIds),
      ),
    );
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.needsNote) ...[
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú / lý do',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.needsProxy) ...[
                const Text(
                  'Chọn người duyệt khác trong doanh nghiệp',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_loadingMembers)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red))
                else if (_members.isEmpty)
                  const Text('Không có người duyệt phù hợp')
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
                    onChanged: (value) => setState(() => _proxySignerId = value),
                  ),
                const SizedBox(height: 12),
              ],
              if (widget.needsAuthorization) ...[
                const Text(
                  'Chứng từ ủy quyền',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _uploadingAuthorization ? null : _pickAuthorizationFiles,
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
                          const Icon(Icons.insert_drive_file_outlined, size: 18),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
