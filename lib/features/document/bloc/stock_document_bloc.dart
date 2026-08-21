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
    this.availableActions,
    this.isDetailLoading = false,
    this.isActionSubmitting = false,
    this.message,
  });

  final String documentType;
  final List<StockDocument> items;
  final String? selectedId;
  final StockDocument? detail;
  final List<TimelineEvent> timeline;
  final AvailableActions? availableActions;
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
    availableActions,
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
    // Process events one-by-one so _epoch cancellation cannot drop a
    // just-completed action refresh while another load is in flight.
    on<StockDocumentStarted>(_onStarted, transformer: _sequential());
    on<StockDocumentRefreshRequested>(_onRefresh, transformer: _sequential());
    on<StockDocumentTypeChanged>(_onTypeChanged, transformer: _sequential());
    on<StockDocumentActionRequested>(
      _onActionRequested,
      transformer: _sequential(),
    );
    on<StockDocumentSelected>(_onSelected, transformer: _sequential());
  }

  final StockDocumentRepository _repository;
  final Map<String, _DocumentTabCache> _tabCache = {};
  String _documentType = 'stock_issue';
  String? _selectedId;
  int _epoch = 0;

  static EventTransformer<T> _sequential<T>() {
    return (events, mapper) => events.asyncExpand(mapper);
  }

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
      // Show cached detail immediately, then refresh in background.
      emit(_loadedFromCache(_documentType, cache));
    }
    await _loadDetail(event.documentId, emit, showLoading: cache?.detail == null);
  }

  Future<void> _onActionRequested(
    StockDocumentActionRequested event,
    Emitter<StockDocumentState> emit,
  ) async {
    final selectedId = _selectedId;
    if (selectedId == null) return;
    emit(_currentLoaded(isActionSubmitting: true));
    try {
      final actionResult = await _repository.action(
        _documentType,
        selectedId,
        event.body,
      );
      // Optimistic list sync from action response (status/step may be partial).
      _upsertListItem(actionResult);

      await _loadDetail(
        selectedId,
        emit,
        showLoading: false,
        isActionSubmitting: true,
      );

      // Detail is the source of truth right after a mutation.
      final mutationDetail = _tabCache[_documentType]?.detail ?? actionResult;
      _upsertListItem(mutationDetail);
      emit(
        _currentLoaded(
          isActionSubmitting: true,
          detailOverride: mutationDetail,
        ),
      );

      await _loadList(
        emit,
        showLoading: false,
        preserveSelection: true,
        forceReload: true,
        isActionSubmitting: true,
      );

      // List API can lag behind workflow mutations — re-apply detail fields.
      final latestDetail = _tabCache[_documentType]?.detail ?? mutationDetail;
      if (latestDetail.documentId == selectedId) {
        _upsertListItem(latestDetail);
      }
      emit(_currentLoaded(isActionSubmitting: false));
    } catch (e) {
      emit(_currentLoaded(isActionSubmitting: false, message: _friendly(e)));
    }
  }

  Future<void> _loadList(
    Emitter<StockDocumentState> emit, {
    required bool showLoading,
    bool preserveSelection = false,
    bool forceReload = false,
    bool isActionSubmitting = false,
  }) async {
    final type = _documentType;
    final epoch = ++_epoch;
    final cache = _tabCache[type];

    if (!forceReload && cache != null) {
      _selectedId = cache.selectedId;
      emit(
        _loadedFromCache(
          type,
          cache,
          isActionSubmitting: isActionSubmitting,
        ),
      );
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
        emit(
          StockDocumentLoaded(
            documentType: type,
            items: list,
            isActionSubmitting: isActionSubmitting,
          ),
        );
        return;
      }

      final cachedDetail = previousCache?.detail;
      final cachedTimeline = previousCache?.timeline ?? const <TimelineEvent>[];
      final cachedAvailable = previousCache?.availableActions;
      final canReuseDetail =
          cachedDetail != null && cachedDetail.documentId == selectedId;

      if (canReuseDetail) {
        _tabCache[type] = _DocumentTabCache(
          items: list,
          selectedId: selectedId,
          detail: cachedDetail,
          timeline: cachedTimeline,
          availableActions: cachedAvailable,
        );
        emit(
          StockDocumentLoaded(
            documentType: type,
            items: list,
            selectedId: selectedId,
            detail: cachedDetail,
            timeline: cachedTimeline,
            availableActions: cachedAvailable,
            isActionSubmitting: isActionSubmitting,
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
          isActionSubmitting: isActionSubmitting,
        ),
      );
      await _loadDetail(
        selectedId,
        emit,
        showLoading: true,
        isActionSubmitting: isActionSubmitting,
      );
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
    bool isActionSubmitting = false,
  }) async {
    final type = _documentType;
    final epoch = ++_epoch;
    if (showLoading) {
      emit(
        _currentLoaded(
          isDetailLoading: true,
          isActionSubmitting: isActionSubmitting,
        ),
      );
    }
    try {
      final detailFuture = _repository.getDetail(type, id);
      final timelineFuture = _repository.timeline(type, id);
      final availableFuture = _repository.availableActions(type, id);
      final detail = await detailFuture;
      final timeline = await timelineFuture;
      AvailableActions? available;
      try {
        available = await availableFuture;
      } catch (_) {
        // available-actions is supplementary; non-fatal.
      }
      if (epoch != _epoch) return;

      final previousItems = _tabCache[type]?.items ?? const <StockDocument>[];
      final items = _itemsWithUpsert(previousItems, detail);
      _tabCache[type] = _DocumentTabCache(
        items: items,
        selectedId: id,
        detail: detail,
        timeline: timeline,
        availableActions: available,
      );
      emit(
        StockDocumentLoaded(
          documentType: type,
          items: items,
          selectedId: id,
          detail: detail,
          timeline: timeline,
          availableActions: available,
          isActionSubmitting: isActionSubmitting,
        ),
      );
    } catch (e) {
      if (epoch == _epoch) {
        emit(
          _currentLoaded(
            isDetailLoading: false,
            isActionSubmitting: isActionSubmitting,
            message: _friendly(e),
          ),
        );
      }
    }
  }

  /// Sync a document into the in-memory list cache (status / current step).
  void _upsertListItem(StockDocument document) {
    final type = _documentType;
    final cache = _tabCache[type];
    final previous = cache?.items ?? const <StockDocument>[];
    final items = _itemsWithUpsert(previous, document);
    _tabCache[type] = _DocumentTabCache(
      items: items,
      selectedId: cache?.selectedId ?? document.documentId,
      detail: cache?.detail,
      timeline: cache?.timeline ?? const [],
      availableActions: cache?.availableActions,
    );
  }

  static List<StockDocument> _itemsWithUpsert(
    List<StockDocument> items,
    StockDocument document,
  ) {
    final index = items.indexWhere(
      (item) => item.documentId == document.documentId,
    );
    if (index < 0) {
      return [document, ...items];
    }
    final existing = items[index];
    final merged = StockDocument(
      id: document.id.isNotEmpty ? document.id : existing.id,
      documentType: document.documentType.isNotEmpty
          ? document.documentType
          : existing.documentType,
      documentId: document.documentId,
      status: document.status,
      code: document.code ?? existing.code,
      currentStepCode: document.currentStepCode ?? existing.currentStepCode,
      currentStepStatus:
          document.currentStepStatus ?? existing.currentStepStatus,
      currentStepUpdatedAt:
          document.currentStepUpdatedAt ?? existing.currentStepUpdatedAt,
      lastActionById: document.lastActionById ?? existing.lastActionById,
      lastActionAt: document.lastActionAt ?? existing.lastActionAt,
      steps: document.steps.isNotEmpty ? document.steps : existing.steps,
    );
    final next = List<StockDocument>.of(items);
    next[index] = merged;
    return next;
  }

  StockDocumentLoaded _currentLoaded({
    bool? isDetailLoading,
    bool? isActionSubmitting,
    String? message,
    StockDocument? detailOverride,
  }) {
    final cache = _tabCache[_documentType];
    if (cache != null) {
      return StockDocumentLoaded(
        documentType: _documentType,
        items: cache.items,
        selectedId: cache.selectedId,
        detail: detailOverride ?? cache.detail,
        timeline: cache.timeline,
        availableActions: cache.availableActions,
        isDetailLoading: isDetailLoading ?? false,
        isActionSubmitting: isActionSubmitting ?? false,
        message: message,
      );
    }

    return StockDocumentLoaded(
      documentType: _documentType,
      items: const [],
      selectedId: _selectedId,
      detail: detailOverride,
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
      availableActions: cache.availableActions,
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
    this.availableActions,
  });

  final List<StockDocument> items;
  final String? selectedId;
  final StockDocument? detail;
  final List<TimelineEvent> timeline;
  final AvailableActions? availableActions;
}
