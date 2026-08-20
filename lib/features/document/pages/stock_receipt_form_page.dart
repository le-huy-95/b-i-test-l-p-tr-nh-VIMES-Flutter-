import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/datasources/api_services/contact_api_service.dart';
import 'package:test_y_app/data/datasources/api_services/supplier_api_service.dart';
import 'package:test_y_app/data/datasources/api_services/tenant_people_api_service.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';
import 'package:test_y_app/features/document/workflow_approval_utils.dart';
import 'package:test_y_app/features/document/widgets/workflow_approval_bottom_sheet.dart';
import 'package:test_y_app/features/document/widgets/workflow_signature_row.dart';
import 'package:test_y_app/features/document/widgets/contact_create_sheet.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';
import 'package:test_y_app/domain/repositories/stock_receipt_repository.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/document/widgets/partner_select_dialog.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_date_field.dart';
import 'package:test_y_app/shared/widgets/app_field_label_action.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:test_y_app/shared/widgets/app_number_field.dart';
import 'package:test_y_app/shared/widgets/app_form_stepper.dart';
import 'package:test_y_app/shared/widgets/app_text_field.dart';
import 'package:test_y_app/shared/widgets/select_field.dart';

class StockReceiptFormPageLauncher extends StatelessWidget {
  const StockReceiptFormPageLauncher({
    super.key,
    required this.repository,
    this.receiptId,
  });

  final StockReceiptRepository repository;
  final String? receiptId;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: repository,
      child: _StockReceiptFormScreen(receiptId: receiptId),
    );
  }
}

class StockReceiptFormPage extends StatelessWidget {
  const StockReceiptFormPage({super.key, this.receiptId});

  final String? receiptId;

  @override
  Widget build(BuildContext context) {
    return _StockReceiptFormScreen(receiptId: receiptId);
  }
}

class _StockReceiptFormScreen extends StatefulWidget {
  const _StockReceiptFormScreen({this.receiptId});

  final String? receiptId;

  @override
  State<_StockReceiptFormScreen> createState() =>
      _StockReceiptFormScreenState();
}

