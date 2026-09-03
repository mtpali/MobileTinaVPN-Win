enum ThemePreference { system, light, dark }

class AppSettings {
  const AppSettings({
    this.httpPort = 10809,
    this.socksPort = 10808,
    this.systemProxy = true,
    this.startWithWindows = false,
    this.theme = ThemePreference.system,
  });

  final int httpPort;
  final int socksPort;
  final bool systemProxy;
  final bool startWithWindows;
  final ThemePreference theme;

  AppSettings copyWith({
    int? httpPort,
    int? socksPort,
    bool? systemProxy,
    bool? startWithWindows,
    ThemePreference? theme,
  }) {
    return AppSettings(
      httpPort: httpPort ?? this.httpPort,
      socksPort: socksPort ?? this.socksPort,
      systemProxy: systemProxy ?? this.systemProxy,
      startWithWindows: startWithWindows ?? this.startWithWindows,
      theme: theme ?? this.theme,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'httpPort': httpPort,
        'socksPort': socksPort,
        'systemProxy': systemProxy,
        'startWithWindows': startWithWindows,
        'theme': theme.name,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      httpPort: json['httpPort'] as int? ?? 10809,
      socksPort: json['socksPort'] as int? ?? 10808,
      systemProxy: json['systemProxy'] as bool? ?? true,
      startWithWindows: json['startWithWindows'] as bool? ?? false,
      theme: ThemePreference.values.byName(
        json['theme'] as String? ?? ThemePreference.system.name,
      ),
    );
  }
}
