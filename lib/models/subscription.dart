import 'server_profile.dart';

class SubscriptionUsage {
  const SubscriptionUsage({
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expiryUnix = 0,
  });

  final int upload;
  final int download;
  final int total;
  final int expiryUnix;

  int get used => upload + download;

  bool get hasExpiry => expiryUnix > 0;

  bool get isExpired => isExpiredAt(DateTime.now());

  bool isExpiredAt(DateTime now) {
    if (!hasExpiry) return false;
    return expiryUnix <= now.millisecondsSinceEpoch ~/ 1000;
  }

  double get fraction {
    if (total <= 0) return 0;
    return (used / total).clamp(0.0, 1.0).toDouble();
  }

  int? get daysRemaining {
    if (expiryUnix <= 0) return null;
    final Duration remaining = DateTime.fromMillisecondsSinceEpoch(
      expiryUnix * 1000,
    ).difference(DateTime.now());
    return remaining.inDays < 0 ? 0 : remaining.inDays;
  }

  Map<String, Object> toJson() => <String, Object>{
        'upload': upload,
        'download': download,
        'total': total,
        'expiryUnix': expiryUnix,
      };

  factory SubscriptionUsage.fromJson(Map<String, Object?> json) {
    return SubscriptionUsage(
      upload: json['upload'] as int? ?? 0,
      download: json['download'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      expiryUnix: json['expiryUnix'] as int? ?? 0,
    );
  }
}

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    required this.servers,
    required this.updatedAt,
    this.usage = const SubscriptionUsage(),
  });

  final String id;
  final String name;
  final String url;
  final List<ServerProfile> servers;
  final DateTime updatedAt;
  final SubscriptionUsage usage;

  bool get isRemote => url.isNotEmpty;

  bool get isExpired => usage.isExpired;

  bool containsServer(String serverId) {
    return servers.any((ServerProfile server) => server.id == serverId);
  }

  Subscription copyWith({
    String? name,
    List<ServerProfile>? servers,
    DateTime? updatedAt,
    SubscriptionUsage? usage,
  }) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      url: url,
      servers: servers ?? this.servers,
      updatedAt: updatedAt ?? this.updatedAt,
      usage: usage ?? this.usage,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'url': url,
        'servers': servers.map((ServerProfile item) => item.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'usage': usage.toJson(),
      };

  factory Subscription.fromJson(Map<String, Object?> json) {
    final List<Object?> rawServers = json['servers']! as List<Object?>;
    return Subscription(
      id: json['id']! as String,
      name: json['name']! as String,
      url: json['url']! as String,
      servers: rawServers
          .map(
            (Object? item) =>
                ServerProfile.fromJson(item! as Map<String, Object?>),
          )
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      usage: SubscriptionUsage.fromJson(
        json['usage']! as Map<String, Object?>,
      ),
    );
  }
}
