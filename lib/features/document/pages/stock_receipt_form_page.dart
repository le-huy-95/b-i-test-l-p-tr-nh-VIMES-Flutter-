import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/datasources/api_services/supplier_api_service.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';
import 'package:test_y_app/domain/repositories/stock_receipt_repository.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/document/widgets/partner_select_dialog.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_date_field.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:test_y_app/shared/widgets/app_number_field.dart';
import 'package:test_y_app/shared/widgets/app_phone_field.dart';
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
  final _deliveredByName = TextEditingController();
  final _deliveredByPhone = TextEditingController();
  final _deliveredByCompanyName = TextEditingController();
  final _deliveredByNote = TextEditingController();
  final _note = TextEditingController();

  String? _selectedWarehouseId;
  String? _supplierId;
  String? _supplierName;
  String _receiptType = 'purchase';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _seeded = false;
  int _currentStep = 0;

  List<Warehouse> _warehouses = const [];
  List<Product> _products = const [];
  List<PartnerSelectDialogItem> _suppliers = const [];
  final List<_ReceiptLineDraft> _lines = [_ReceiptLineDraft()];
  StockReceiptDocumentData? _existing;
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
    _deliveredByName.dispose();
    _deliveredByPhone.dispose();
    _deliveredByCompanyName.dispose();
    _deliveredByNote.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final warehouseRepo = context.read<WarehouseRepository>();
      final productRepo = context.read<ProductRepository>();
      final receiptRepo = context.read<StockReceiptRepository>();
      final results = await Future.wait([
        warehouseRepo.list(),
        productRepo.list(),
        mapSuppliersToPartnerItems(),
        if (widget.receiptId != null) receiptRepo.getById(widget.receiptId!),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0] as List<Warehouse>;
        _products = results[1] as List<Product>;
        _suppliers = results[2] as List<PartnerSelectDialogItem>;
        if (widget.receiptId != null) {
          _existing = results[3] as StockReceiptDocumentData;
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
        _loading = false;
      });
      await _loadProductStock();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    }
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

  void _seedFromExisting(StockReceiptDocumentData existing) {
    _selectedWarehouseId = existing.warehouseId;
    _supplierId = existing.supplierId;
    _supplierName = _supplierNameById(existing.supplierId);
    _receiptType = existing.receiptType;
    _receiptDate.text = DateFormat('dd/MM/yyyy').format(existing.receiptDate);
    _deliveredByName.text = existing.deliveredByName ?? '';
    _note.text = existing.note ?? '';
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
    _seeded = true;
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
    final created = await showModalBottomSheet<SupplierOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartnerCreateSheet(
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
    if (_deliveredByName.text.trim().isEmpty) {
      if (showError) {
        SimpleSnackbarService.showError('Vui lòng nhập người giao hàng');
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
    final body = <String, dynamic>{
      'warehouseId': _selectedWarehouseId,
      'receiptType': _receiptType,
      'receiptDate': _toIsoDate(_receiptDate.text),
      if (_supplierId != null && _supplierId!.trim().isNotEmpty)
        'supplierId': _supplierId!.trim(),
      'deliveredBy': {
        'contactId': '',
        'kind': 'external',
        'fullName': _deliveredByName.text.trim(),
        'phone': _deliveredByPhone.text.trim(),
        'companyName': _deliveredByCompanyName.text.trim(),
        if (_deliveredByNote.text.trim().isNotEmpty)
          'note': _deliveredByNote.text.trim(),
      },
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
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

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
          label: 'Người giao hàng',
          controller: _deliveredByName,
          hintText: 'Nhập họ tên',
          required: true,
        ),
        const SizedBox(height: 12),
        AppPhoneField(
          label: 'SĐT người giao hàng',
          controller: _deliveredByPhone,
          hintText: 'Nhập số điện thoại',
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Công ty / Đơn vị giao',
          controller: _deliveredByCompanyName,
          hintText: 'Nhập công ty / đơn vị',
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Ghi chú người giao',
          controller: _deliveredByNote,
          hintText: 'Nhập ghi chú',
          maxLines: 2,
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
          label: 'Tên tenant',
          initialValue: _tenantName,
          readOnly: true,
          enabled: false,
        ),
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

  Widget _buildReview() {
    final date =
        DateTime.tryParse(_toIsoDate(_receiptDate.text)) ?? DateTime.now();
    final warehouse = _warehouseById(_selectedWarehouseId);
    final code = _existing?.code ?? '';
    final deliveredBy = _deliveredByName.text.trim();
    final supplier = _supplierDisplayName();
    final location = warehouse == null
        ? '………………………………'
        : '${warehouse.code} · ${warehouse.name}';
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
          Text(
            '- Họ và tên người giao: ${deliveredBy.isEmpty ? '…………………' : deliveredBy}',
          ),
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
              'Người giao hàng',
              'Thủ kho',
              'Kế toán trưởng',
            ],
            signatureNames: {'Người lập phiếu': _currentUserName ?? ''},
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

  Widget _docRow(List<(double, Widget)> cells) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++)
            Container(
              width: cells[i].$1,
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
        ],
      ),
    );
  }

  Widget _buildDocTable() {
    final rows = <Widget>[
      _docRow([
        (32.0, _docHeaderText('STT')),
        (
          168.0,
          _docHeaderText(
            'Tên, nhãn hiệu, quy cách, phẩm chất vật tư, dụng cụ, sản phẩm, hàng hóa',
          ),
        ),
        (60.0, _docHeaderText('Mã số')),
        (52.0, _docHeaderText('Đơn vị tính')),
        (56.0, _docHeaderText('Số lượng\nTheo chứng từ')),
        (56.0, _docHeaderText('Số lượng\nThực nhập')),
        (64.0, _docHeaderText('Đơn giá')),
        (80.0, _docHeaderText('Thành tiền')),
      ]),
      _docRow([
        (32.0, _cellText('A')),
        (168.0, _cellText('B')),
        (60.0, _cellText('C')),
        (52.0, _cellText('D')),
        (56.0, _cellText('1')),
        (56.0, _cellText('2')),
        (64.0, _cellText('3')),
        (80.0, _cellText('4')),
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
          (32.0, _cellText('${i + 1}')),
          (
            168.0,
            _cellText(
              product?.name ?? (line.productId.isEmpty ? '—' : line.productId),
              align: TextAlign.left,
            ),
          ),
          (60.0, _cellText(product?.sku ?? '—')),
          (52.0, _cellText(line.unitName)),
          (56.0, _cellText(_formatNum(expected))),
          (56.0, _cellText(_formatNum(actual))),
          (64.0, _cellText(_formatNum(price))),
          (80.0, _cellText(_formatNum(actual * price))),
        ]),
      );
    }

    const tableWidth = 568.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: tableWidth,
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.black45)),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );
  }

  Widget _buildSignatureRow(
    List<String> roles, {
    Map<String, String>? signatureNames,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in roles)
          Expanded(
            child: Column(
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
                if (signatureNames?[role] != null &&
                    signatureNames![role]!.isNotEmpty) ...[
                  _fitOnOneLine(
                    Text(
                      signatureNames[role]!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                _fitOnOneLine(
                  const Text(
                    '(Ký, họ tên)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _fitOnOneLine(Widget child) {
    return FittedBox(fit: BoxFit.scaleDown, child: child);
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
