import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';
import 'package:test_y_app/features/product/widgets/product_unit_editor.dart';

sealed class ProductFormEvent extends Equatable {
  const ProductFormEvent();
  @override
  List<Object?> get props => [];
}

class ProductFormLoadExisting extends ProductFormEvent {
  const ProductFormLoadExisting(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class ProductFormSubmitted extends ProductFormEvent {
  const ProductFormSubmitted({
    required this.sku,
    required this.name,
    this.barcode,
    this.imageFileId,
    this.removeImage = false,
    this.baseUnitName,
    this.minStockLevel = 0,
    this.maxStockLevel,
    this.reorderPoint,
    this.averageCost = 0,
    this.units = const [],
  });

  final String sku;
  final String name;
  final String? barcode;

  /// ID file ảnh nhận từ `POST /api/v1/files`, backend tự liên kết
  /// `uploaded_files.url` vào `products.image_url`.
  final String? imageFileId;

  /// Chỉ có ý nghĩa khi cập nhật: người dùng chủ động gỡ ảnh hiện tại.
  final bool removeImage;
  final String? baseUnitName;
  final double minStockLevel;
  final double? maxStockLevel;
  final double? reorderPoint;
  final double averageCost;
  final List<ProductUnitInput> units;

  @override
  List<Object?> get props => [
        sku,
        name,
        barcode,
        imageFileId,
        removeImage,
        baseUnitName,
        minStockLevel,
        maxStockLevel,
        reorderPoint,
        averageCost,
        units,
      ];
}

sealed class ProductFormState extends Equatable {
  const ProductFormState();
  @override
  List<Object?> get props => [];
}

class ProductFormInitial extends ProductFormState {
  const ProductFormInitial({this.existing});
  final Product? existing;
  @override
  List<Object?> get props => [existing];
}

class ProductFormLoading extends ProductFormState {
  const ProductFormLoading();
}

class ProductFormSubmitting extends ProductFormState {
  const ProductFormSubmitting();
}

class ProductFormSuccess extends ProductFormState {
  const ProductFormSuccess(this.product);
  final Product product;
  @override
  List<Object?> get props => [product];
}

class ProductFormFailure extends ProductFormState {
  const ProductFormFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ProductFormBloc extends Bloc<ProductFormEvent, ProductFormState> {
  ProductFormBloc({
    required ProductRepository repository,
    this.productId,
  })  : _repository = repository,
        super(const ProductFormInitial()) {
    on<ProductFormLoadExisting>(_onLoad);
    on<ProductFormSubmitted>(_onSubmit);
  }

  final ProductRepository _repository;
  final String? productId;

  Future<void> _onLoad(
    ProductFormLoadExisting event,
    Emitter<ProductFormState> emit,
  ) async {
    emit(const ProductFormLoading());
    try {
      final existing = await _repository.getById(event.id);
      emit(ProductFormInitial(existing: existing));
    } catch (e) {
      emit(ProductFormFailure(_friendly(e)));
    }
  }

  Future<void> _onSubmit(
    ProductFormSubmitted event,
    Emitter<ProductFormState> emit,
  ) async {
    emit(const ProductFormSubmitting());
    try {
      final body = <String, dynamic>{
        'sku': event.sku.trim(),
        'name': event.name.trim(),
        if (event.barcode != null && event.barcode!.trim().isNotEmpty)
          'barcode': event.barcode!.trim(),
        if (event.imageFileId != null && event.imageFileId!.trim().isNotEmpty)
          'imageFileId': event.imageFileId!.trim(),
        if (productId != null && event.removeImage) 'imageUrl': null,
        if (event.baseUnitName != null && event.baseUnitName!.trim().isNotEmpty)
          'baseUnitName': event.baseUnitName!.trim(),
        'minStockLevel': event.minStockLevel,
        if (event.maxStockLevel != null) 'maxStockLevel': event.maxStockLevel,
        if (event.reorderPoint != null) 'reorderPoint': event.reorderPoint,
        'averageCost': event.averageCost,
        if (productId == null && event.units.isNotEmpty)
          'units': event.units
              .map(
                (u) => <String, dynamic>{
                  'unitName': u.unitName.trim(),
                  'conversionRate': u.conversionRate,
                },
              )
              .toList(),
      };
      final Product result;
      if (productId == null) {
        result = await _repository.create(body);
      } else {
        result = await _repository.update(productId!, body);
      }
      emit(ProductFormSuccess(result));
    } catch (e) {
      emit(ProductFormFailure(_friendly(e)));
    }
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
