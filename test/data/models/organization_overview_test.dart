import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';

Map<String, dynamic> _orgPayload({bool withInventory = true}) {
  return {
    'generatedAt': '2026-08-17T14:00:00.000Z',
    'visibilityScope': withInventory ? 'organization' : 'own_documents',
    'role': withInventory ? 'admin' : 'warehouse_keeper',
    'filters': {
      'from': '2026-07-18T00:00:00.000Z',
      'to': '2026-08-17T14:00:00.000Z',
      'expiryDays': 30,
      'topLimit': 5,
      'recentLimit': 5,
    },
    'organization': {
      'warehouseCount': 2,
      'warehouses': [
        {'id': 'w1', 'code': 'WH01', 'name': 'Kho chính'},
        {'id': 'w2', 'code': 'WH02', 'name': 'Kho phụ'},
      ],
    },
    'documents': {
      'stockReceipts': {
        'byStatus': {
          'draft': 1,
          'pending_approval': 2,
          'approved': 0,
          'completed': 10,
          'rejected': 0,
          'cancelled': 0,
        },
        'total': 13,
        'pendingApproval': 2,
        'draft': 1,
        'completed': 10,
        'pendingApprovalList': [
          {
            'id': 'r1',
            'code': 'PN-001',
            'receiptDate': '2026-08-10T00:00:00.000Z',
            'receiptType': 'purchase',
            'totalAmount': '1500000.00',
            'status': 'pending_approval',
            'createdAt': '2026-08-10T08:00:00.000Z',
            'warehouse': {'id': 'w1', 'code': 'WH01', 'name': 'Kho chính'},
            'supplier': {'id': 's1', 'code': 'NCC01', 'name': 'NCC A'},
            'createdById': 'u1',
          },
        ],
      },
      'stockIssues': {
        'byStatus': {
          'draft': 0,
          'pending_approval': 1,
          'approved': 0,
          'completed': 8,
          'rejected': 0,
          'cancelled': 0,
        },
        'total': 9,
        'pendingApproval': 1,
        'draft': 0,
        'completed': 8,
        'pendingApprovalList': [
          {
            'id': 'i1',
            'code': 'PX-001',
            'issueDate': '2026-08-11T00:00:00.000Z',
            'issueType': 'sale',
            'status': 'pending_approval',
            'createdAt': '2026-08-09T08:00:00.000Z',
            'warehouse': {'id': 'w1', 'code': 'WH01', 'name': 'Kho chính'},
            'customer': {'id': 'c1', 'code': 'KH01', 'name': 'KH A'},
            'createdById': 'u1',
          },
        ],
      },
      'stockOpenings': {
        'byStatus': {
          'draft': 0,
          'pending_approval': 0,
          'approved': 0,
          'completed': 1,
          'rejected': 0,
          'cancelled': 0,
        },
        'total': 1,
        'pendingApproval': 0,
        'draft': 0,
        'completed': 1,
      },
    },
    'productMovement': {
      'totalImportedQty': '100.0000',
      'totalExportedQty': '40.5000',
      'topImportedProducts': [
        {
          'productId': 'p1',
          'sku': 'VT-001',
          'name': 'Găng tay y tế M',
          'baseUnitName': 'hộp',
          'totalQty': '80.0000',
          'documentCount': 3,
        },
      ],
      'topExportedProducts': [
        {
          'productId': 'p2',
          'sku': 'VT-014',
          'name': 'Khẩu trang N95',
          'baseUnitName': 'hộp',
          'totalQty': '20.5000',
          'documentCount': 2,
        },
      ],
      'dailyMovement': [
        {'date': '2026-08-15', 'importedQty': '40.0000', 'exportedQty': '10.0000'},
        {'date': '2026-08-16', 'importedQty': '60.0000', 'exportedQty': '30.5000'},
      ],
    },
    'inventory': withInventory
        ? {
            'skuCount': 42,
            'totalOnhandQty': '1580.0000',
            'totalReservedQty': '120.0000',
            'totalAvailableQty': '1460.0000',
            'estimatedStockValue': '2450000.00',
            'lowStockCount': 3,
            'expiryAlertCount': 2,
            'activeReservationCount': 5,
          }
        : null,
    'warehousesBreakdown': withInventory
        ? [
            {
              'warehouse': {'id': 'w1', 'code': 'WH01', 'name': 'Kho chính'},
              'productMovement': {
                'totalImportedQty': '90.0000',
                'totalExportedQty': '30.0000',
              },
              'stockReceipts': {
                'byStatus': {
                  'draft': 1,
                  'pending_approval': 2,
                  'approved': 0,
                  'completed': 10,
                  'rejected': 0,
                  'cancelled': 0,
                },
                'total': 13,
                'pendingApproval': 2,
                'draft': 1,
                'completed': 10,
              },
              'stockIssues': {
                'byStatus': {
                  'draft': 0,
                  'pending_approval': 1,
                  'approved': 0,
                  'completed': 8,
                  'rejected': 0,
                  'cancelled': 0,
                },
                'total': 9,
                'pendingApproval': 1,
                'draft': 0,
                'completed': 8,
              },
            },
          ]
        : [],
  };
}

