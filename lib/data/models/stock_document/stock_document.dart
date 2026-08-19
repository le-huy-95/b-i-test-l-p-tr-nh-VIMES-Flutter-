class StockDocument {
  const StockDocument({
    required this.id,
    required this.documentType,
    required this.documentId,
    required this.status,
    this.code,
    this.currentStepCode,
    this.currentStepStatus,
    this.currentStepUpdatedAt,
    this.lastActionById,
    this.lastActionAt,
    this.steps = const [],
  });

  final String id;
  final String documentType;
  final String documentId;
  final String status;
  final String? code;
  final String? currentStepCode;
  final String? currentStepStatus;
  final DateTime? currentStepUpdatedAt;
  final String? lastActionById;
  final DateTime? lastActionAt;
  final List<WorkflowStep> steps;

  factory StockDocument.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    return StockDocument(
      id: '${json['id'] ?? ''}',
      documentType: '${json['documentType'] ?? ''}',
      documentId: '${json['documentId'] ?? json['id'] ?? ''}',
      status: '${json['status'] ?? json['documentStatus'] ?? 'draft'}',
      code: json['code']?.toString(),
      currentStepCode: json['currentStepCode']?.toString(),
      currentStepStatus: json['currentStepStatus']?.toString(),
      currentStepUpdatedAt: _parseDate(json['currentStepUpdatedAt']),
      lastActionById: json['lastActionById']?.toString(),
      lastActionAt: _parseDate(json['lastActionAt']),
      steps: rawSteps is List
          ? rawSteps
              .whereType<Map>()
              .map((e) => WorkflowStep.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class WorkflowStep {
  const WorkflowStep({
    required this.id,
    required this.stepCode,
    required this.stepName,
    required this.sequence,
    required this.status,
    this.requiredSignerId,
    this.assignedApproverId,
    this.actualSignerId,
    this.authorizedSignerId,
    this.note,
    this.actionAt,
  });

  final String id;
  final String stepCode;
  final String stepName;
  final int sequence;
  final String status;
  final String? requiredSignerId;
  final String? assignedApproverId;
  final String? actualSignerId;
  final String? authorizedSignerId;
  final String? note;
  final DateTime? actionAt;

  factory WorkflowStep.fromJson(Map<String, dynamic> json) => WorkflowStep(
        id: '${json['id'] ?? ''}',
        stepCode: '${json['stepCode'] ?? ''}',
        stepName: '${json['stepName'] ?? ''}',
        sequence: int.tryParse('${json['sequence'] ?? 0}') ?? 0,
        status: '${json['status'] ?? 'pending'}',
        requiredSignerId: json['requiredSignerId']?.toString(),
        assignedApproverId: json['assignedApproverId']?.toString(),
        actualSignerId: json['actualSignerId']?.toString(),
        authorizedSignerId: json['authorizedSignerId']?.toString(),
        note: json['note']?.toString(),
        actionAt: _parseDate(json['actionAt']),
      );
}

class TimelineEvent {
  const TimelineEvent({required this.toStatus, required this.changedAt, this.fromStatus, this.note});
  final String toStatus;
  final String? fromStatus;
  final DateTime changedAt;
  final String? note;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        fromStatus: json['fromStatus']?.toString(),
        toStatus: '${json['toStatus'] ?? ''}',
        changedAt: _parseDate(json['changedAt']) ?? DateTime.now(),
        note: json['note']?.toString(),
      );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
