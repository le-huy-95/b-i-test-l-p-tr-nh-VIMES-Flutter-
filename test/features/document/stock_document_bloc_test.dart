import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';
import 'package:test_y_app/features/document/bloc/stock_document_bloc.dart';

class MockStockDocumentRepository extends Mock
    implements StockDocumentRepository {}

StockDocument _doc({
  required String id,
  required String status,
  String? currentStepCode,
  List<WorkflowStep> steps = const [],
  DateTime? lastActionAt,
}) {
  return StockDocument(
    id: id,
    documentType: 'stock_receipt',
    documentId: id,
    status: status,
    code: 'PN-LAGOWJ',
    currentStepCode: currentStepCode,
    lastActionAt: lastActionAt,
    steps: steps,
  );
}

WorkflowStep _step({
  required String id,
  required String code,
  required String name,
  required String status,
  int sequence = 1,
}) {
  return WorkflowStep(
    id: id,
    stepCode: code,
    stepName: name,
    sequence: sequence,
    status: status,
  );
}

void main() {
  late MockStockDocumentRepository repository;

  final draft = _doc(
    id: 'doc-1',
    status: 'draft',
    currentStepCode: 'creator',
    lastActionAt: DateTime(2026, 8, 20, 7, 48),
    steps: [
      _step(
        id: 's1',
        code: 'creator',
        name: 'Người lập phiếu',
        status: 'pending',
      ),
      _step(
        id: 's2',
        code: 'delivery',
        name: 'Người giao hàng',
        status: 'pending',
        sequence: 2,
      ),
    ],
  );

  final inReview = _doc(
    id: 'doc-1',
    status: 'in_review',
    currentStepCode: 'delivery',
    lastActionAt: DateTime(2026, 8, 20, 11, 50),
    steps: [
      _step(
        id: 's1',
        code: 'creator',
        name: 'Người lập phiếu',
        status: 'approved',
      ),
      _step(
        id: 's2',
        code: 'delivery',
        name: 'Người giao hàng',
        status: 'pending',
        sequence: 2,
      ),
    ],
  );

  final available = AvailableActions(
    documentId: 'doc-1',
    documentType: 'stock_receipt',
    status: 'in_review',
    currentStepId: 's2',
    currentStepCode: 'delivery',
    currentStepName: 'Người giao hàng',
    actions: const ['approve'],
  );

  setUp(() {
    repository = MockStockDocumentRepository();
  });

  blocTest<StockDocumentBloc, StockDocumentState>(
    'after approve, list item status follows detail even if list API lags',
    build: () {
      when(() => repository.list('stock_receipt')).thenAnswer(
        (_) async => [draft],
      );
      when(
        () => repository.getDetail('stock_receipt', 'doc-1'),
      ).thenAnswer((_) async => inReview);
      when(
        () => repository.timeline('stock_receipt', 'doc-1'),
      ).thenAnswer((_) async => const []);
      when(
        () => repository.availableActions('stock_receipt', 'doc-1'),
      ).thenAnswer((_) async => available);
      when(
        () => repository.action(
          'stock_receipt',
          'doc-1',
          any(),
        ),
      ).thenAnswer((_) async => inReview);
      return StockDocumentBloc(repository: repository);
    },
    act: (bloc) async {
      bloc.add(const StockDocumentStarted('stock_receipt'));
      await bloc.stream.firstWhere((s) => s is StockDocumentLoaded);
      bloc.add(const StockDocumentSelected('doc-1'));
      await bloc.stream.firstWhere(
        (s) => s is StockDocumentLoaded && (s).detail != null,
      );
      // List API keeps returning draft (lag / eventual consistency).
      when(() => repository.list('stock_receipt')).thenAnswer(
        (_) async => [draft],
      );
      bloc.add(
        const StockDocumentActionRequested({
          'action': 'approve',
          'stepId': 's1',
        }),
      );
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      final state = bloc.state;
      expect(state, isA<StockDocumentLoaded>());
      final loaded = state as StockDocumentLoaded;
      expect(loaded.items, hasLength(1));
      expect(loaded.items.first.status, 'in_review');
      expect(loaded.items.first.currentStepCode, 'delivery');
      expect(loaded.detail?.status, 'in_review');
      expect(loaded.isActionSubmitting, isFalse);
    },
  );
}