void main() {
  test('parses organization-scope overview and derived fields', () {
    final overview = OrganizationOverview.fromJson(_orgPayload());

    expect(overview.visibilityScope, 'organization');
    expect(overview.isOrganizationScope, isTrue);
    expect(overview.role, 'admin');
    expect(overview.organization.warehouseCount, 2);
    expect(overview.organization.warehouses.first.code, 'WH01');
    expect(overview.documents.stockReceipts.pendingApproval, 2);
    expect(
      overview.documents.stockReceipts.pendingApprovalList.first.code,
      'PN-001',
    );
    expect(
      overview.documents.stockIssues.pendingApprovalList.first.customer?.name,
      'KH A',
    );
    expect(overview.productMovement.topImportedProducts.first.sku, 'VT-001');
    expect(overview.productMovement.dailyMovement, hasLength(2));
    expect(overview.productMovement.dailyMovement.first.date, '2026-08-15');
    expect(overview.inventory?.estimatedStockValue, '2450000.00');
    expect(overview.inventory?.lowStockCount, 3);
    expect(overview.alertCount, 5);
    expect(overview.pendingApprovalCount, 3);
    expect(overview.warehousesBreakdown, hasLength(1));
    expect(
      overview.warehousesBreakdown.first.productMovement.totalImportedQty,
      '90.0000',
    );

    final pending = overview.pendingDocuments;
    expect(pending, hasLength(2));
    expect(pending.first.code, 'PX-001');
    expect(pending.first.kind, PendingDocumentKind.issue);
    expect(pending.last.code, 'PN-001');
    expect(pending.last.kind, PendingDocumentKind.receipt);
  });

  test('parses own_documents scope with null inventory', () {
    final overview = OrganizationOverview.fromJson(
      _orgPayload(withInventory: false),
    );

    expect(overview.visibilityScope, 'own_documents');
    expect(overview.isOrganizationScope, isFalse);
    expect(overview.inventory, isNull);
    expect(overview.alertCount, 0);
    expect(overview.warehousesBreakdown, isEmpty);
    expect(overview.productMovement.totalExportedQty, '40.5000');
  });

  test('defaults dailyMovement when field is missing', () {
    final payload = Map<String, dynamic>.from(_orgPayload());
    final movement = Map<String, dynamic>.from(
      payload['productMovement'] as Map,
    );
    movement.remove('dailyMovement');
    payload['productMovement'] = movement;

    final overview = OrganizationOverview.fromJson(payload);

    expect(overview.productMovement.dailyMovement, isEmpty);
    expect(overview.productMovement.resolvedDailyMovement, isEmpty);
  });
}
