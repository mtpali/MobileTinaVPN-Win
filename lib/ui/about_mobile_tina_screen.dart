import 'dart:async';

import 'package:flutter/material.dart';

import '../services/windows_platform_service.dart';

class AboutMobileTinaScreen extends StatelessWidget {
  const AboutMobileTinaScreen({required this.platform, super.key});

  final WindowsPlatformService platform;

  static const List<_SocialLink> _socialLinks = <_SocialLink>[
    _SocialLink(
      title: 'اینستاگرام شعبه اول : کتالم',
      url: 'https://www.instagram.com/mobile.tina/',
      color: Color(0xffe4405f),
    ),
    _SocialLink(
      title: 'اینستاگرام شعبه دوم : رامسر',
      url: 'https://www.instagram.com/mobile.tina2/',
      color: Color(0xffe4405f),
    ),
    _SocialLink(
      title: 'اینستاگرام سوم',
      url: 'https://www.instagram.com/mobile.tinaa/',
      color: Color(0xffe4405f),
    ),
    _SocialLink(
      title: 'توسعه دهنده برنامه',
      url: 'https://t.me/vpn963',
      color: Color(0xff229ed9),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff111315),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: <Widget>[
          const Text(
            'درباره ما',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'ما را در شبکه‌های اجتماعی دنبال کنید',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xffb8bcc2), fontSize: 14),
          ),
          const SizedBox(height: 22),
          ..._socialLinks.map(
            (_SocialLink item) => Padding(
              padding: EdgeInsets.only(
                bottom: item == _socialLinks.last ? 24 : 12,
              ),
              child: _SocialCard(
                item: item,
                onTap: () => unawaited(_openLink(context, item.url)),
              ),
            ),
          ),
          const Text(
            'آدرس فروشگاه',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const _AddressCard(
            text: 'شعبه اول : کتالم ، جنب دبستان شهید بهشتی',
          ),
          const SizedBox(height: 12),
          const _AddressCard(
            text: 'شعبه دوم : رامسر ، ابریشم محله ، جنب بانک رفاه',
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    try {
      await platform.openUrl(url);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('باز کردن لینک امکان‌پذیر نبود.')),
      );
    }
  }
}

class _SocialCard extends StatelessWidget {
  const _SocialCard({required this.item, required this.onTap});

  final _SocialLink item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff171a1e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xff333840)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 70,
          child: Row(
            children: <Widget>[
              Container(
                width: 5,
                height: double.infinity,
                color: item.color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 18,
                    end: 16,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xff171a1e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff333840)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xffd9dde2),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLink {
  const _SocialLink({
    required this.title,
    required this.url,
    required this.color,
  });

  final String title;
  final String url;
  final Color color;
}
