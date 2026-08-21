import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/datasources/api_services/contact_api_service.dart';
import 'package:test_y_app/data/datasources/api_services/customer_api_service.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';
import 'package:test_y_app/features/document/workflow_approval_utils.dart';
import 'package:test_y_app/features/document/widgets/workflow_approval_bottom_sheet.dart';
import 'package:test_y_app/features/document/widgets/workflow_signature_row.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/data/datasources/api_services/tenant_people_api_service.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';
import 'package:test_y_app/domain/repositories/stock_issue_repository.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/document/services/stock_doc_pdf_service.dart';
import 'package:test_y_app/features/document/widgets/partner_select_dialog.dart';
import 'package:test_y_app/features/document/widgets/contact_create_sheet.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_date_field.dart';
import 'package:test_y_app/shared/widgets/app_field_label_action.dart';
import 'package:test_y_app/shared/widgets/app_form_stepper.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:test_y_app/shared/widgets/app_number_field.dart';
import 'package:test_y_app/shared/widgets/app_text_field.dart';
import 'package:test_y_app/shared/widgets/select_field.dart';

class StockIssueFormPageLauncher extends StatelessWidget {
  const StockIssueFormPageLauncher({
    super.key,
    required this.repository,
    this.issueId,
  });

  final StockIssueRepository repository;
  final String? issueId;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: repository,
      child: const _StockIssueFormHost(),
    );
  }
}

class _StockIssueFormHost extends StatelessWidget {
  const _StockIssueFormHost();

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WarehouseRepository>(
          create: (_) => context.read<WarehouseRepository>(),
        ),
        RepositoryProvider<ProductRepository>(
          create: (_) => context.read<ProductRepository>(),
        ),
        RepositoryProvider<StockIssueRepository>(
          create: (_) => context.read<StockIssueRepository>(),
        ),
      ],
      child: const _StockIssueFormScreen(),
    );
  }
}

class StockIssueFormPage extends StatelessWidget {
  const StockIssueFormPage({super.key, this.issueId});

  final String? issueId;

  @override
  Widget build(BuildContext context) => _StockIssueFormScreen(issueId: issueId);
}

class _StockIssueFormScreen extends StatefulWidget {
  const _StockIssueFormScreen({this.issueId});

  final String? issueId;

  @override
  State<_StockIssueFormScreen> createState() => _StockIssueFormScreenState();
}

