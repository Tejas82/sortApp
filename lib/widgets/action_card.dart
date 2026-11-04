import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/urgency.dart';
import '../models/action_item.dart';

enum CardMenu { reply, snooze1, snooze3, done, wrong, openEmail }

IconData iconFor(ActionType t) {
  switch (t) {
    case ActionType.event:
      return Icons.event_outlined;
    case ActionType.deadline:
      return Icons.flag_outlined;
    case ActionType.reply:
      return Icons.reply_outlined;
    case ActionType.payment:
      return Icons.payments_outlined;
    case ActionType.prep:
      return Icons.backpack_outlined;
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.item,
    required this.onCalendar,
    required this.onReply,
    required this.onMenu,
    this.now,
  });

  final ActionItem item;
  final VoidCallback onCalendar;
  final VoidCallback onReply;
  final ValueChanged<CardMenu> onMenu;
  final DateTime? now;

  String? _whenLine() {
    final t = now ?? DateTime.now();
    if (item.start != null) {
      final s = formatWhen(item.start!, allDay: item.allDay);
      if (item.deadline != null) {
        return '$s · due ${formatWhen(item.deadline!, allDay: true)}';
      }
      return s;
    }
    if (item.deadline != null) {
      final d = daysUntil(item.deadline!, t);
      final rel = d < 0
          ? 'overdue'
          : d == 0
              ? 'today'
              : d == 1
                  ? 'tomorrow'
                  : 'in $d days';
      return 'Due ${formatWhen(item.deadline!, allDay: true)} ($rel)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final when = _whenLine();
    final primaryIsReply = item.type == ActionType.reply ||
        (!item.canAddToCalendar && item.canReply && item.suggestedReply != null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(iconFor(item.type),
                      size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (when != null) ...[
                        const SizedBox(height: 2),
                        Text(when,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.primary)),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<CardMenu>(
                  tooltip: 'More',
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    if (item.canReply && !primaryIsReply)
                      const PopupMenuItem(value: CardMenu.reply, child: Text('Draft a reply')),
                    const PopupMenuItem(value: CardMenu.snooze1, child: Text('Snooze 1 day')),
                    const PopupMenuItem(value: CardMenu.snooze3, child: Text('Snooze 3 days')),
                    const PopupMenuItem(value: CardMenu.done, child: Text('Mark done')),
                    const PopupMenuItem(value: CardMenu.wrong, child: Text("This isn't right")),
                    if (item.fromGmail && item.threadId != null)
                      const PopupMenuItem(value: CardMenu.openEmail, child: Text('Open email')),
                  ],
                ),
              ],
            ),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(item.summary, style: theme.textTheme.bodyMedium),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (item.child != null)
                  _Tag(label: item.child!, icon: Icons.child_care_outlined),
                if (item.location?.isNotEmpty ?? false)
                  _Tag(label: item.location!, icon: Icons.place_outlined),
                if (item.needsCheck)
                  _Tag(
                    label: 'Check the details',
                    icon: Icons.info_outline,
                    color: scheme.tertiaryContainer,
                    onColor: scheme.onTertiaryContainer,
                  ),
                if (item.addedToCalendar)
                  const _Tag(label: 'In calendar', icon: Icons.check),
                if (item.draftSaved)
                  const _Tag(label: 'Draft in Gmail', icon: Icons.check),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.sourceSubject.isEmpty
                        ? ''
                        : '${item.sourceFrom.isEmpty ? '' : '${senderName(item.sourceFrom)} · '}${item.sourceSubject}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (primaryIsReply && item.canReply)
                  FilledButton.tonalIcon(
                    onPressed: onReply,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Draft reply'),
                  )
                else if (item.canAddToCalendar && !item.addedToCalendar)
                  FilledButton.tonalIcon(
                    onPressed: onCalendar,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Add'),
                  )
                else
                  TextButton(
                    onPressed: () => onMenu(CardMenu.done),
                    child: const Text('Done'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon, this.color, this.onColor});

  final String label;
  final IconData icon;
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = onColor ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}
