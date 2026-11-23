// Prueba base de ONEchat (Etapa 0): la app arranca en la pantalla
// de acceso con su marca y su botón principal.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:onechat/main.dart';

void main() {
  testWidgets('La pantalla de acceso muestra marca y botón principal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OneChatApp());

    expect(find.text('ONEchat'), findsOneWidget);
    expect(find.text('CHATEAR DIRECTAMENTE'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    // El acceso es unificado: ya no existe «Iniciar sesión» aparte;
    // el nickname registrado pide la contraseña en esta misma pantalla.
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
