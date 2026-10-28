import 'package:digidropp_todo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('reads the title from .env and adds a todo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'APP_TITLE=Test Todos\nENVIRONMENT=ci');

    await tester.pumpWidget(TodoApp(config: AppConfig.fromEnv(), envLoaded: true));
    await tester.pumpAndSettle();
    expect(find.text('Test Todos'), findsOneWidget);
    expect(find.text('CI'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ship the build');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Ship the build'), findsOneWidget);
    expect(find.text('1 left · built by Digidropp'), findsOneWidget);
  });
}
