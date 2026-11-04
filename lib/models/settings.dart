class AppSettings {
  AppSettings({
    this.openAiKey = '',
    this.model = defaultModel,
    List<String>? children,
    List<String>? senders,
    this.lookbackDays = 30,
    this.onboarded = false,
  })  : children = children ?? [],
        senders = senders ?? [];

  static const defaultModel = 'gpt-4o-mini';

  /// Stored on the device only. A build-time key can be passed with
  /// `--dart-define=OPENAI_API_KEY=...` instead.
  String openAiKey;
  String model;

  /// Children's first names, used to tag actions to the right child.
  List<String> children;

  /// Sender addresses or domains to read. Empty = keyword auto-detect.
  List<String> senders;
  int lookbackDays;
  bool onboarded;

  Map<String, dynamic> toJson() => {
        'openAiKey': openAiKey,
        'model': model,
        'children': children,
        'senders': senders,
        'lookbackDays': lookbackDays,
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        openAiKey: (j['openAiKey'] as String?) ?? '',
        model: (j['model'] as String?) ?? defaultModel,
        children: ((j['children'] as List?) ?? []).cast<String>(),
        senders: ((j['senders'] as List?) ?? []).cast<String>(),
        lookbackDays: (j['lookbackDays'] as int?) ?? 30,
        onboarded: (j['onboarded'] as bool?) ?? false,
      );
}