class _StockReceiptFormScreenState extends State<_StockReceiptFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _receiptDate = TextEditingController();
  final _note = TextEditingController();
  final _deliveryApproverController = TextEditingController();
  final _warehouseKeeperController = TextEditingController();
  final _chiefAccountantController = TextEditingController();

  String? _selectedWarehouseId;
  String? _supplierId;
  String? _supplierName;
  String _receiptType = 'purchase';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _seeded = false;
  int _currentStep = 0;

  // Delivery contact state
  String? _deliveryContactId;
  List<PartnerSelectDialogItem> _deliveryContacts = const [];
  final _contactApi = ContactApiService();

  List<Warehouse> _warehouses = const [];
  List<Product> _products = const [];
  List<PartnerSelectDialogItem> _suppliers = const [];
  List<TenantMember> _approvers = const [];
  final List<_ReceiptLineDraft> _lines = [_ReceiptLineDraft()];
  StockReceiptDocumentData? _existing;
  StockDocument? _workflow;
  bool _workflowActionSubmitting = false;
  final Map<String, double> _productStock = {};

  bool get _isEdit => widget.receiptId != null;

  @override
  void initState() {
    super.initState();
    _receiptDate.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _receiptDate.dispose();
    _note.dispose();
    _deliveryApproverController.dispose();
    _warehouseKeeperController.dispose();
    _chiefAccountantController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final warehouseRepo = context.read<WarehouseRepository>();
      final productRepo = context.read<ProductRepository>();
      final receiptRepo = context.read<StockReceiptRepository>();
      final peopleRepo = TenantPeopleApiService();
      final results = await Future.wait([
        warehouseRepo.list(),
        productRepo.list(),
        mapSuppliersToPartnerItems(),
        peopleRepo.fetchMembers(limit: 200),
        if (widget.receiptId != null) receiptRepo.getById(widget.receiptId!),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0] as List<Warehouse>;
        _products = results[1] as List<Product>;
        _suppliers = results[2] as List<PartnerSelectDialogItem>;
        final memberPage = results[3] as TenantMemberPageResult;
        _approvers = memberPage.items.where((m) => m.isActive).toList();
        if (widget.receiptId != null) {
          _existing = results[4] as StockReceiptDocumentData;
        }
        if (_suppliers.isNotEmpty) {
          _supplierId ??= _suppliers.first.id;
          _supplierName ??= _suppliers.first.title;
        }
        if (_warehouses.isNotEmpty) {
          _selectedWarehouseId ??= _warehouses.first.id;
        }
        if (_existing != null && !_seeded) {
          _seedFromExisting(_existing!);
        }
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
    final receiptId = widget.receiptId;
    if (receiptId == null) return;
    try {
      final workflow = await context.read<StockDocumentRepository>().getDetail(
        'stock_receipt',
        receiptId,
      );
      if (!mounted) return;
      setState(() {
        _workflow = workflow;
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
  }) async {
    final receiptId = widget.receiptId;
    if (receiptId == null) return;
    setState(() => _workflowActionSubmitting = true);
    try {
      await context
          .read<StockDocumentRepository>()
          .action('stock_receipt', receiptId, {
            'action': action,
            'stepId': step.id,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          });
      if (!mounted) return;
      SimpleSnackbarService.showSuccess(
        action == 'approve' ? 'Đã phê duyệt phiếu' : 'Đã từ chối phê duyệt',
      );
      await _load();
    } catch (e) {
      if (mounted) SimpleSnackbarService.showError(_friendly(e));
    } finally {
      if (mounted) setState(() => _workflowActionSubmitting = false);
    }
  }

  Future<void> _openWorkflowApproval(WorkflowStep step, String action) async {
    await WorkflowApprovalBottomSheet.show(
      context,
      stepName: step.stepName,
      stepId: step.id,
      actions: const ['approve'],
      onSubmit: (action, note, proxySignerId, authorizationIds) =>
          _submitWorkflowAction(step: step, action: action, note: note),
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
              : () => _openWorkflowApproval(step, 'approve'),
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
      // Tồn kho không bắt buộc để tiếp tục form
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

  void _seedFromExisting(StockReceiptDocumentData existing) {
    _selectedWarehouseId = existing.warehouseId;
    _supplierId = existing.supplierId;
    _supplierName = _supplierNameById(existing.supplierId);
    _receiptType = existing.receiptType;
    _receiptDate.text = DateFormat('dd/MM/yyyy').format(existing.receiptDate);
    _note.text = existing.note ?? '';
    _deliveryContactId = existing.deliveredByContactId;
    _lines
      ..clear()
      ..addAll(
        existing.lines.isEmpty
            ? [_ReceiptLineDraft()]
            : existing.lines.map(
                (line) => _ReceiptLineDraft(
                  productId: line.productId,
                  unitName: line.unitName,
                  expectedQty: line.expectedQty.toString(),
                  actualQty: line.actualQty.toString(),
                  unitPrice: line.unitPrice.toString(),
                  batchNo: line.batchNo ?? '',
                  expiryDate: line.expiryDate == null
                      ? ''
                      : DateFormat('dd/MM/yyyy').format(line.expiryDate!),
                  manufactureDate: line.manufactureDate == null
                      ? ''
                      : DateFormat('dd/MM/yyyy').format(line.manufactureDate!),
                ),
              ),
      );
    if (_lines.isEmpty) _lines.add(_ReceiptLineDraft());
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
    return [
      delivery.isNotEmpty ? delivery : warehouse,
      warehouse,
      accountant,
    ];
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

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  String? _supplierNameById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final s in _suppliers) {
      if (s.id == id) return s.title;
    }
    return id;
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  double? _parseOptional(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _toIsoDate(String ddmmyyyy) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(ddmmyyyy).toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  Future<void> _pickDate() async {
    final current = DateFormat('dd/MM/yyyy').parse(_receiptDate.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() => _receiptDate.text = DateFormat('dd/MM/yyyy').format(picked));
  }

  void _addLine() => setState(() => _lines.add(_ReceiptLineDraft()));

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() => _lines.removeAt(index));
  }

  Future<void> _showCreateSupplierSheet() async {
    final created = await AppBottomSheetService.show<SupplierOption>(
      context: context,
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      actions: const [],
      content: PartnerCreateSheet(
        title: 'Tạo nhà cung cấp',
        codeLabel: 'Mã nhà cung cấp',
        nameLabel: 'Tên nhà cung cấp',
        extraFields: const [
          PartnerCreateField(
            label: 'Mã số thuế',
            hintText: 'Nhập mã số thuế',
            fieldKey: 'taxCode',
          ),
          PartnerCreateField(
            label: 'Người liên hệ',
            hintText: 'Nhập người liên hệ / số điện thoại',
            keyboardType: TextInputType.phone,
            fieldKey: 'contact',
          ),
        ],
        onCreated: (values) => SupplierApiService().create(
          code: values['code'] ?? '',
          name: values['name'] ?? '',
          taxCode: values['taxCode'],
          contact: values['contact'],
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _suppliers = [
        ..._suppliers,
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
      _supplierId = created.id;
      _supplierName = created.name;
    });
  }

  bool _validateGeneralStep({bool showError = true}) {
    if (_selectedWarehouseId == null) {
      if (showError) SimpleSnackbarService.showError('Vui lòng chọn kho');
      return false;
    }
    if (_receiptDate.text.trim().isEmpty) {
      if (showError) {
        SimpleSnackbarService.showError('Vui lòng chọn ngày phiếu');
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
      final index = i + 1;
      if (line.productId.trim().isEmpty) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $index: vui lòng chọn sản phẩm',
          );
        }
        return false;
      }
      if (line.unitName.trim().isEmpty) {
        if (showError) {
          SimpleSnackbarService.showError('Dòng $index: vui lòng nhập đơn vị');
        }
        return false;
      }
      final expected = _parseOptional(line.expectedQty);
      if (expected == null || expected < 0) {
        if (showError) {
          SimpleSnackbarService.showError('Dòng $index: SL dự kiến phải ≥ 0');
        }
        return false;
      }
      final actual = _parseOptional(line.actualQty);
      if (actual == null || actual <= 0) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $index: SL thực nhập phải lớn hơn 0',
          );
        }
        return false;
      }
      final available = _productStock[line.productId] ?? double.infinity;
      if (expected > available) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $index: SL dự kiến vượt tồn kho hiện có (${_formatNum(available)})',
          );
        }
        return false;
      }
      if (actual > available) {
        if (showError) {
          SimpleSnackbarService.showError(
            'Dòng $index: SL thực nhập vượt tồn kho hiện có (${_formatNum(available)})',
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
      'receiptType': _receiptType,
      'receiptDate': _toIsoDate(_receiptDate.text),
      if (_supplierId != null && _supplierId!.trim().isNotEmpty)
        'supplierId': _supplierId!.trim(),
      'deliveredBy': {
        'contactId': _deliveryContactId ?? '',
        'kind': 'external',
        'fullName': deliveredByName,
      },
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      'workflowAssignedApproverIds': _buildWorkflowAssignedApproverIds(),
      'lines': _lines.map((l) => l.toJson(_toIsoDate)).toList(),
    };

    setState(() => _saving = true);
    try {
      final repo = context.read<StockReceiptRepository>();
      if (_isEdit) {
        await repo.update(widget.receiptId!, body);
      } else {
        await repo.create(body);
      }
      if (!mounted) return;
      SimpleSnackbarService.showSuccess(
        _isEdit ? 'Đã cập nhật phiếu nhập' : 'Đã tạo phiếu nhập',
      );
      Navigator.of(context).pop(true);
      return;
    } catch (e) {
      if (mounted) SimpleSnackbarService.showError(_friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  String _supplierDisplayName() {
    if (_supplierName != null && _supplierName!.trim().isNotEmpty) {
      return _supplierName!;
    }
    if (_supplierId == null || _supplierId!.trim().isEmpty) return '—';
    return _supplierNameById(_supplierId) ?? _supplierId!;
  }

  double get _totalAmount {
    return _lines.fold<double>(0, (sum, line) {
      final actual = _parseOptional(line.actualQty) ?? 0;
      final unitPrice = _parseOptional(line.unitPrice) ?? 0;
      return sum + actual * unitPrice;
    });
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
          subtitle: 'Chọn kho, nhà cung cấp và ngày phiếu',
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
        AppSelectField<PartnerSelectDialogItem>(
          label: 'Nhà cung cấp',
          labelTrailing: AppFieldLabelAction(
            tooltip: 'Tạo nhà cung cấp',
            onPressed: _showCreateSupplierSheet,
          ),
          value: _supplierId,
          hint: _suppliers.isEmpty
              ? 'Chưa có nhà cung cấp'
              : 'Chọn nhà cung cấp',
          bottomSheetTitle: 'Chọn nhà cung cấp',
          searchHint: 'Tìm nhà cung cấp',
          items: _suppliers,
          actionLabel: 'Tạo nhà cung cấp',
          onAction: _showCreateSupplierSheet,
          onChanged: (value) {
            setState(() {
              _supplierId = value;
              _supplierName = _supplierNameById(value);
            });
          },
        ),
        const SizedBox(height: 12),
        AppDateField(
          label: 'Ngày nhập phiếu *',
          controller: _receiptDate,
          onTap: _pickDate,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Ghi chú phiếu',
          controller: _note,
          hintText: 'Nhập ghi chú chung',
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
        const Text(
          'Dòng hàng',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_products.isEmpty)
          _buildEmptyProductsState()
        else
          for (var i = 0; i < _lines.length; i++) ...[
            _ReceiptLineItem(
              index: i,
              draft: _lines[i],
              products: _products,
              productStock: _productStock,
              onChanged: () => setState(() {}),
              onRemove: _lines.length > 1 ? () => _removeLine(i) : null,
              productTitleById: _productTitleById,
              formatNum: _formatNum,
            ),
            if (i != _lines.length - 1) const Divider(height: 32),
          ],
        if (_products.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppButton(
            label: 'Thêm sản phẩm',
            onPressed: _navigateToCreateProduct,
            variant: AppButtonVariant.outlined,
            icon: const Icon(Icons.add, color: ColorSkin.primary),
          ),
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
      SimpleSnackbarService.showSuccess('Đã tải lại danh sách sản phẩm');
    } catch (e) {
      if (mounted) SimpleSnackbarService.showError(_friendly(e));
    }
  }

  String _productTitleById(String id) {
    final p = _productById(id);
    if (p == null) return id;
    return '${p.sku} · ${p.name}';
  }

  static const double _docPreviewWidth = 568;

  Widget _buildReview() {
    final date =
        DateTime.tryParse(_toIsoDate(_receiptDate.text)) ?? DateTime.now();
    final warehouse = _warehouseById(_selectedWarehouseId);
    final code = _existing?.code ?? '';
    final supplier = _supplierDisplayName();
    final location = warehouse == null
        ? '………………………………'
        : '${warehouse.code} · ${warehouse.name}';
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
                  supplier: supplier,
                  location: location,
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
    required String supplier,
    required String location,
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
                    const Text('Bộ phận: …………………'),
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
                      '(Ban hành theo Thông tư số 200/2014/TT-BTC\nNgày 22/12/2014 của Bộ Tài chính)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Spacer(),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    const Text(
                      'PHIẾU NHẬP KHO',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Ngày ${date.day} tháng ${date.month} năm ${date.year}',
                    ),
                    Text('Số: ${code.isEmpty ? '…………………' : code}'),
                  ],
                ),
              ),
              const Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('Nợ: …………………'), Text('Có: …………………')],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('- Theo: $supplier, số ………… ngày …… tháng …… năm ……'),
          Text('- Nhập tại kho: $location, địa điểm: ………………………………'),
          const SizedBox(height: 10),
          _buildDocTable(),
          const SizedBox(height: 10),
          Text(
            '- Tổng số tiền (viết bằng chữ): ${_vietnameseWords(_totalAmount)}',
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
              'Thủ kho',
              'Kế toán trưởng',
            ],
            signatureNames: {
              'Người lập phiếu': _currentUserName ?? '',
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

  Warehouse? _warehouseById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final warehouse in _warehouses) {
      if (warehouse.id == id) return warehouse;
    }
    return null;
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
        (56, _docHeaderText('Số lượng\nTheo chứng từ')),
        (56, _docHeaderText('Số lượng\nThực nhập')),
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
      final expected = _parseOptional(line.expectedQty) ?? 0;
      final actual = _parseOptional(line.actualQty) ?? 0;
      final price = _parseOptional(line.unitPrice) ?? 0;
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
          (56, _cellText(_formatNum(expected))),
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
      final group = groups[i];
      if (group == 0) continue;
      final hasHigherValue = groups.skip(i + 1).any((item) => item > 0);
      if (group < 100 && hasHigherValue) parts.add('không trăm');
      final hundreds = group ~/ 100;
      final tens = (group % 100) ~/ 10;
      final ones = group % 10;
      if (hundreds > 0) parts.add('${digits[hundreds]} trăm');
      if (tens == 1) {
        parts.add('mười');
        if (ones == 5) {
          parts.add('lăm');
        } else if (ones > 0) {
          parts.add(digits[ones]);
        }
      } else if (tens > 1) {
        parts.add('${digits[tens]} mươi');
        if (ones == 1) {
          parts.add('mốt');
        } else if (ones == 5) {
          parts.add('lăm');
        } else if (ones > 0) {
          parts.add(digits[ones]);
        }
      } else if (ones > 0) {
        if (hundreds > 0 || hasHigherValue) parts.add('linh');
        parts.add(ones == 5 ? 'năm' : digits[ones]);
      }
      if (i > 0) parts.add(units[i]);
    }
    var text = parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (negative) text = 'âm $text';
    return '$text đồng';
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
        title: Text(_isEdit ? 'Sửa phiếu nhập' : 'Tạo phiếu nhập'),
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
                        label: _saving ? 'Đang lưu...' : 'Lưu phiếu nhập',
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
      floatingActionButton: _currentStep == 1 && _products.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'receipt_add_product',
                  onPressed: _navigateToCreateProduct,
                  backgroundColor: ColorSkin.primary,
                  foregroundColor: ColorSkin.white,
                  icon: const Icon(Icons.add, color: ColorSkin.white),
                  label: const Text(
                    'Thêm sản phẩm',
                    style: TextStyle(color: ColorSkin.white),
                  ),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'receipt_add',
                  backgroundColor: ColorSkin.primary,
                  onPressed: _addLine,
                  child: const Icon(Icons.add, color: ColorSkin.white),
                ),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
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

