import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';

sealed class ProductDetailEvent extends Equatable {
  const ProductDetailEvent();
  @override
  List<Object?> get props => [];
}

class ProductDetailStarted extends ProductDetailEvent {
  const ProductDetailStarted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class ProductDetailRefreshRequested extends ProductDetailEvent {
  const ProductDetailRefreshRequested();
}

class ProductDetailDeleteRequested extends ProductDetailEvent {
  const ProductDetailDeleteRequested();
}

sealed class ProductDetailState extends Equatable {
  const ProductDetailState();
  @override
  List<Object?> get props => [];
}

class ProductDetailInitial extends ProductDetailState {
  const ProductDetailInitial();
}

class ProductDetailLoading extends ProductDetailState {
  const ProductDetailLoading();
}

class ProductDetailLoaded extends ProductDetailState {
  const ProductDetailLoaded({required this.product, this.availability});
  final Product product;
  final ProductAvailability? availability;
  @override
  List<Object?> get props => [product, availability];
}

class ProductDetailDeleted extends ProductDetailState {
  const ProductDetailDeleted();
}

class ProductDetailFailure extends ProductDetailState {
  const ProductDetailFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ProductDetailBloc extends Bloc<ProductDetailEvent, ProductDetailState> {
  ProductDetailBloc({
    required ProductRepository repository,
    required this.productId,
  })  : _repository = repository,
        super(const ProductDetailInitial()) {
    on<ProductDetailStarted>(_onStarted);
    on<ProductDetailRefreshRequested>(_onRefresh);
    on<ProductDetailDeleteRequested>(_onDelete);
  }

  final ProductRepository _repository;
  final String productId;

  Future<void> _onStarted(
    ProductDetailStarted event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(const ProductDetailLoading());
    try {
      final result = await _loadProduct(event.id);
      emit(result);
    } catch (e) {
      emit(ProductDetailFailure(_friendly(e)));
    }
  }

  Future<void> _onRefresh(
    ProductDetailRefreshRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    final currentId = productId;
    emit(const ProductDetailLoading());
    try {
      final result = await _loadProduct(currentId);
      emit(result);
    } catch (e) {
      emit(ProductDetailFailure(_friendly(e)));
    }
  }

  Future<ProductDetailLoaded> _loadProduct(String id) async {
    final product = await _repository.getById(id);
    ProductAvailability? availability;
    try {
      availability = await _repository.getAvailability(id);
    } catch (_) {
      availability = null;
    }
    return ProductDetailLoaded(product: product, availability: availability);
  }

  Future<void> _onDelete(
    ProductDetailDeleteRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(const ProductDetailLoading());
    try {
      await _repository.delete(productId);
      emit(const ProductDetailDeleted());
    } catch (e) {
      emit(ProductDetailFailure(_friendly(e)));
    }
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
