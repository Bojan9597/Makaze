import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logs in and shows customer navigation only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MakazeApp(authClient: FakeAuthClient()));

    expect(find.text('Logovanje'), findsOneWidget);
    expect(find.text('Registracija'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.ensureVisible(find.text('Prijavi se'));
    await tester.tap(find.text('Prijavi se'));
    await tester.pumpAndSettle();

    expect(find.text('Saloni'), findsWidgets);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Termini'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Zahtjevi'), findsNothing);
    expect(find.text('Kalendar'), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('salon login shows salon navigation only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MakazeApp(authClient: FakeAuthClient(role: AppRole.salon)),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'salon@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.ensureVisible(find.text('Prijavi se'));
    await tester.tap(find.text('Prijavi se'));
    await tester.pumpAndSettle();

    expect(find.text('Danas'), findsWidgets);
    expect(find.text('Zahtjevi'), findsWidgets);
    expect(find.text('Kalendar'), findsWidgets);
    expect(find.text('Saloni'), findsNothing);
    expect(find.text('Mapa'), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('can switch from login to registration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MakazeApp(authClient: FakeAuthClient()));

    await tester.ensureVisible(find.text('Nemam nalog - registracija'));
    await tester.tap(find.text('Nemam nalog - registracija'));
    await tester.pumpAndSettle();

    expect(find.text('Registracija'), findsOneWidget);
    expect(find.text('Ime i prezime'), findsOneWidget);
    expect(find.text('Kreiraj nalog'), findsOneWidget);
  });
}

class FakeAuthClient implements AuthClient {
  const FakeAuthClient({this.role = AppRole.customer});

  final AppRole role;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return AuthSession(
      token: 'fake-token',
      userId: 'fake-user-id',
      fullName: 'Test User',
      email: email,
      role: role,
      salonId: role == AppRole.salon ? 'fake-salon-id' : null,
      salonName: role == AppRole.salon ? 'Test Salon' : null,
    );
  }

  @override
  Future<AuthSession> register({
    required AppRole role,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String salonName,
    required String salonAddress,
    required String city,
    double? latitude,
    double? longitude,
  }) async {
    return AuthSession(
      token: 'fake-token',
      userId: 'fake-user-id',
      fullName: fullName,
      email: email,
      role: role,
    );
  }
}
