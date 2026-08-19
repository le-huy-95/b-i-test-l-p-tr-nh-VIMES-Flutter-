import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';

sealed class ProductListEvent extends Equatable {
  const ProductListEvent();
  @override
  List<Object?> get props => [];
}

class ProductListStarted extends ProductListEvent {
  const ProductListStarted();
}

class ProductListRefreshed extends ProductListEvent {
  const ProductListRefreshed();
}

class ProductListSearchChanged extends ProductListEvent {
  const ProductListSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

sealed class ProductListState extends Equatable {
  const ProductListState();
  @override
  List<Object?> get props => [];
}

class ProductListInitial extends ProductListState {
  const ProductListInitial();
}

class ProductListLoading extends ProductListState {
  const ProductListLoading();
}

class ProductListLoaded extends ProductListState {
  const ProductListLoaded({required this.items, required this.query});
  final List<Product> items;
  final String query;

  List<Product> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              (p.barcode?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  List<Object?> get props => [items, query];
}

class ProductListFailure extends ProductListState {
  const ProductListFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  ProductListBloc({required ProductRepository repository})
      : _repository = repository,
        super(const ProductListInitial()) {
    on<ProductListStarted>(_onLoad);
    on<ProductListRefreshed>(_onLoad);
    on<ProductListSearchChanged>(_onSearch);
  }

  final ProductRepository _repository;
  List<Product> _cache = const [];

  Future<void> _onLoad(
    ProductListEvent event,
    Emitter<ProductListState> emit,
  ) async {
    final query = state is ProductListLoaded ? (state as ProductListLoaded).query : '';
    emit(const ProductListLoading());
    try {
      _cache = await _repository.list();
      emit(ProductListLoaded(items: _cache, query: query));
    } catch (e) {
      emit(ProductListFailure(_friendly(e)));
    }
  }

  void _onSearch(
    ProductListSearchChanged event,
    Emitter<ProductListState> emit,
  ) {
    emit(ProductListLoaded(items: _cache, query: event.query));
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
