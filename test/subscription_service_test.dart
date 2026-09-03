import 'package:flutter_test/flutter_test.dart';
import 'package:mobiletina_vpn/models/subscription.dart';
import 'package:mobiletina_vpn/services/subscription_service.dart';

void main() {
  test('parses subscription-userinfo header', () {
    final SubscriptionUsage usage = SubscriptionService().parseUsage(
      'upload=1024; download=2048; total=8192; expire=2000000000',
    );

    expect(usage.upload, 1024);
    expect(usage.download, 2048);
    expect(usage.used, 3072);
    expect(usage.total, 8192);
    expect(usage.expiryUnix, 2000000000);
    expect(usage.fraction, closeTo(0.375, 0.001));
  });

  test('recognizes an expired subscription at the exact expiry second', () {
    const SubscriptionUsage usage = SubscriptionUsage(expiryUnix: 1000);

    expect(
      usage.isExpiredAt(
        DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
      ),
      isTrue,
    );
    expect(
      usage.isExpiredAt(
        DateTime.fromMillisecondsSinceEpoch(999 * 1000),
      ),
      isFalse,
    );
  });
}
