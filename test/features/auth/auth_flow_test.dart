import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_torneo_flash/core/errors/auth_failure.dart';
import 'package:tu_torneo_flash/data/dto/profile.dart';
import 'package:tu_torneo_flash/data/repositories/auth_repository.dart';
import 'package:tu_torneo_flash/features/auth/session.dart';
import 'package:tu_torneo_flash/features/profile/profile_controller.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('login', () {
    testWidgets('organizer pages ask for login and return there afterwards', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        profiles: FakeProfileRepository(namedProfile()),
        initialLocation: '/profile',
      );
      expect(currentPath(c), '/login');

      await tester.enterText(field('Correo electrónico'), 'ana@test.dev');
      await tester.enterText(field('Contraseña'), 'secret12');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(currentPath(c), '/profile');
      expect(find.text('Mi perfil'), findsOneWidget);
    });

    testWidgets('validates the form before calling the backend', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth, initialLocation: '/login');

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Este campo es obligatorio'), findsNWidgets(2));

      await tester.enterText(field('Correo electrónico'), 'ana@');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un correo válido'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('shows a friendly message for wrong credentials', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..nextFailure = AuthFailure.invalidCredentials;
      final c = await pumpApp(tester, auth: auth, initialLocation: '/login');

      await tester.enterText(field('Correo electrónico'), 'ana@test.dev');
      await tester.enterText(field('Contraseña'), 'nope');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
      expect(currentPath(c), '/login');
    });

    testWidgets('social buttons follow repository availability', (
      tester,
    ) async {
      await pumpApp(tester, initialLocation: '/login');
      expect(find.text('Continuar con Google'), findsNothing);
      expect(find.text('Continuar con Apple'), findsNothing);
    });

    testWidgets(
      'Apple sign-in stores the shared name and skips complete profile',
      (tester) async {
        final auth = FakeAuthRepository(
          isGoogleAvailable: true,
          isAppleAvailable: true,
        )..appleName = 'Ana López';
        final profiles = FakeProfileRepository(Profile(id: testUser.id));
        final c = await pumpApp(
          tester,
          auth: auth,
          profiles: profiles,
          initialLocation: '/login',
        );
        expect(find.text('Continuar con Google'), findsOneWidget);

        await tester.tap(find.text('Continuar con Apple'));
        await tester.pumpAndSettle();

        expect(profiles.profile?.displayName, 'Ana López');
        expect(currentPath(c), '/my-tournaments');
      },
    );

    testWidgets('a cancelled Google sheet shows no error', (tester) async {
      final auth = FakeAuthRepository(isGoogleAvailable: true)
        ..nextFailure = AuthFailure.cancelled;
      final c = await pumpApp(tester, auth: auth, initialLocation: '/login');

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('Algo salió mal. Inténtalo de nuevo.'), findsNothing);
      expect(currentPath(c), '/login');
    });
  });

  group('sign up', () {
    testWidgets('tells the user to check their email when confirmation is on', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..signUpResult = SignUpResult.confirmationSent;
      final c = await pumpApp(tester, auth: auth, initialLocation: '/sign-up');

      await tester.enterText(field('Correo electrónico'), 'ana@test.dev');
      await tester.enterText(field('Contraseña'), 'short');
      await tester.enterText(field('Confirma la contraseña'), 'other');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);

      await tester.enterText(field('Contraseña'), 'secret12');
      await tester.enterText(field('Confirma la contraseña'), 'secret12');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Te enviamos un correo'), findsOneWidget);
      expect(currentPath(c), '/sign-up');
    });

    testWidgets('a new account without a name completes its profile first', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(Profile(id: testUser.id));
      final c = await pumpApp(
        tester,
        profiles: profiles,
        initialLocation: '/sign-up',
      );

      await tester.enterText(field('Correo electrónico'), 'ana@test.dev');
      await tester.enterText(field('Contraseña'), 'secret12');
      await tester.enterText(field('Confirma la contraseña'), 'secret12');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(currentPath(c), '/complete-profile');

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Este campo es obligatorio'), findsOneWidget);

      await tester.enterText(field('Tu nombre'), '  Ana López ');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(profiles.profile?.displayName, 'Ana López');
      expect(currentPath(c), '/my-tournaments');
    });
  });

  group('password', () {
    testWidgets('forgot password confirms the email was sent', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth, initialLocation: '/login');

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Correo electrónico'), 'ana@test.dev');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['reset:ana@test.dev']);
      expect(find.textContaining('te llegará el enlace'), findsOneWidget);
    });

    testWidgets('a recovery link forces a new password, then continues', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      final c = await pumpApp(
        tester,
        auth: auth,
        profiles: FakeProfileRepository(namedProfile()),
      );
      // The spinner never settles: pump frames by hand while on this screen.
      routerOf(c).go('/login-callback');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.emit(testUser, passwordRecovery: true);
      await tester.pumpAndSettle();
      expect(currentPath(c), '/reset-password');

      await tester.enterText(field('Nueva contraseña'), 'newsecret');
      await tester.enterText(field('Confirma la contraseña'), 'newsecret');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['updatePassword']);
      expect(c.read(sessionProvider).recoveringPassword, isFalse);
      expect(currentPath(c), '/my-tournaments');
    });
  });

  group('profile', () {
    testWidgets('edits the name, uploads an avatar and signs out', (
      tester,
    ) async {
      final auth = FakeAuthRepository(currentUser: testUser);
      final profiles = FakeProfileRepository(namedProfile());
      final c = await pumpApp(
        tester,
        auth: auth,
        profiles: profiles,
        overrides: [
          avatarPickerProvider.overrideWithValue(
            () async => PickedImage(Uint8List.fromList([1, 2, 3]), 'image/png'),
          ),
        ],
        initialLocation: '/my-tournaments',
      );

      await tester.tap(find.byTooltip('Mi perfil'));
      await tester.pumpAndSettle();
      expect(find.text('ana@test.dev'), findsOneWidget);

      await tester.enterText(field('Tu nombre'), 'Ana L.');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil actualizado'), findsOneWidget);
      expect(c.read(sessionProvider).profile?.displayName, 'Ana L.');

      await tester.tap(find.text('Cambiar foto'));
      await tester.pumpAndSettle();
      expect(profiles.uploads, ['image/png']);
      expect(c.read(sessionProvider).profile?.avatarUrl, isNotNull);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(auth.calls.last, 'signOut');
      expect(currentPath(c), '/');
      expect(find.text('Encuentra tu torneo'), findsOneWidget);
    });
  });
}