class _ReceiptLineDraft {
  _ReceiptLineDraft({
    this.productId = '',
    this.unitName = '',
    this.expectedQty = '',
    this.actualQty = '',
    this.unitPrice = '',
    this.batchNo = '',
    this.expiryDate = '',
    this.manufactureDate = '',
  });

  String productId;
  String unitName;
  String expectedQty;
  String actualQty;
  String unitPrice;
  String batchNo;
  String expiryDate;
  String manufactureDate;

  Map<String, dynamic> toJson(String Function(String) toIsoDate) {
    return {
      'productId': productId.trim(),
      'unitName': unitName.trim(),
      'expectedQty':
          double.tryParse(expectedQty.trim().replaceAll(',', '.')) ?? 0,
      'actualQty': double.tryParse(actualQty.trim().replaceAll(',', '.')) ?? 0,
      'unitPrice': double.tryParse(unitPrice.trim().replaceAll(',', '.')) ?? 0,
      if (batchNo.trim().isNotEmpty) 'batchNo': batchNo.trim(),
      if (expiryDate.trim().isNotEmpty) 'expiryDate': toIsoDate(expiryDate),
      if (manufactureDate.trim().isNotEmpty)
        'manufactureDate': toIsoDate(manufactureDate),
    };
  }
}

class _ReceiptLineItem extends StatelessWidget {
  const _ReceiptLineItem({
    required this.index,
    required this.draft,
    required this.products,
    required this.productStock,
    required this.onChanged,
    required this.productTitleById,
    required this.formatNum,
    this.onRemove,
  });

