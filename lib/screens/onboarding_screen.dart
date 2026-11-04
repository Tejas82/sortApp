import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'paste_screen.dart';

/// Activation in as few steps as possible: names (optional), an API key if
/// none was built in, then connect Gmail and see the first actions.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _children = TextEditingController();
  final _key = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _children.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _saveBasics(AppState state) async {
    final names = _children.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await state.updateSettings((s) {
      if (names.isNotEmpty) s.children = names;
      if (_key.text.trim().isNotEmpty) s.openAiKey = _key.text.trim();
    });
  }

  Future<void> _connect(AppState state) async {
    setState(() => _busy = true);
    await _saveBasics(state);
    final ok = await state.connectGmail();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.lastError ?? 'Sign-in was cancelled.')));
      return;
    }
    await state.completeOnboarding();
    // Fire the first sync; the feed shows progress.
    state.sync();
  }

  Future<void> _tryPaste(AppState state) async {
    await _saveBasics(state);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PasteScreen(fromOnboarding: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Icon(Icons.checklist_rtl_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('See it. Sort it.',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Sortapp reads school and club emails and turns them into '
              'one-tap actions: add to calendar, reply, or remember to do it.',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _children,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Your children's first names (optional)",
                hintText: 'e.g. Aarav, Mira',
                helperText: 'Used to tag each action to the right child',
              ),
            ),
            if (!state.hasApiKey) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _key,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'OpenAI API key',
                  helperText: 'Prototype only: stored on this phone',
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _busy ? null : () => _connect(state),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.mail_outline),
              label: const Text('Connect Gmail'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _tryPaste(state),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Try it with a pasted message first'),
            ),
            const SizedBox(height: 32),
            _PrivacyNote(theme: theme),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What Sortapp reads',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            '• Only emails that look like school or club messages, from the last 30 days.\n'
            '• Only the extracted actions are saved on your phone, not your emails.\n'
            '• Nothing is sent or added to your calendar without your tap.\n'
            '• Calendar access is asked for only when you first add an event.',
            style: style,
          ),
        ],
      ),
    );
  }
}
