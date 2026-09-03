import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/subscription.dart';
import 'codec_utils.dart';
import 'subscription_parser.dart';

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SubscriptionService {
  SubscriptionService({SubscriptionParser? parser})
      : _parser = parser ?? SubscriptionParser();

  final SubscriptionParser _parser;

  Future<Subscription> fetch({
    required String name,
    required String url,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Uri uri = Uri.tryParse(url.trim()) ?? Uri();
    if (!uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const SubscriptionException('لینک اشتراک معتبر نیست.');
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = 'MobileTinaVPN-Windows/0.1';
    try {
      final HttpClientRequest request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = true;
      request.maxRedirects = 5;
      final HttpClientResponse response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SubscriptionException(
          'دریافت اشتراک با خطای ${response.statusCode} روبه‌رو شد.',
        );
      }
      final String payload = await response
          .transform(const Utf8Decoder(allowMalformed: false))
          .join()
          .timeout(timeout);
      final SubscriptionParseResult parsed = _parser.parse(payload);
      if (parsed.servers.isEmpty) {
        throw const SubscriptionException(
          'هیچ سرور پشتیبانی‌شده‌ای در اشتراک پیدا نشد.',
        );
      }
      final String finalName = name.trim().isEmpty ? 'اشتراک من' : name.trim();
      return Subscription(
        id: stableId(uri.toString()),
        name: finalName,
        url: uri.toString(),
        servers: parsed.servers,
        updatedAt: DateTime.now(),
        usage: parseUsage(response.headers.value('subscription-userinfo')),
      );
    } on TimeoutException {
      throw const SubscriptionException('زمان دریافت اشتراک تمام شد.');
    } on SocketException {
      throw const SubscriptionException('ارتباط اینترنت برقرار نشد.');
    } on TlsException {
      throw const SubscriptionException('گواهی امنیتی لینک اشتراک معتبر نیست.');
    } on FormatException {
      throw const SubscriptionException('محتوای اشتراک قابل خواندن نیست.');
    } finally {
      client.close(force: true);
    }
  }

  SubscriptionUsage parseUsage(String? header) {
    if (header == null || header.trim().isEmpty) {
      return const SubscriptionUsage();
    }
    final Map<String, int> values = <String, int>{};
    for (final String item in header.split(';')) {
      final List<String> pair = item.trim().split('=');
      if (pair.length == 2) {
        values[pair.first.trim().toLowerCase()] =
            int.tryParse(pair.last.trim()) ?? 0;
      }
    }
    return SubscriptionUsage(
      upload: values['upload'] ?? 0,
      download: values['download'] ?? 0,
      total: values['total'] ?? 0,
      expiryUnix: values['expire'] ?? 0,
    );
  }
}