class _StockIssueFormScreenState extends State<_StockIssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _issueDate = TextEditingController();
  final _deliveryApproverController = TextEditingController();

  final _warehouseKeeperController = TextEditingController();
  final _chiefAccountantController = TextEditingController();
  final _lines = <_IssueLineDraft>[];

  String? _customerId;
  List<Warehouse> _warehouses = const [];
  List<Product> _products = const [];
  List<PartnerSelectDialogItem> _customers = const [];
  List<TenantMember> _approvers = const [];

  // Delivery contact state
  String? _deliveryContactId;
  List<PartnerSelectDialogItem> _deliveryContacts = const [];
  final _contactApi = ContactApiService();
  String? _selectedWarehouseId;
  String _issueType = 'sale';
  bool _loading = true;
  bool _saving = false;
  bool _seeded = false;
  int _currentStep = 0;
  String? _error;
  StockIssueDocumentData? _existing;
  StockDocument? _workflow;
  AvailableActions? _availableActions;
  bool _workflowActionSubmitting = false;
  final Map<String, double> _productStock = {};

  bool get _isEdit => widget.issueId != null;

  @override
  void initState() {
    super.initState();
    _issueDate.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _issueDate.dispose();
    _deliveryApproverController.dispose();
    _warehouseKeeperController.dispose();
    _chiefAccountantController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final warehouseRepo = context.read<WarehouseRepository>();
      final productRepo = context.read<ProductRepository>();
      final issueRepo = context.read<StockIssueRepository>();
      final peopleRepo = TenantPeopleApiService();
      final customerApi = CustomerApiService();
      final results = await Future.wait([
        warehouseRepo.list(),
        productRepo.list(),
        mapCustomersToPartnerItems(),
        peopleRepo.fetchMembers(limit: 200),
        customerApi.list(),
        if (widget.issueId != null) issueRepo.getById(widget.issueId!),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0] as List<Warehouse>;
        _products = results[1] as List<Product>;
        _customers = results[2] as List<PartnerSelectDialogItem>;
        final memberPage = results[3] as TenantMemberPageResult;
        _approvers = memberPage.items.where((m) => m.isActive).toList();
        final customers = results[4] as List<CustomerOption>;
        if (_customerId == null && customers.isNotEmpty) {
          _customerId = customers.first.id;
        }
        if (widget.issueId != null) {
          _existing = results[5] as StockIssueDocumentData;
        }
        if (_warehouses.isNotEmpty && _selectedWarehouseId == null) {
          _selectedWarehouseId = _warehouses.first.id;
        }
        if (_existing != null && !_seeded) _seedFromExisting(_existing!);
        if (_lines.isEmpty) _lines.add(_IssueLineDraft());
        _applyDefaultDeliveryApprover();
        _applyDefaultChiefAccountant();
        _loading = false;
      });
      await _loadProductStock();
      await _loadDeliveryContacts();
      if (_isEdit) await _loadWorkflow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    }
  }

  Future<void> _loadWorkflow() async {
    final issueId = widget.issueId;
    if (issueId == null) return;
    try {
      final repo = context.read<StockDocumentRepository>();
      final workflowFuture = repo.getDetail('stock_issue', issueId);
      final availableFuture = repo.availableActions('stock_issue', issueId);
      final results = await Future.wait([workflowFuture, availableFuture]);
      if (!mounted) return;
      final workflow = results[0] as StockDocument;
      final available = results[1] as AvailableActions;
      setState(() {
        _workflow = workflow;
        _availableActions = available;
        seedApproverControllersFromWorkflowSteps(
          steps: workflow.steps,
          setDeliveryApprover: (id) => _deliveryApproverController.text = id,
          setWarehouseKeeper: (id) => _warehouseKeeperController.text = id,
          setChiefAccountant: (id) => _chiefAccountantController.text = id,
          hasDeliveryApprover: () =>
              _deliveryApproverController.text.trim().isNotEmpty,
          hasWarehouseKeeper: () =>
              _warehouseKeeperController.text.trim().isNotEmpty,
          hasChiefAccountant: () =>
              _chiefAccountantController.text.trim().isNotEmpty,
        );
      });
    } catch (_) {
      // Workflow là dữ liệu bổ sung, không chặn form.
    }
  }

  Future<void> _submitWorkflowAction({
    required WorkflowStep step,
    required String action,
    String? note,
    String? proxySignerId,
    List<String> authorizationIds = const [],
  }) async {
    final issueId = widget.issueId;
    if (issueId == null) return;
    setState(() => _workflowActionSubmitting = true);
    try {
      final body = <String, dynamic>{
        'action': action,
        'stepId': step.id,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (proxySignerId != null && proxySignerId.trim().isNotEmpty)
          'proxySignerId': proxySignerId.trim(),
        if (authorizationIds.isNotEmpty) 'authorizationIds': authorizationIds,
      };
      await context.read<StockDocumentRepository>().action(
        'stock_issue',
        issueId,
        body,
      );
      if (!mounted) return;
      SimpleSnackbarService.showSuccess(switch (action) {
        'approve' => 'Đã phê duyệt phiếu',
        'reject' => 'Đã từ chối phiếu',
        'skip' => 'Đã bỏ qua bước này',
        'proxy_sign' => 'Đã ký thay',
        _ => 'Đã thực hiện hành động',
      });
      await _load();
    } catch (e) {
      if (mounted) SimpleSnackbarService.showError(_friendly(e));
    } finally {
      if (mounted) setState(() => _workflowActionSubmitting = false);
    }
  }

  Future<void> _openWorkflowApproval(WorkflowStep step, String action) async {
    final availableActions = _availableActions;
    final stepActions = _buildStepAvailableActions(step.id, availableActions);
    await WorkflowApprovalBottomSheet.show(
      context,
      stepName: step.stepName,
      stepId: step.id,
      actions: stepActions,
      fileRepository: context.read<FileRepository>(),
      onSubmit: (selectedAction, note, proxySignerId, authorizationIds) =>
          _submitWorkflowAction(
            step: step,
            action: selectedAction,
            note: note,
            proxySignerId: proxySignerId,
            authorizationIds: authorizationIds,
          ),
    );
  }

  Widget _buildWorkflowApprovalButtons() {
    final workflow = _workflow;
    final userId = _currentUserId;
    if (workflow == null || userId == null) return const SizedBox.shrink();

    final buttons = <Widget>[];

    for (final slot in WorkflowSignatureSlot.values) {
      final step = workflowStepForSlot(slot, workflow.steps);
      if (step == null) continue;
      if (!canUserApproveSignatureSlot(
        slot: slot,
        steps: workflow.steps,
        userId: userId,
        userRole: currentTenantRoleFromAuthState(
          context.read<AuthBloc>().state,
        ),
        assignedApproverIds: _buildWorkflowAssignedApproverIds(),
        documentStatus: workflow.status,
      )) {
        continue;
      }

      final label = switch (slot) {
        WorkflowSignatureSlot.deliveryApprover => 'Người giao hàng',
        WorkflowSignatureSlot.warehouseKeeper => 'Thủ kho',
        WorkflowSignatureSlot.chiefAccountant => 'Kế toán trưởng',
      };

      buttons.add(
        FilledButton.tonal(
          onPressed: _workflowActionSubmitting
              ? null
              : () => _openWorkflowApproval(
                  step,
                  _buildStepAvailableActions(
                    step.id,
                    _availableActions,
                  ).firstWhere((a) => a == 'approve', orElse: () => 'approve'),
                ),
          child: Text('Phê duyệt — $label'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Future<void> _loadProductStock() async {
    if (_products.isEmpty) return;
    final productRepo = context.read<ProductRepository>();
    try {
      final entries = await Future.wait(
        _products.map((p) => productRepo.getAvailability(p.id)),
      );
      if (!mounted) return;
      final stock = <String, double>{};
      for (final avail in entries) {
        stock[avail.productId] = avail.totalAvailable;
      }
      setState(() => _productStock.addAll(stock));
    } catch (_) {
      // tồn kho là dữ liệu bổ sung, không chặn form
    }
  }

  Future<void> _loadDeliveryContacts() async {
    try {
      final contacts = await _contactApi.listDeliveryPersons();
      final items = mapDeliveryContactsToPartnerItems(contacts);
      if (!mounted) return;
      setState(() => _deliveryContacts = items);
    } catch (_) {
      // Contact list không bắt buộc
    }
  }

  Future<List<PartnerSelectDialogItem>> _refreshDeliveryContacts() async {
    await _loadDeliveryContacts();
    return _deliveryContacts;
  }

  Future<void> _showContactCreateSheet() async {
    final created = await ContactCreateSheet.show(
      context,
      onCreated:
          ({
            required String fullName,
            String? phone,
            String? companyName,
            String? note,
          }) => _contactApi.createDeliveryPerson(
            fullName: fullName,
            phone: phone,
            companyName: companyName,
            note: note,
          ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _deliveryContacts = [
        ..._deliveryContacts,
        PartnerSelectDialogItem(
          id: created.id,
          title: created.fullName,
          subtitle: [
            if (created.phone != null && created.phone!.isNotEmpty)
              created.phone!,
            if (created.companyName != null && created.companyName!.isNotEmpty)
              created.companyName!,
          ].join(' · '),
        ),
      ];
      _deliveryContactId = created.id;
    });
  }

  void _seedFromExisting(StockIssueDocumentData existing) {
    _selectedWarehouseId = existing.warehouseId;
    _issueType = existing.issueType;
    _issueDate.text = DateFormat('dd/MM/yyyy').format(existing.issueDate);
    _customerId = existing.customerId;
    _note.text = existing.note ?? '';
    _deliveryContactId = existing.deliveredByContactId;
    _lines
      ..clear()
      ..addAll(
        existing.lines.map(
          (line) => _IssueLineDraft(
            productId: line.productId,
            unitName: line.unitName,
            requestedQty: line.requestedQty.toString(),
            actualQty: line.actualQty.toString(),
            unitPrice: line.unitPrice.toString(),
          ),
        ),
      );
    if (_lines.isEmpty) _lines.add(_IssueLineDraft());
    _seeded = true;
  }

  void _applyDefaultDeliveryApprover() {
    if (_deliveryApproverController.text.isNotEmpty) return;
    final userId = _currentUserId;
    if (userId == null) return;
    final role = currentTenantRoleFromAuthState(context.read<AuthBloc>().state);
    if (role == null) return;
    final normalized = normalizeTenantRole(role);
    if (normalized != 'warehouse_keeper' && normalized != 'admin') return;
    _deliveryApproverController.text = userId;
  }

  void _applyDefaultChiefAccountant() {
    if (_chiefAccountantController.text.isNotEmpty) return;
    final userId = _currentUserId;
    final role = currentTenantRoleFromAuthState(context.read<AuthBloc>().state);
    if (userId == null || role == null) return;
    if (normalizeTenantRole(role) != 'accountant') return;
    _chiefAccountantController.text = userId;
  }

  List<String> _buildWorkflowAssignedApproverIds() {
    final delivery = _deliveryApproverController.text.trim();
    final warehouse = _warehouseKeeperController.text.trim();
    final accountant = _chiefAccountantController.text.trim();
    // Slot giao hàng không còn chọn trên form — fallback thủ kho.
    return [delivery.isNotEmpty ? delivery : warehouse, warehouse, accountant];
  }

  List<String> _buildStepAvailableActions(
    String stepId,
    AvailableActions? available,
  ) {
    if (available == null) return ['approve', 'reject'];
    if (available.currentStepId == stepId) {
      return available.actions;
    }
    // If this step is not the current step, return empty
    return [];
  }

  Map<String, StepAvailableActions>? _buildStepAvailableActionsMap(
    List<WorkflowStep> steps,
    AvailableActions? available,
  ) {
    if (available == null) return null;
    final map = <String, StepAvailableActions>{};
    for (final step in steps) {
      if (available.currentStepId == step.id) {
        map[step.id] = StepAvailableActions(
          stepId: step.id,
          actions: available.actions,
        );
      }
    }
    return map;
  }

  List<TenantMember> _membersForRole(String role) {
    final normalized = normalizeTenantRole(role);
    return _approvers.where((member) {
      final memberRole = normalizeTenantRole(member.role);
      return memberRole == normalized || memberRole == 'admin';
    }).toList();
  }

  String? _memberDisplayName(String userId) {
    if (userId.trim().isEmpty) return null;
    for (final member in _approvers) {
      if (member.userId == userId) return member.name ?? member.userId;
    }
    return userId;
  }

  Widget _buildApproverSelectField({
    required String label,
    required TextEditingController controller,
    required List<TenantMember> members,
    Widget? labelTrailing,
  }) {
    return AppSelectField<AppSelectItem>(
      label: label,
      labelTrailing: labelTrailing,
      value: controller.text.isEmpty ? null : controller.text,
      hint: 'Chọn $label',
      bottomSheetTitle: 'Chọn $label',
      searchHint: 'Tìm user',
      items: [
        for (final member in members)
          AppSelectItem(
            id: member.userId,
            title: member.name ?? member.userId,
            subtitle: [
              tenantRoleLabel(member.role),
              if ((member.phone ?? '').isNotEmpty) member.phone!,
              if ((member.email ?? '').isNotEmpty) member.email!,
            ].join(' · '),
          ),
      ],
      onChanged: (value) => setState(() => controller.text = value ?? ''),
    );
  }

  void _addLine() => setState(() => _lines.add(_IssueLineDraft()));

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      if (_lines.isEmpty) _lines.add(_IssueLineDraft());
    });
  }

  Future<void> _pickDate() async {
    final current = DateFormat('dd/MM/yyyy').parse(_issueDate.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() => _issueDate.text = DateFormat('dd/MM/yyyy').format(picked));
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }

  String _toIsoDate(String ddmmyyyy) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(ddmmyyyy).toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  bool _validateGeneralStep({bool showError = true}) {
    final selectedWarehouseId = _selectedWarehouseId;
    if (selectedWarehouseId == null) {
      if (showError) SimpleSnackbarService.showError('Vui lòng chọn kho');
      return false;
    }

    if (_issueDate.text.trim().isEmpty ||
        DateTime.tryParse(_toIsoDate(_issueDate.text.trim())) == null) {
      if (showError) {
        SimpleSnackbarService.showError('Vui lòng chọn ngày phiếu hợp lệ');
      }
      return false;
    }

    if (_issueType == 'sale' && _customerId == null) {
      if (showError) {
        SimpleSnackbarService.showError(
          'Phiếu xuất bán bắt buộc phải chọn khách hàng',
        );
      }
      return false;
    }
    if (_deliveryContactId == null || _deliveryContactId!.trim().isEmpty) {
      if (showError) {
        SimpleSnackbarService.showError('Vui lòng chọn người giao hàng');
      }
      return false;
    }
    if (_warehouseKeeperController.text.trim().isEmpty) {
      if (showError) {
        SimpleSnackbarService.showError('Vui lòng chọn thủ kho');
      }
      return false;
    }
    if (_chiefAccountantController.text.trim().isEmpty) {
      if (showError) {
        SimpleSnackbarService.showError('Vui lòng chọn kế toán trưởng');
      }
      return false;
    }

    return true;
  }

  bool _validateLinesStep({bool showError = true}) {
    if (_lines.isEmpty) {
      if (showError) {
        SimpleSnackbarService.showError('Vui lòng thêm ít nhất 1 Hàng hóa');
      }
      return false;
    }

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final displayIndex = i + 1;
      if (line.productId.trim().isEmpty) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $displayIndex: vui lòng chọn sản phẩm',
          );
        }
        return false;
      }
      if (line.unitName.trim().isEmpty) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $displayIndex: vui lòng nhập đơn vị',
          );
        }
        return false;
      }
      final requested = double.tryParse(line.requestedQty.trim());
      if (requested == null || requested <= 0) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $displayIndex: SL dự kiến phải lớn hơn 0',
          );
        }
        return false;
      }
      final actual = double.tryParse(line.actualQty.trim());
      if (actual == null || actual <= 0) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $displayIndex: SL thực xuất phải lớn hơn 0',
          );
        }
        return false;
      }
      final unitPrice = line.unitPrice.trim();
      if (unitPrice.isNotEmpty && double.tryParse(unitPrice) == null) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $displayIndex: đơn giá phải là số hợp lệ',
          );
        }
        return false;
      }
      final available = _productStock[line.productId] ?? double.infinity;
      if (requested > available) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $displayIndex: SL dự kiến vượt tồn kho hiện có (${_formatNum(available)})',
          );
        }
        return false;
      }
      if (actual > available) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $displayIndex: SL thực xuất vượt tồn kho hiện có (${_formatNum(available)})',
          );
        }
        return false;
      }
    }

    return true;
  }

  bool _validate({bool showError = true}) {
    if (!_validateGeneralStep(showError: showError)) return false;
    if (!_validateLinesStep(showError: showError)) return false;
    return true;
  }

  void _goNext() {
    if (_currentStep == 0) {
      if (!_validateGeneralStep()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_validateLinesStep()) return;
      setState(() => _currentStep = 2);
    }
  }

  void _goBack() {
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
  }

  Future<void> _save() async {
    if (!_validate()) return;

    // Lấy thông tin người giao hàng đã chọn
    final selectedContact = _deliveryContacts
        .cast<PartnerSelectDialogItem?>()
        .firstWhere((c) => c?.id == _deliveryContactId, orElse: () => null);
    final deliveredByName = selectedContact?.title ?? '';

    final body = <String, dynamic>{
      'warehouseId': _selectedWarehouseId,
      'issueType': _issueType,
      'issueDate': _toIsoDate(_issueDate.text),
      if (_customerId != null && _customerId!.trim().isNotEmpty)
        'customerId': _customerId!.trim(),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      'deliveredBy': {
        'contactId': _deliveryContactId ?? '',
        'kind': 'external',
        'fullName': deliveredByName,
      },
      'workflowAssignedApproverIds': _buildWorkflowAssignedApproverIds(),
      'lines': _lines.map((line) => line.toJson()).toList(),
    };

    setState(() => _saving = true);
    try {
      final repo = context.read<StockIssueRepository>();
      final saved = _isEdit
          ? await repo.update(widget.issueId!, body)
          : await repo.create(body);
      await _uploadPdf(saved);
      if (!mounted) return;
      SimpleSnackbarService.showSuccess(
        _isEdit ? 'Đã cập nhật phiếu xuất' : 'Đã tạo phiếu xuất',
      );
      context.pop(true);
    } catch (e) {
      if (mounted) SimpleSnackbarService.showError(_friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadPdf(StockIssueDocumentData saved) async {
    final fileRepository = context.read<FileRepository>();
    try {
      final code = saved.code.isNotEmpty
          ? saved.code
          : '${saved.id}-${DateTime.now().millisecondsSinceEpoch}';
      final data = _buildPdfData(saved, code);
      final bytes = await StockDocPdfService.buildPdf(data);
      final file = await StockDocPdfService.writeToTempFile(
        fileName: 'phieu-xuat-$code.pdf',
        bytes: bytes,
      );
      final uploaded = await fileRepository.upload(file, kind: 'stock_issue');
      if (mounted && uploaded.url.isNotEmpty) {
        SimpleSnackbarService.showSuccess('Đã lưu PDF lên hệ thống');
      }
    } catch (e) {
      if (mounted) {
        SimpleSnackbarService.showError(
          'Đã lưu phiếu nhưng chưa tải PDF lên hệ thống: ${_friendly(e)}',
        );
      }
    }
  }

  StockDocPdfData _buildPdfData(StockIssueDocumentData saved, String code) {
    final warehouse = _selectedWarehouse;
    final date =
        DateTime.tryParse(_toIsoDate(_issueDate.text)) ?? DateTime.now();
    final lines = <List<String>>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final product = _productById(line.productId);
      final requested = double.tryParse(line.requestedQty.trim()) ?? 0;
      final actual = double.tryParse(line.actualQty.trim()) ?? 0;
      final price = double.tryParse(line.unitPrice.trim()) ?? 0;
      lines.add([
        '${i + 1}',
        product?.name ?? (line.productId.isEmpty ? '—' : line.productId),
        product?.sku ?? '—',
        line.unitName,
        _formatNum(requested),
        _formatNum(actual),
        _formatNum(price),
        _formatNum(actual * price),
      ]);
    }
    return StockDocPdfData(
      title: 'PHIẾU XUẤT KHO',
      tenantName: _tenantName,
      address: warehouse?.address ?? '',
      code: code,
      date: date,
      receiverLabel: 'Họ và tên người nhận hàng',
      receiver: _customerDisplayName(),
      reasonLabel: 'Lý do xuất',
      reason: issueTypeLabel(_issueType),
      locationLabel: 'Xuất tại kho (ngăn lô)',
      location: warehouse == null
          ? '…………………'
          : '${warehouse.code} · ${warehouse.name}  địa điểm: ${warehouse.address}',
      requestedLabel: 'Yêu cầu',
      actualLabel: 'Thực xuất',
      lines: lines,
      total: _totalAmount,
      totalInWords: _vietnameseWords(_totalAmount),
      signatureRoles: const [
        'Người lập phiếu',
        'Người giao hàng',
        'Thủ kho',
        'Kế toán trưởng',
      ],
      note: _note.text.trim(),
    );
  }

  Warehouse? get _selectedWarehouse {
    for (final w in _warehouses) {
      if (w.id == _selectedWarehouseId) return w;
    }
    return null;
  }

  Product? _productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  String get _tenantName {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      for (final t in auth.tenants) {
        if (t.id == auth.selectedTenantId) return t.name;
      }
    }
    return '';
  }

  String _customerDisplayName() {
    if (_customerId == null || _customerId!.trim().isEmpty) return '—';
    for (final c in _customers) {
      if (c.id == _customerId) return c.title;
    }
    return _customerId!;
  }

  String _deliveryContactDisplayName() {
    if (_deliveryContactId == null || _deliveryContactId!.trim().isEmpty) {
      return '';
    }
    for (final contact in _deliveryContacts) {
      if (contact.id == _deliveryContactId) return contact.title;
    }
    return '';
  }

  String? get _currentUserName {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      final name = auth.user.name;
      if (name.isNotEmpty) return name;
    }
    return _tenantName;
  }

  String? get _currentUserId {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated && auth.user.id.isNotEmpty) {
      return auth.user.id;
    }
    return null;
  }

  Future<void> _showCreateCustomerSheet() async {
    final created = await AppBottomSheetService.show<CustomerOption>(
      context: context,
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      actions: const [],
      content: PartnerCreateSheet(
        title: 'Tạo khách hàng',
        codeLabel: 'Mã khách hàng',
        nameLabel: 'Tên khách hàng',
        extraFields: const [
          PartnerCreateField(
            label: 'Số điện thoại',
            hintText: 'Nhập số điện thoại',
            keyboardType: TextInputType.phone,
            fieldKey: 'phone',
          ),
          PartnerCreateField(
            label: 'Email',
            hintText: 'Nhập email',
            keyboardType: TextInputType.emailAddress,
            fieldKey: 'email',
          ),
        ],
        onCreated: (values) => CustomerApiService().create(
          code: values['code'] ?? '',
          name: values['name'] ?? '',
          phone: values['phone'],
          email: values['email'],
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _customers = [
        ..._customers,
        PartnerSelectDialogItem(
          id: created.id,
          title: created.name,
          subtitle: [
            if (created.code != null && created.code!.isNotEmpty) created.code,
            if (created.phone != null && created.phone!.isNotEmpty)
              created.phone,
          ].join(' · '),
        ),
      ];
      _customerId = created.id;
    });
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _vietnameseWords(num value) {
    final intValue = value.round();
    if (intValue == 0) return 'không đồng';
    final negative = intValue < 0;
    var n = intValue.abs();
    const digits = [
      '',
      'một',
      'hai',
      'ba',
      'bốn',
      'năm',
      'sáu',
      'bảy',
      'tám',
      'chín',
    ];
    const units = ['', 'nghìn', 'triệu', 'tỷ', 'nghìn tỷ', 'triệu tỷ'];
    final groups = <int>[];
    while (n > 0) {
      groups.add(n % 1000);
      n ~/= 1000;
    }
    final parts = <String>[];
    for (var i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      if (g == 0) continue;
      final hasHigherValue = groups.skip(i + 1).any((x) => x > 0);
      if (g < 100 && hasHigherValue) parts.add('không trăm');
      final h = g ~/ 100;
      final t = (g % 100) ~/ 10;
      final o = g % 10;
      if (h > 0) parts.add('${digits[h]} trăm');
      if (t == 1) {
        parts.add('mười');
        if (o == 5) {
          parts.add('lăm');
        } else if (o > 0) {
          parts.add(digits[o]);
        }
      } else if (t > 1) {
        parts.add('${digits[t]} mươi');
        if (o == 1) {
          parts.add('mốt');
        } else if (o == 5) {
          parts.add('lăm');
        } else if (o > 0) {
          parts.add(digits[o]);
        }
      } else if (o > 0) {
        if (h > 0 || hasHigherValue) parts.add('linh');
        parts.add(o == 5 ? 'năm' : digits[o]);
      }
      if (i > 0) parts.add(units[i]);
    }
    var text = parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (negative) text = 'âm $text';
    return '$text đồng';
  }

  double get _totalAmount {
    var total = 0.0;
    for (final line in _lines) {
      final qty = double.tryParse(line.actualQty.trim()) ?? 0;
      final price = double.tryParse(line.unitPrice.trim()) ?? 0;
      total += qty * price;
    }
    return total;
  }

  Widget _buildSectionTitle(
    String title, {
    String? subtitle,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: ColorSkin.subtitle)),
        ],
      ],
    );
  }

  Widget _buildGeneralInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Thông tin chung',
          subtitle: 'Chọn kho, khách hàng và ngày phiếu',
        ),
        const SizedBox(height: 12),
        AppSelectField<AppSelectItem>(
          label: 'Kho *',
          value: _selectedWarehouseId,
          hint: 'Chọn kho',
          bottomSheetTitle: 'Chọn kho',
          searchHint: 'Tìm kho',
          items: [
            for (final w in _warehouses)
              AppSelectItem(
                id: w.id,
                title: '${w.code} · ${w.name}',
                subtitle: w.address,
              ),
          ],
          onChanged: (value) => setState(() => _selectedWarehouseId = value),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Loại phiếu',
          initialValue: 'Xuất hàng',
          readOnly: true,
          enabled: false,
        ),
        const SizedBox(height: 12),
        AppDateField(
          label: 'Ngày xuất phiếu *',
          controller: _issueDate,
          onTap: _pickDate,
        ),
        const SizedBox(height: 12),
        AppSelectField<PartnerSelectDialogItem>(
          label: 'Khách hàng',
          labelTrailing: AppFieldLabelAction(
            tooltip: 'Tạo khách hàng',
            onPressed: _showCreateCustomerSheet,
          ),
          value: _customerId,
          hint: 'Chọn khách hàng',
          bottomSheetTitle: 'Chọn khách hàng',
          searchHint: 'Tìm khách hàng',
          items: _customers,
          onChanged: (value) async {
            if (value == null) return;
            setState(() {
              _customerId = value;
            });
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Ghi chú phiếu',
          controller: _note,
          hintText: 'Nhập ghi chú',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Người lập phiếu',
          initialValue: _currentUserName,
          readOnly: true,
          enabled: false,
        ),
        const SizedBox(height: 12),
        AppSelectField<PartnerSelectDialogItem>(
          label: 'Người giao hàng',
          labelTrailing: AppFieldLabelAction(
            tooltip: 'Thêm người giao hàng',
            onPressed: _showContactCreateSheet,
          ),
          value: _deliveryContactId,
          hint: _deliveryContacts.isEmpty
              ? 'Chưa có người giao hàng'
              : 'Chọn người giao hàng',
          bottomSheetTitle: 'Người giao hàng',
          searchHint: 'Tìm theo tên, SĐT, công ty',
          items: _deliveryContacts,
          actionLabel: 'Thêm người giao hàng',
          onAction: _showContactCreateSheet,
          onBeforeOpen: _refreshDeliveryContacts,
          onChanged: (value) {
            setState(() => _deliveryContactId = value);
          },
        ),
        const SizedBox(height: 12),
        _buildSectionTitle(
          'Người duyệt nội bộ',
          subtitle: 'Chọn thủ kho và kế toán trưởng',
        ),
        const SizedBox(height: 12),
        if (_approvers.isEmpty)
          const Text('Chưa tải được danh sách người duyệt phù hợp'),
        if (_approvers.isNotEmpty) ...[
          _buildApproverSelectField(
            label: 'Thủ kho',
            controller: _warehouseKeeperController,
            members: _membersForRole('warehouse_keeper'),
          ),
          const SizedBox(height: 12),
          _buildApproverSelectField(
            label: 'Kế toán trưởng',
            controller: _chiefAccountantController,
            members: _membersForRole('accountant'),
          ),
          const SizedBox(height: 16),
          _buildWorkflowApprovalButtons(),
        ],
      ],
    );
  }

  Widget _buildLines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Hàng hóa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            if (_products.isNotEmpty)
              GestureDetector(
                onTap: _addLine,
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 20, color: ColorSkin.primary),
                    SizedBox(width: 4),
                    Text(
                      'Thêm sản phẩm',
                      style: TextStyle(
                        color: ColorSkin.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_products.isEmpty)
          _buildEmptyProductsState()
        else
          for (var i = 0; i < _lines.length; i++) ...[
            _IssueLineItem(
              index: i,
              draft: _lines[i],
              products: _products,
              productStock: _productStock,
              onChanged: () => setState(() {}),
              onRemove: _lines.length > 1 ? () => _removeLine(i) : null,
              formatNum: _formatNum,
            ),
            if (i != _lines.length - 1) const Divider(height: 32),
          ],
      ],
    );
  }

  Widget _buildEmptyProductsState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Icon(
          Icons.inventory_2_outlined,
          size: 48,
          color: ColorSkin.subtitle,
        ),
        const SizedBox(height: 8),
        const Text(
          'Chưa có sản phẩm nào',
          style: TextStyle(fontWeight: FontWeight.w700, color: ColorSkin.title),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bạn cần tạo sản phẩm trước khi thêm Hàng hóa',
          style: TextStyle(color: ColorSkin.subtitle, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Thêm sản phẩm',
          onPressed: _navigateToCreateProduct,
          variant: AppButtonVariant.primary,
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  Future<void> _navigateToCreateProduct() async {
    final created = await context.push<bool>(AppRoutes.productsNew.path);
    if (created == true && mounted) {
      await _reloadProducts();
    }
  }

  Future<void> _reloadProducts() async {
    try {
      final productRepo = context.read<ProductRepository>();
      final products = await productRepo.list();
      if (!mounted) return;
      setState(() => _products = products);
      await _loadProductStock();
      SimpleSnackbarService.showSuccess('Đã tải lại danh sách sản phẩm');
    } catch (e) {
      if (mounted) SimpleSnackbarService.showError(_friendly(e));
    }
  }

  static const double _docPreviewWidth = 568;

  Widget _buildReview() {
    final date =
        DateTime.tryParse(_toIsoDate(_issueDate.text)) ?? DateTime.now();
    final warehouse = _selectedWarehouse;
    final code = _existing?.code ?? '';
    final location = warehouse == null
        ? '………………………………'
        : '${warehouse.code} · ${warehouse.name}';
    final address = warehouse?.address?.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final containerWidth = viewportWidth < _docPreviewWidth
            ? _docPreviewWidth
            : viewportWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: containerWidth,
            child: Center(
              child: SizedBox(
                width: _docPreviewWidth,
                child: _buildReviewDocument(
                  date: date,
                  code: code,
                  location: location,
                  address: address,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewDocument({
    required DateTime date,
    required String code,
    required String location,
    String? address,
  }) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 10.5, height: 1.25, color: Colors.black),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đơn vị: ${_tenantName.isEmpty ? '…………………' : _tenantName}',
                    ),
                    Text(
                      'Địa chỉ: ${address == null || address.isEmpty ? '…………………' : address}',
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Text(
                      'Mẫu số 01 – VT',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '(Ban hành theo Thông tư số 200/2014/TT-BTC\nngày 22/12/2014 của Bộ Tài chính)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    const Text(
                      'PHIẾU XUẤT KHO',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Ngày ${date.day} tháng ${date.month} năm ${date.year}',
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quyển số: 001'),
                    Text('Số: ${code.isEmpty ? '…………' : code}'),
                    const Text('NỢ TK: ……………'),
                    const Text('CÓ TK: ……………'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('- Họ và tên người nhận hàng: ${_customerDisplayName()}'),
          Text('- Lý do xuất: ${issueTypeLabel(_issueType)}'),
          Text(
            '- Xuất tại kho (ngăn lô): $location, địa điểm: ${address == null || address.isEmpty ? '…………………' : address}',
          ),
          const SizedBox(height: 10),
          _buildDocTable(),
          const SizedBox(height: 10),
          Text(
            '- Tổng số tiền: ${_formatNum(_totalAmount)} (Viết bằng chữ: ${_vietnameseWords(_totalAmount)})',
          ),
          const Text('- Số chứng từ gốc kèm theo: …………………………………………'),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ngày ${date.day} tháng ${date.month} năm ${date.year}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          _buildSignatureRow(
            const [
              'Người lập phiếu',
              'Người giao hàng',
              'Thủ kho',
              'Kế toán trưởng',
            ],
            signatureNames: {
              'Người lập phiếu': _currentUserName ?? '',
              'Người giao hàng': _deliveryContactDisplayName(),
              'Thủ kho':
                  _memberDisplayName(_warehouseKeeperController.text) ?? '',
              'Kế toán trưởng':
                  _memberDisplayName(_chiefAccountantController.text) ?? '',
            },
          ),
        ],
      ),
    );
  }

  Widget _docHeaderText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700),
    );
  }

  Widget _cellText(String text, {TextAlign align = TextAlign.center}) {
    return Text(text, textAlign: align, style: const TextStyle(fontSize: 8));
  }

  Widget _docRow(List<(int, Widget)> cells) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: cells[i].$1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                decoration: BoxDecoration(
                  border: Border(
                    left: i == 0
                        ? const BorderSide(color: Colors.black45)
                        : BorderSide.none,
                    right: const BorderSide(color: Colors.black45),
                    bottom: const BorderSide(color: Colors.black45),
                  ),
                ),
                child: Center(child: cells[i].$2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocTable() {
    final rows = <Widget>[
      _docRow([
        (32, _docHeaderText('STT')),
        (
          168,
          _docHeaderText(
            'Tên, nhãn hiệu, quy cách, phẩm chất vật tư, dụng cụ, sản phẩm, hàng hóa',
          ),
        ),
        (60, _docHeaderText('Mã số')),
        (52, _docHeaderText('Đơn vị tính')),
        (56, _docHeaderText('Số lượng\nYêu cầu')),
        (56, _docHeaderText('Số lượng\nThực xuất')),
        (64, _docHeaderText('Đơn giá')),
        (80, _docHeaderText('Thành tiền')),
      ]),
      _docRow([
        (32, _cellText('A')),
        (168, _cellText('B')),
        (60, _cellText('C')),
        (52, _cellText('D')),
        (56, _cellText('1')),
        (56, _cellText('2')),
        (64, _cellText('3')),
        (80, _cellText('4')),
      ]),
    ];

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final product = _productById(line.productId);
      final requested = double.tryParse(line.requestedQty.trim()) ?? 0;
      final actual = double.tryParse(line.actualQty.trim()) ?? 0;
      final price = double.tryParse(line.unitPrice.trim()) ?? 0;
      rows.add(
        _docRow([
          (32, _cellText('${i + 1}')),
          (
            168,
            _cellText(
              product?.name ?? (line.productId.isEmpty ? '—' : line.productId),
              align: TextAlign.left,
            ),
          ),
          (60, _cellText(product?.sku ?? '—')),
          (52, _cellText(line.unitName)),
          (56, _cellText(_formatNum(requested))),
          (56, _cellText(_formatNum(actual))),
          (64, _cellText(_formatNum(price))),
          (80, _cellText(_formatNum(actual * price))),
        ]),
      );
    }

    return SizedBox(
      width: _docPreviewWidth,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.black45)),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }

  Widget _buildSignatureRow(
    List<String> roles, {
    Map<String, String>? signatureNames,
  }) {
    final workflow = _workflow;
    if (workflow != null && workflow.steps.isNotEmpty) {
      return WorkflowSignatureRow(
        roles: roles,
        signatureNames: signatureNames,
        steps: workflow.steps,
        assignedApproverIds: _buildWorkflowAssignedApproverIds(),
        documentStatus: workflow.status,
        currentUserId: _currentUserId,
        currentUserRole: currentTenantRoleFromAuthState(
          context.read<AuthBloc>().state,
        ),
        actionSubmitting: _workflowActionSubmitting,
        onActionTap: _openWorkflowApproval,
        fitOnOneLine: _fitOnOneLine,
        stepAvailableActions: _buildStepAvailableActionsMap(
          workflow.steps,
          _availableActions,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in roles)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fitOnOneLine(
                  Text(
                    role,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 14,
                  child: _fitOnOneLine(
                    Text(
                      signatureNames?[role]?.trim().isNotEmpty == true
                          ? signatureNames![role]!
                          : '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _fitOnOneLine(
                  const Text(
                    '(Ký, họ tên)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _fitOnOneLine(Widget child) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  List<Widget> _buildStepContent() {
    return switch (_currentStep) {
      1 => [_buildLines()],
      2 => [
        _buildSectionTitle('Xác nhận', subtitle: 'Kiểm tra lại trước khi lưu'),
        const SizedBox(height: 12),
        _buildReview(),
      ],
      _ => [_buildGeneralInfo()],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: Text(_isEdit ? 'Sửa lệnh xuất hàng' : 'Tạo lệnh xuất hàng'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: ColorSkin.border1.withValues(alpha: 0.5)),
            ),
          ),
          child: _currentStep < 2
              ? Row(
                  children: [
                    if (_currentStep > 0) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Quay lại',
                          onPressed: _saving ? null : _goBack,
                          variant: AppButtonVariant.outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: _currentStep == 0 ? 1 : 2,
                      child: AppButton(
                        label: 'Tiếp tục',
                        onPressed: _saving ? null : _goNext,
                        variant: AppButtonVariant.primary,
                        expand: true,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Quay lại',
                        onPressed: _saving ? null : _goBack,
                        variant: AppButtonVariant.outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: _saving ? 'Đang lưu...' : 'Lưu phiếu xuất',
                        onPressed: _saving ? null : _save,
                        variant: AppButtonVariant.primary,
                        isLoading: _saving,
                        expand: true,
                      ),
                    ),
                  ],
                ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: AppFormStepper(
                    steps: const ['Thông tin chung', 'Hàng hóa', 'Xác nhận'],
                    currentIndex: _currentStep,
                  ),
                ),
                Container(
                  height: 1,
                  color: ColorSkin.border1.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          _currentStep == 1 && _products.isNotEmpty ? 150 : 16,
                        ),
                        children: _buildStepContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _IssueLineDraft {
  _IssueLineDraft({
    this.productId = '',
    this.unitName = '',
    this.requestedQty = '',
    this.actualQty = '',
    this.unitPrice = '',
  });

  String productId;
  String unitName;
  String requestedQty;
  String actualQty;
  String unitPrice;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'unitName': unitName,
      'requestedQty': double.tryParse(requestedQty.trim()) ?? 0,
      'actualQty': double.tryParse(actualQty.trim()) ?? 0,
      if (unitPrice.trim().isNotEmpty)
        'unitPrice': double.tryParse(unitPrice.trim()) ?? 0,
    };
  }
}

class _IssueLineItem extends StatelessWidget {
  const _IssueLineItem({
    required this.index,
    required this.draft,
    required this.products,
    required this.productStock,
    required this.onChanged,
    required this.formatNum,
    this.onRemove,
  });

  final int index;
  final _IssueLineDraft draft;
  final List<Product> products;
  final Map<String, double> productStock;
  final VoidCallback onChanged;
  final String Function(double value) formatNum;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final available = productStock[draft.productId] ?? 0;
    final requested = double.tryParse(draft.requestedQty.trim()) ?? 0;
    final actual = double.tryParse(draft.actualQty.trim()) ?? 0;
    final overStock =
        draft.productId.isNotEmpty &&
        available > 0 &&
        (requested > available || actual > available);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dòng ${index + 1}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ColorSkin.title,
              ),
            ),
            const Spacer(),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                tooltip: 'Xoá dòng',
                icon: const Icon(Icons.delete_outline, color: ColorSkin.error),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AppSelectField<AppSelectItem>(
          label: 'Sản phẩm *',
          value: draft.productId.isEmpty ? null : draft.productId,
          hint: 'Chọn sản phẩm',
          bottomSheetTitle: 'Chọn sản phẩm',
          searchHint: 'Tìm sản phẩm',
          items: [
            for (final p in products)
              AppSelectItem(
                id: p.id,
                title: '${p.sku} · ${p.name}',
                subtitle: p.barcode,
              ),
          ],
          onChanged: (value) {
            draft.productId = value ?? '';

            // Tự động điền giá gốc khi chọn sản phẩm
            Product? product;
            for (final p in products) {
              if (p.id == value) {
                product = p;
                break;
              }
            }
            if (product != null) {
              draft.unitPrice = product.averageCost > 0
                  ? formatNum(product.averageCost)
                  : '';
            }

            onChanged();
          },
        ),
        const SizedBox(height: 8),
        if (draft.productId.isNotEmpty)
          Text(
            'Tồn kho thực tế: ${formatNum(available)}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: overStock ? ColorSkin.error : ColorSkin.subtitle,
            ),
          ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Đơn vị',
          initialValue: draft.unitName,
          hintText: 'Nhập đơn vị',
          onChanged: (value) => draft.unitName = value,
          required: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppNumberField(
                label: 'SL dự kiến',
                initialValue: draft.requestedQty,
                hintText: '0',
                onChanged: (value) => draft.requestedQty = value,
                required: true,
                nonNegative: true,
                max: draft.productId.isEmpty ? null : available,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppNumberField(
                label: 'SL thực xuất',
                initialValue: draft.actualQty,
                hintText: '0',
                onChanged: (value) => draft.actualQty = value,
                required: true,
                nonNegative: true,
                max: draft.productId.isEmpty ? null : available,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppPriceField(
          label: 'Tiền mặt',
          initialValue: draft.unitPrice,
          hintText: '0',
          onChanged: (value) => draft.unitPrice = value,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
