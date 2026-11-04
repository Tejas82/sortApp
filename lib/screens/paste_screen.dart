import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

/// Forward-to-try: paste a school or club message and see the actions it
/// contains, without granting any Google access.
class PasteScreen extends StatefulWidget {
  const PasteScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  State<PasteScreen> createState() => _PasteScreenState();
}

class _PasteScreenState extends State<PasteScreen> {
  final _text = TextEditingController();
  final _key = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _run(AppState state) async {
    if (_text.text.trim().length < 20) {
      _snack('Paste the full message so there is something to sort.');
      return;
    }
    if (_key.text.trim().isNotEmpty) {
      await state.updateSettings((s) => s.openAiKey = _key.text.trim());
    }
    setState(() => _busy = true);
    try {
      final added = await state.extractFromPaste(_text.text);
      if (!mounted) return;
      if (added == 0) {
        _snack('Nothing to act on in that message.');
        return;
      }
      if (widget.fromOnboarding) await state.completeOnboarding();
      if (!mounted) return;
      _snack('Found $added action${added == 1 ? '' : 's'}.');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Paste a message')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Copy a message from a school email, WhatsApp group or club app '
              'and paste it here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 16,
              decoration: const InputDecoration(
                hintText:
                    'e.g. "Year 3 trip to the Science Museum on Friday 21 Nov. '
                    'Please return the consent form and £12 by Monday."',
                alignLabelWithHint: true,
              ),
            ),
            if (!state.hasApiKey) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _key,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'OpenAI API key'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(state),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined),
              label: const Text('Sort it'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
