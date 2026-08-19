import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';

sealed class StockDocumentEvent extends Equatable {
  const StockDocumentEvent();
  @override
  List<Object?> get props => [];
}

class StockDocumentStarted extends StockDocumentEvent {
  const StockDocumentStarted(this.documentType);
  final String documentType;
  @override
  List<Object?> get props => [documentType];
}

class StockDocumentRefreshRequested extends StockDocumentEvent {
  const StockDocumentRefreshRequested(this.documentType);
  final String documentType;
  @override
  List<Object?> get props => [documentType];
}

class StockDocumentTypeChanged extends StockDocumentEvent {
  const StockDocumentTypeChanged(this.documentType);
  final String documentType;
  @override
  List<Object?> get props => [documentType];
}

class StockDocumentActionRequested extends StockDocumentEvent {
  const StockDocumentActionRequested(this.body);
  final Map<String, dynamic> body;
  @override
  List<Object?> get props => [body];
}

class StockDocumentSelected extends StockDocumentEvent {
  const StockDocumentSelected(this.documentId);
  final String documentId;
  @override
  List<Object?> get props => [documentId];
}

sealed class StockDocumentState extends Equatable {
  const StockDocumentState();
  @override
  List<Object?> get props => [];
}

class StockDocumentInitial extends StockDocumentState {
  const StockDocumentInitial();
}

class StockDocumentLoading extends StockDocumentState {
  const StockDocumentLoading({required this.documentType});
  final String documentType;
  @override
  List<Object?> get props => [documentType];
}

class StockDocumentLoaded extends StockDocumentState {
  const StockDocumentLoaded({
    required this.documentType,
    required this.items,
    this.selectedId,
    this.detail,
    this.timeline = const [],
    this.isDetailLoading = false,
    this.isActionSubmitting = false,
    this.message,
  });

  final String documentType;
  final List<StockDocument> items;
  final String? selectedId;
  final StockDocument? detail;
  final List<TimelineEvent> timeline;
  final bool isDetailLoading;
  final bool isActionSubmitting;
  final String? message;

  @override
  List<Object?> get props => [
    documentType,
    items,
    selectedId,
    detail,
    timeline,
    isDetailLoading,
    isActionSubmitting,
    message,
  ];
}

class StockDocumentFailure extends StockDocumentState {
  const StockDocumentFailure(this.documentType, this.message);
  final String documentType;
  final String message;
  @override
  List<Object?> get props => [documentType, message];
}

class StockDocumentBloc extends Bloc<StockDocumentEvent, StockDocumentState> {
  StockDocumentBloc({required StockDocumentRepository repository})
    : _repository = repository,
      super(const StockDocumentInitial()) {
    on<StockDocumentStarted>(_onStarted);
    on<StockDocumentRefreshRequested>(_onRefresh);
    on<StockDocumentTypeChanged>(_onTypeChanged);
    on<StockDocumentActionRequested>(_onActionRequested);
    on<StockDocumentSelected>(_onSelected);
  }

  final StockDocumentRepository _repository;
  final Map<String, _DocumentTabCache> _tabCache = {};
  String _documentType = 'stock_issue';
  String? _selectedId;
  int _epoch = 0;

  Future<void> _onStarted(
    StockDocumentStarted event,
    Emitter<StockDocumentState> emit,
  ) async {
    _documentType = event.documentType;
    final cache = _tabCache[_documentType];
    if (cache != null) {
      _selectedId = cache.selectedId;
      emit(_loadedFromCache(_documentType, cache));
      return;
    }
    await _loadList(emit, showLoading: true);
  }

  Future<void> _onRefresh(
    StockDocumentRefreshRequested event,
    Emitter<StockDocumentState> emit,
  ) async {
    _documentType = event.documentType;
    await _loadList(
      emit,
      showLoading: false,
      preserveSelection: true,
      forceReload: true,
    );
  }

  Future<void> _onTypeChanged(
    StockDocumentTypeChanged event,
    Emitter<StockDocumentState> emit,
  ) async {
    if (_documentType == event.documentType) return;
    _documentType = event.documentType;
    final cache = _tabCache[_documentType];
    if (cache != null) {
      _selectedId = cache.selectedId;
      emit(_loadedFromCache(_documentType, cache));
      return;
    }
    _selectedId = null;
    await _loadList(emit, showLoading: true);
  }

  Future<void> _onSelected(
    StockDocumentSelected event,
    Emitter<StockDocumentState> emit,
  ) async {
    _selectedId = event.documentId;
    final cache = _tabCache[_documentType];
    if (cache != null &&
        cache.selectedId == event.documentId &&
        cache.detail != null) {
      emit(_loadedFromCache(_documentType, cache));
      return;
    }
    await _loadDetail(event.documentId, emit, showLoading: true);
  }

  Future<void> _onActionRequested(
    StockDocumentActionRequested event,
    Emitter<StockDocumentState> emit,
  ) async {
    final selectedId = _selectedId;
    if (selectedId == null) return;
    emit(_currentLoaded(isActionSubmitting: true));
    try {
      await _repository.action(_documentType, selectedId, event.body);
      await _loadList(
        emit,
        showLoading: false,
        preserveSelection: true,
        forceReload: true,
      );
    } catch (e) {
      emit(_currentLoaded(isActionSubmitting: false, message: _friendly(e)));
    }
  }

