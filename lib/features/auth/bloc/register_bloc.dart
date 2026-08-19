import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/register_event.dart';
import 'package:test_y_app/features/auth/bloc/register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const RegisterInitial()) {
    on<RegisterDraftUpdated>(_onDraftUpdated);
    on<RegisterSubmitted>(_onSubmitted);
    on<RegisterStatusCleared>(_onStatusCleared);
  }

  final AuthRepository _authRepository;

  void _onDraftUpdated(
    RegisterDraftUpdated event,
    Emitter<RegisterState> emit,
  ) {
    if (state is RegisterLoading) return;
    emit(RegisterInitial(draft: event.draft));
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    final draft = state.draft;
    final email = draft.email.trim();
    final phone = draft.phone.trim();
    if (phone.isEmpty) {
      emit(RegisterFailure('Vui lòng nhập số điện thoại', draft: draft));
      return;
    }
    emit(RegisterLoading(draft: draft));
    try {
      final result = await _authRepository.register(
        email: email.isEmpty ? null : email,
        phone: phone,
        password: draft.password,
        name: draft.name.trim(),
      );
      emit(RegisterSuccess(result, draft: draft));
    } catch (e) {
      emit(RegisterFailure(e.toString(), draft: draft));
    }
  }

  void _onStatusCleared(
    RegisterStatusCleared event,
    Emitter<RegisterState> emit,
  ) {
    emit(RegisterInitial(draft: state.draft));
  }
}
