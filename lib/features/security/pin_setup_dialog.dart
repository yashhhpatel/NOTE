import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prompts the user to create a PIN (enter, then confirm). Returns the PIN, or
/// null if cancelled. Enforces a 4–8 digit numeric PIN.
Future<String?> showPinSetupDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _PinSetupDialog(),
  );
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _controller = TextEditingController();
  String? _firstEntry;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirming => _firstEntry != null;

  void _submit() {
    final value = _controller.text;
    if (value.length < 4 || value.length > 8) {
      setState(() => _error = 'PIN must be 4–8 digits');
      return;
    }
    if (!_confirming) {
      setState(() {
        _firstEntry = value;
        _error = null;
        _controller.clear();
      });
    } else if (value == _firstEntry) {
      Navigator.pop(context, value);
    } else {
      setState(() {
        _error = 'PINs do not match';
        _firstEntry = null;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_confirming ? 'Confirm PIN' : 'Create a PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: _confirming ? 'Re-enter PIN' : 'Enter 4–8 digits',
              errorText: _error,
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_confirming ? 'Confirm' : 'Next'),
        ),
      ],
    );
  }
}