  final int index;
  final _ReceiptLineDraft draft;
  final List<Product> products;
  final Map<String, double> productStock;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final String Function(String id) productTitleById;
  final String Function(double value) formatNum;

  double? _parseOptional(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final available = productStock[draft.productId] ?? 0;
    final currentQty = _parseOptional(draft.actualQty) ?? 0;
    final currentExpected = _parseOptional(draft.expectedQty) ?? 0;
    final overStock =
        draft.productId.isNotEmpty &&
        available > 0 &&
        (currentExpected > available || currentQty > available);

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
                initialValue: draft.expectedQty,
                hintText: '0',
                onChanged: (value) => draft.expectedQty = value,
                required: true,
                nonNegative: true,
                max: draft.productId.isEmpty ? null : available,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppNumberField(
                label: 'SL thực nhập',
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
        Row(
          children: [
            Expanded(
              child: AppNumberField(
                label: 'Đơn giá',
                initialValue: draft.unitPrice,
                hintText: '0',
                onChanged: (value) => draft.unitPrice = value,
                nonNegative: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Batch No',
                initialValue: draft.batchNo,
                hintText: 'Nhập batch',
                onChanged: (value) => draft.batchNo = value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'HSD',
                initialValue: draft.expiryDate,
                hintText: 'dd/MM/yyyy',
                onChanged: (value) => draft.expiryDate = value,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'NSX',
                initialValue: draft.manufactureDate,
                hintText: 'dd/MM/yyyy',
                onChanged: (value) => draft.manufactureDate = value,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
