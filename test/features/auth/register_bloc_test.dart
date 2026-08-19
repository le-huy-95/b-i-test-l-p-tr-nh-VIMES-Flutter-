import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_y_app/data/models/auth/register_result.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/register_bloc.dart';
import 'package:test_y_app/features/auth/bloc/register_event.dart';
import 'package:test_y_app/features/auth/bloc/register_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  const draft = RegisterFormDraft(
    name: 'Nguyen Van A',
    email: 'a@vimes.vn',
    phone: '0901234567',
    password: 'secret1',
    agreeTerms: true,
  );

  const result = RegisterResult(
    id: 'u1',
    email: 'a@vimes.vn',
    phone: '0901234567',
    requiresVerification: true,
  );

  setUp(() {
    authRepository = MockAuthRepository();
  });

  RegisterBloc buildBloc() => RegisterBloc(authRepository: authRepository);

  group('RegisterBloc draft', () {
    blocTest<RegisterBloc, RegisterState>(
      'rejects submit when phone is empty',
      build: buildBloc,
      seed: () => const RegisterInitial(
        draft: RegisterFormDraft(
          name: 'Nguyen Van A',
          email: 'a@vimes.vn',
          password: 'secret1',
          agreeTerms: true,
        ),
      ),
      act: (bloc) => bloc.add(const RegisterSubmitted()),
      expect: () => [
        isA<RegisterFailure>().having(
          (s) => s.message,
          'message',
          'Vui lòng nhập số điện thoại',
        ),
      ],
      verify: (_) {
        verifyNever(
          () => authRepository.register(
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          ),
        );
      },
    );

    blocTest<RegisterBloc, RegisterState>(
      'keeps form fields after successful register',
      build: buildBloc,
      setUp: () {
        when(
          () => authRepository.register(
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => result);
      },
      act: (bloc) async {
        bloc.add(const RegisterDraftUpdated(draft));
        bloc.add(const RegisterSubmitted());
      },
      expect: () => [
        isA<RegisterInitial>().having((s) => s.draft, 'draft', draft),
        isA<RegisterLoading>().having((s) => s.draft, 'draft', draft),
        isA<RegisterSuccess>().having((s) => s.draft, 'draft', draft),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      'restores editable step 1 state without losing draft',
      build: buildBloc,
      seed: () => const RegisterSuccess(result, draft: draft),
      act: (bloc) => bloc.add(const RegisterStatusCleared()),
      expect: () => [
        isA<RegisterInitial>().having((s) => s.draft, 'draft', draft),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      'keeps draft when register API fails',
      build: buildBloc,
      setUp: () {
        when(
          () => authRepository.register(
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          ),
        ).thenThrow(Exception('Đăng ký thất bại'));
      },
      seed: () => const RegisterInitial(draft: draft),
      act: (bloc) => bloc.add(const RegisterSubmitted()),
      expect: () => [
        isA<RegisterLoading>().having((s) => s.draft, 'draft', draft),
        isA<RegisterFailure>().having((s) => s.draft, 'draft', draft),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      'allows editing draft after success so returning to step 1 stays in sync',
      build: buildBloc,
      seed: () => const RegisterSuccess(result, draft: draft),
      act: (bloc) => bloc.add(
        const RegisterDraftUpdated(
          RegisterFormDraft(
            name: 'Nguyen Van B',
            email: 'b@vimes.vn',
            phone: '0901234567',
            password: 'secret1',
            agreeTerms: true,
          ),
        ),
      ),
      expect: () => [
        isA<RegisterInitial>().having(
          (s) => s.draft.name,
          'name',
          'Nguyen Van B',
        ),
      ],
    );
  });
}
