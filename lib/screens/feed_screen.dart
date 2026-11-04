import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core/urgency.dart';
import '../models/action_item.dart';
import '../widgets/action_card.dart';
import '../widgets/edit_event_sheet.dart';
import 'paste_screen.dart';
import 'settings_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  void _snack(BuildContext context, String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), action: action));
  }

  Future<void> _sync(BuildContext context) async {
    final state = context.read<AppState>();
    final added = await state.sync();
    if (!context.mounted) return;
    if (state.lastError != null) {
      _snack(context, state.lastError!);
    } else {
      _snack(context, added == 0 ? 'All sorted. Nothing new.' : '$added new action${added == 1 ? '' : 's'}');
    }
  }

  Future<void> _addToCalendar(BuildContext context, ActionItem item) async {
    final state = context.read<AppState>();
    final edited = await showEditEventSheet(context, item);
    if (edited == null || !context.mounted) return;
    try {
      await state.addToCalendar(edited);
      if (context.mounted) _snack(context, 'Added to your calendar');
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not add event: $e');
    }
  }

  Future<void> _reply(BuildContext context, ActionItem item) async {
    final state = context.read<AppState>();
    final controller = TextEditingController(text: item.suggestedReply ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 10,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Write your reply'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save as Gmail draft'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || !context.mounted) return;
    try {
      await state.saveReplyDraft(item, text);
      if (context.mounted) {
        _snack(context, 'Draft saved in Gmail. Review and send it there.',
            action: item.threadId == null
                ? null
                : SnackBarAction(label: 'Open', onPressed: () => _openEmail(item)));
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not save draft: $e');
    }
  }

  Future<void> _openEmail(ActionItem item) async {
    final uri = Uri.parse('https://mail.google.com/mail/u/0/#all/${item.threadId}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _menu(BuildContext context, ActionItem item, CardMenu choice) async {
    final state = context.read<AppState>();
    switch (choice) {
      case CardMenu.reply:
        await _reply(context, item);
      case CardMenu.snooze1:
        await state.snooze(item, const Duration(days: 1));
        if (context.mounted) _snack(context, 'Snoozed until tomorrow');
      case CardMenu.snooze3:
        await state.snooze(item, const Duration(days: 3));
        if (context.mounted) _snack(context, 'Snoozed for 3 days');
      case CardMenu.done:
        await state.markDone(item);
        if (context.mounted) {
          _snack(context, 'Marked done',
              action: SnackBarAction(label: 'Undo', onPressed: () => state.reopen(item)));
        }
      case CardMenu.wrong:
        await state.dismiss(item, wrong: true);
        if (context.mounted) {
          _snack(context, 'Removed. Thanks, this helps Sortapp learn.',
              action: SnackBarAction(label: 'Undo', onPressed: () => state.reopen(item)));
        }
      case CardMenu.openEmail:
        await _openEmail(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final items = state.activeActions(now);

    final children = <Widget>[];
    UrgencyBucket? current;
    for (final item in items) {
      final b = bucketFor(item, now);
      if (b != current) {
        current = b;
        children.add(_SectionHeader(label: bucketLabel(b), overdue: b == UrgencyBucket.overdue));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.check),
          ),
          onDismissed: (_) => _menu(context, item, CardMenu.done),
          child: ActionCard(
            item: item,
            now: now,
            onCalendar: () => _addToCalendar(context, item),
            onReply: () => _reply(context, item),
            onMenu: (c) => _menu(context, item, c),
          ),
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sortapp'),
        actions: [
          IconButton(
            tooltip: 'Check for new messages',
            onPressed: state.syncing ? null : () => _sync(context),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: state.syncing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Column(
                  children: [
                    Text(
                      state.syncTotal == 0
                          ? 'Looking for school and club emails…'
                          : 'Sorting ${state.syncDone} of ${state.syncTotal}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: state.syncTotal == 0 ? null : state.syncDone / state.syncTotal,
                    ),
                  ],
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const PasteScreen())),
        icon: const Icon(Icons.content_paste),
        label: const Text('Paste'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _sync(context),
        child: items.isEmpty
            ? _EmptyState(state: state, onSync: () => _sync(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: children,
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.overdue = false});
  final String label;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: overdue ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state, required this.onSync});
  final AppState state;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title;
    final String body;
    if (state.syncing) {
      title = 'Sorting your messages';
      body = 'Your first actions will appear here in a moment.';
    } else if (!state.gmailConnected) {
      title = 'Nothing here yet';
      body = 'Connect Gmail in Settings, or paste a message to try Sortapp.';
    } else {
      title = 'All sorted';
      body = 'No actions need you right now. Pull down to check again.';
    }
    // ListView so pull-to-refresh works on the empty state too.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.inbox_outlined, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (state.lastError != null) ...[
          const SizedBox(height: 16),
          Text(state.lastError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
        if (state.gmailConnected && !state.syncing) ...[
          const SizedBox(height: 24),
          Center(child: OutlinedButton(onPressed: onSync, child: const Text('Check now'))),
        ],
      ],
    );
  }
}
