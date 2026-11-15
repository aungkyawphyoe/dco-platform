import 'package:dco_mobile/core/widgets/keyboard_dismissal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('outside touch and Done dismiss, while Next moves focus', (
    tester,
  ) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardDismissal(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: first, textInputAction: TextInputAction.next),
              TextField(
                focusNode: second,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => submitted = value,
              ),
              const Text('Outside'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(first.hasFocus, isTrue);
    await tester.tap(find.text('Outside'));
    await tester.pump();
    expect(first.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(second.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField).last, 'saved value');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(second.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(submitted, 'saved value');
  });
}
