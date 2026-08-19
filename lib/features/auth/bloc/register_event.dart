import 'package:equatable/equatable.dart';
import 'package:test_y_app/features/auth/bloc/register_state.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

class RegisterDraftUpdated extends RegisterEvent {
  const RegisterDraftUpdated(this.draft);

  final RegisterFormDraft draft;

  @override
  List<Object?> get props => [draft];
}

class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted();
}

class RegisterStatusCleared extends RegisterEvent {
  const RegisterStatusCleared();
}
