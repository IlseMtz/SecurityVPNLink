import 'package:flutter_test/flutter_test.dart';
import 'package:securelink_app/main.dart';

void main() {
  testWidgets('el inicio muestra el formulario de acceso de SecureLink', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('SecureLink'), findsOneWidget);
    expect(find.text('Resumen general'), findsNothing);
  });
}
