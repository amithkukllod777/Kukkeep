import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukkeep/screens/draw_screen.dart';

// `flutter create` (run fresh in CI — native scaffolding isn't committed)
// only creates a file under this exact name if one doesn't already exist, and
// its default template pumps a boilerplate `MyApp` this codebase doesn't
// have. Committing a real test under this filename keeps CI from silently
// regenerating and failing on that boilerplate.
//
// DrawScreen is the one full screen with no network/Firebase dependency at
// build time, so it's safe to pump directly in a widget test without mocking
// Api/Firebase.
void main() {
  testWidgets('DrawScreen renders with undo/redo/clear disabled on an empty canvas', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DrawScreen()));

    expect(find.text('Drawing'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    final undo = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    final redo = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.redo));
    final clear = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline));
    expect(undo.onPressed, isNull);
    expect(redo.onPressed, isNull);
    expect(clear.onPressed, isNull);
  });
}
