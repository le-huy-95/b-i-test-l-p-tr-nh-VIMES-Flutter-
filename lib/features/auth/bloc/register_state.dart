import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/auth/register_result.dart';

class RegisterFormDraft extends Equatable {
  const RegisterFormDraft({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.password = '',
    this.agreeTerms = false,
  });

  final String name;
  final String email;
  final String phone;
  final String password;
  final bool agreeTerms;

  RegisterFormDraft copyWith({
    String? name,
    String? email,
    String? phone,
    String? password,
    bool? agreeTerms,
  }) {
    return RegisterFormDraft(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      agreeTerms: agreeTerms ?? this.agreeTerms,
    );
  }

  @override
  List<Object?> get props => [name, email, phone, password, agreeTerms];
}

sealed class RegisterState extends Equatable {
  const RegisterState({this.draft = const RegisterFormDraft()});

  final RegisterFormDraft draft;

  @override
  List<Object?> get props => [draft];
}

class RegisterInitial extends RegisterState {
  const RegisterInitial({super.draft});
}

class RegisterLoading extends RegisterState {
  const RegisterLoading({required super.draft});
}

class RegisterSuccess extends RegisterState {
  const RegisterSuccess(this.result, {required super.draft});

  final RegisterResult result;

  @override
  List<Object?> get props => [draft, result];
}

class RegisterFailure extends RegisterState {
  const RegisterFailure(this.message, {required super.draft});

  final String message;

  @override
  List<Object?> get props => [draft, message];
}