  Future<void> _loadList(
    Emitter<StockDocumentState> emit, {
    required bool showLoading,
    bool preserveSelection = false,
    bool forceReload = false,
  }) async {
    final type = _documentType;
    final epoch = ++_epoch;
    final cache = _tabCache[type];

    if (!forceReload && cache != null) {
      _selectedId = cache.selectedId;
      emit(_loadedFromCache(type, cache));
      return;
    }

    if (showLoading) {
      emit(StockDocumentLoading(documentType: type));
    }

    try {
      final list = await _repository.list(type);
      if (epoch != _epoch) return;

      final previousCache = _tabCache[type];
      final selectedId = _resolveSelectedId(
        list,
        preserveSelection: preserveSelection,
        currentSelectedId: _selectedId ?? previousCache?.selectedId,
      );

      _selectedId = selectedId;

      if (selectedId == null) {
        _tabCache[type] = _DocumentTabCache(items: list, selectedId: null);
        emit(StockDocumentLoaded(documentType: type, items: list));
        return;
      }

      final cachedDetail = previousCache?.detail;
      final cachedTimeline = previousCache?.timeline ?? const <TimelineEvent>[];
      final canReuseDetail =
          cachedDetail != null && cachedDetail.documentId == selectedId;

      if (canReuseDetail) {
        _tabCache[type] = _DocumentTabCache(
          items: list,
          selectedId: selectedId,
          detail: cachedDetail,
          timeline: cachedTimeline,
        );
        emit(
          StockDocumentLoaded(
            documentType: type,
            items: list,
            selectedId: selectedId,
            detail: cachedDetail,
            timeline: cachedTimeline,
          ),
        );
        return;
      }

      _tabCache[type] = _DocumentTabCache(items: list, selectedId: selectedId);
      emit(
        StockDocumentLoaded(
          documentType: type,
          items: list,
          selectedId: selectedId,
        ),
      );
      await _loadDetail(selectedId, emit, showLoading: true);
    } catch (e) {
      if (epoch == _epoch) {
        emit(StockDocumentFailure(type, _friendly(e)));
      }
    }
  }

  Future<void> _loadDetail(
    String id,
    Emitter<StockDocumentState> emit, {
    required bool showLoading,
  }) async {
    final type = _documentType;
    final epoch = ++_epoch;
    if (showLoading) {
      emit(_currentLoaded(isDetailLoading: true));
    }
    try {
      final detailFuture = _repository.getDetail(type, id);
      final timelineFuture = _repository.timeline(type, id);
      final detail = await detailFuture;
      final timeline = await timelineFuture;
      if (epoch != _epoch) return;
      _tabCache[type] = _DocumentTabCache(
        items: _tabCache[type]?.items ?? const [],
        selectedId: id,
        detail: detail,
        timeline: timeline,
      );
      emit(
        StockDocumentLoaded(
          documentType: type,
          items: _tabCache[type]?.items ?? const [],
          selectedId: id,
          detail: detail,
          timeline: timeline,
        ),
      );
    } catch (e) {
      if (epoch == _epoch) {
        emit(_currentLoaded(isDetailLoading: false, message: _friendly(e)));
      }
    }
  }

  StockDocumentLoaded _currentLoaded({
    bool? isDetailLoading,
    bool? isActionSubmitting,
    String? message,
  }) {
    final cache = _tabCache[_documentType];
    if (cache != null) {
      return StockDocumentLoaded(
        documentType: _documentType,
        items: cache.items,
        selectedId: cache.selectedId,
        detail: cache.detail,
        timeline: cache.timeline,
        isDetailLoading: isDetailLoading ?? false,
        isActionSubmitting: isActionSubmitting ?? false,
        message: message,
      );
    }

    return StockDocumentLoaded(
      documentType: _documentType,
      items: const [],
      selectedId: _selectedId,
      isDetailLoading: isDetailLoading ?? false,
      isActionSubmitting: isActionSubmitting ?? false,
      message: message,
    );
  }

  StockDocumentLoaded _loadedFromCache(
    String type,
    _DocumentTabCache cache, {
    bool isDetailLoading = false,
    bool isActionSubmitting = false,
    String? message,
  }) {
    return StockDocumentLoaded(
      documentType: type,
      items: cache.items,
      selectedId: cache.selectedId,
      detail: cache.detail,
      timeline: cache.timeline,
      isDetailLoading: isDetailLoading,
      isActionSubmitting: isActionSubmitting,
      message: message,
    );
  }

  String? _resolveSelectedId(
    List<StockDocument> items, {
    required bool preserveSelection,
    required String? currentSelectedId,
  }) {
    if (items.isEmpty) return null;
    if (preserveSelection &&
        currentSelectedId != null &&
        items.any((item) => item.documentId == currentSelectedId)) {
      return currentSelectedId;
    }
    return items.first.documentId;
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}

class _DocumentTabCache {
  const _DocumentTabCache({
    required this.items,
    this.selectedId,
    this.detail,
    this.timeline = const [],
  });

  final List<StockDocument> items;
  final String? selectedId;
  final StockDocument? detail;
  final List<TimelineEvent> timeline;
}
