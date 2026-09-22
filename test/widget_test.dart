import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/shared/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders its title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.note_alt_outlined,
            title: 'No notes yet',
            message: 'Create your first note to get started.',
          ),
        ),
      ),
    );

    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('Create your first note to get started.'), findsOneWidget);
    expect(find.byIcon(Icons.note_alt_outlined), findsOneWidget);
  });
}
