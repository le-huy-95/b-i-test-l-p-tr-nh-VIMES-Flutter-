import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';

sealed class ProductLookupEvent extends Equatable {
  const ProductLookupEvent();
  @override
  List<Object?> get props => [];
}

class ProductLookupSubmitted extends ProductLookupEvent {
  const ProductLookupSubmitted(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

sealed class ProductLookupState extends Equatable {
  const ProductLookupState();
  @override
  List<Object?> get props => [];
}

class ProductLookupInitial extends ProductLookupState {
  const ProductLookupInitial();
}

class ProductLookupLoading extends ProductLookupState {
  const ProductLookupLoading();
}

class ProductLookupFound extends ProductLookupState {
  const ProductLookupFound(this.product);
  final Product product;
  @override
  List<Object?> get props => [product];
}

class ProductLookupEmpty extends ProductLookupState {
  const ProductLookupEmpty(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

class ProductLookupFailure extends ProductLookupState {
  const ProductLookupFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ProductLookupBloc extends Bloc<ProductLookupEvent, ProductLookupState> {
  ProductLookupBloc({required ProductRepository repository})
      : _repository = repository,
        super(const ProductLookupInitial()) {
    on<ProductLookupSubmitted>(_onSubmit);
  }

  final ProductRepository _repository;

  Future<void> _onSubmit(
    ProductLookupSubmitted event,
    Emitter<ProductLookupState> emit,
  ) async {
    final code = event.code.trim();
    if (code.isEmpty) {
      emit(const ProductLookupFailure('Nhập barcode, SKU hoặc tên sản phẩm'));
      return;
    }
    emit(const ProductLookupLoading());
    try {
      final matches = await _repository.search(code, limit: 10);
      if (matches.isEmpty) {
        emit(ProductLookupEmpty(code));
        return;
      }
      final exactBarcode = matches.where(
        (p) => (p.barcode ?? '').toLowerCase() == code.toLowerCase(),
      );
      final exactSku = matches.where(
        (p) => p.sku.toLowerCase() == code.toLowerCase(),
      );
      final chosen = exactBarcode.isNotEmpty
          ? exactBarcode.first
          : exactSku.isNotEmpty
              ? exactSku.first
              : matches.first;
      emit(ProductLookupFound(chosen));
    } catch (e) {
      emit(ProductLookupFailure(_friendly(e)));
    }
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
