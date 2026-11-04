import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../models/settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<String?> _prompt(BuildContext context,
      {required String title, String initial = '', String? hint, bool secret = false}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: secret,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final theme = Theme.of(context);
    final done = state.doneActions;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Google account'),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(state.account?.email ?? 'Not connected'),
            subtitle: Text(state.gmailConnected
                ? 'Reading school and club emails'
                : 'Connect to read school and club emails'),
            trailing: state.gmailConnected
                ? TextButton(onPressed: state.disconnectGmail, child: const Text('Disconnect'))
                : FilledButton(onPressed: state.connectGmail, child: const Text('Connect')),
          ),
          const _Header('Children'),
          for (final child in s.children)
            ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: Text(child),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close),
                onPressed: () => state.updateSettings((x) => x.children.remove(child)),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add a child'),
            onTap: () async {
              final name = await _prompt(context, title: "Child's first name");
              if (name != null && name.isNotEmpty) {
                await state.updateSettings((x) => x.children.add(name));
              }
            },
          ),
          const _Header('School and club senders'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              s.senders.isEmpty
                  ? 'Sortapp is finding school and club emails by keyword. '
                      'Add senders to read only those.'
                  : 'Sortapp reads only emails from these senders.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final sender in s.senders)
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: Text(sender),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close),
                onPressed: () => state.updateSettings((x) => x.senders.remove(sender)),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add a sender'),
            subtitle: const Text('An address or domain, e.g. office@school.org.uk or myschool.org.uk'),
            onTap: () async {
              final v = await _prompt(context, title: 'Sender address or domain');
              if (v != null && v.isNotEmpty) {
                await state.updateSettings((x) => x.senders.add(v));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Look back'),
            trailing: DropdownButton<int>(
              value: s.lookbackDays,
              underline: const SizedBox.shrink(),
              items: const [7, 14, 30, 60]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                  .toList(),
              onChanged: (d) {
                if (d != null) state.updateSettings((x) => x.lookbackDays = d);
              },
            ),
          ),
          const _Header('AI'),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('OpenAI API key'),
            subtitle: Text(state.hasApiKey ? 'Set (stored on this phone)' : 'Not set'),
            onTap: () async {
              final v = await _prompt(context, title: 'OpenAI API key', secret: true, hint: 'sk-...');
              if (v != null) await state.updateSettings((x) => x.openAiKey = v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Model'),
            subtitle: Text(s.model),
            onTap: () async {
              final v = await _prompt(context,
                  title: 'Model', initial: s.model, hint: AppSettings.defaultModel);
              if (v != null && v.isNotEmpty) await state.updateSettings((x) => x.model = v);
            },
          ),
          if (done.isNotEmpty) ...[
            const _Header('Recently done'),
            for (final item in done.take(10))
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(item.title),
                subtitle: item.keyDate == null
                    ? null
                    : Text(formatWhen(item.keyDate!, allDay: item.allDay || item.start == null)),
                trailing: TextButton(
                    onPressed: () => state.reopen(item), child: const Text('Reopen')),
              ),
          ],
          const _Header('Your data'),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text('Delete all Sortapp data',
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle: const Text('Removes actions and settings from this phone and disconnects Google'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete everything?'),
                  content: const Text(
                      'This removes all actions and settings from this phone. Events already in your calendar stay there.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) {
                await state.deleteAllData();
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(label,
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
