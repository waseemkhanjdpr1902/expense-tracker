import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../data/providers.dart';

const _name = 'Saran Zafar';
const _title = 'Software Engineer · Full-Stack';
const _tagline =
    'Builds production systems across healthcare, retail & e-commerce.';
const _bio =
    'Software engineer from AJK, Pakistan. Specializes in NestJS REST APIs, '
    'multi-tenant SaaS platforms, offline-first Electron desktop apps, and '
    'WordPress / WooCommerce solutions.';

const _repoUrl =
    'https://github.com/saranzafar/expense-tracker-flutter-mobile-app';
const _initials = 'SZ';

class _Link {
  final IconData icon;
  final String label;
  final String value;
  final String url;
  const _Link(this.icon, this.label, this.value, this.url);
}

const _links = <_Link>[
  _Link(Icons.code_rounded, 'GitHub', '@saranzafar',
      'https://github.com/saranzafar'),
  _Link(Icons.work_outline_rounded, 'LinkedIn', 'in/saranzafar',
      'https://www.linkedin.com/in/saranzafar'),
  _Link(Icons.camera_alt_rounded, 'Instagram', '@saran.devvv',
      'https://www.instagram.com/saran.devvv/'),
  _Link(Icons.public_rounded, 'Website', 'saranzafar.com', 'https://saranzafar.com'),
  _Link(Icons.mail_outline_rounded, 'Email', 'saran.development@gmail.com',
      'mailto:saran.development@gmail.com'),
];

Future<void> _open(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Couldn't open $url")),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FadeIn(delay: AppMotion.staggerDelay(0), child: _HeaderCard()),
            const SizedBox(height: 16),
            FadeIn(delay: AppMotion.staggerDelay(1), child: _BioCard()),
            const SizedBox(height: 16),
            FadeIn(
              delay: AppMotion.staggerDelay(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel('Connect'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: context.hairline),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _links.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: context.hairline),
                          _LinkTile(link: _links[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FadeIn(
              delay: AppMotion.staggerDelay(3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel('This app'),
                  const SizedBox(height: 8),
                  _RepoCard(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text('Made with ♥ in AJK, Pakistan',
                  style: AppTextStyles.caption
                      .copyWith(color: context.inkSubtle)),
            ),
            const SizedBox(height: 4),
            Consumer(
              builder: (context, ref, _) {
                final version = ref.watch(appVersionProvider).maybeWhen(
                      data: (v) => 'v$v',
                      orElse: () => '',
                    );
                if (version.isEmpty) return const SizedBox.shrink();
                return Center(
                  child: Text('Xpense Tracker · $version',
                      style: AppTextStyles.caption
                          .copyWith(color: context.inkSubtle)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text,
          style: AppTextStyles.caption.copyWith(color: context.inkMuted)),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: context.hairline),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: context.palette.accent, width: 1.5),
            ),
            child: Text(_initials,
                style: AppTextStyles.headline
                    .copyWith(color: context.ink, fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name,
                    style: AppTextStyles.headline.copyWith(color: context.ink)),
                const SizedBox(height: 2),
                Text(_title,
                    style: AppTextStyles.caption
                        .copyWith(color: context.inkMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.palette.accentSoft,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Open to collaboration',
                      style: AppTextStyles.caption.copyWith(
                          color: context.palette.onAccentSoft,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BioCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: context.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_tagline,
              style: AppTextStyles.body.copyWith(
                  color: context.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_bio,
              style: AppTextStyles.body
                  .copyWith(color: context.inkMuted, height: 1.5)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link});
  final _Link link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context, link.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: context.hairline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(link.icon, size: 18, color: context.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(link.label,
                      style: AppTextStyles.body.copyWith(
                          color: context.ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(link.value,
                      style: AppTextStyles.caption
                          .copyWith(color: context.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: context.inkSubtle),
          ],
        ),
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Matches the Home hero: a dark surface in both themes, with every
    // foreground derived from onHero rather than assuming white-on-black.
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.heroSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded, size: 18, color: context.palette.accent),
              const SizedBox(width: 6),
              Text('Source code',
                  style: AppTextStyles.caption.copyWith(
                      color: p.onHero.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'expense-tracker-flutter-mobile-app',
              style: AppTextStyles.title
                  .copyWith(color: p.onHero, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Open source · MIT-style',
              style: AppTextStyles.caption.copyWith(
                  color: p.onHero.withValues(alpha: 0.6))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: context.palette.accent,
                foregroundColor: context.palette.onAccent,
              ),
              icon: const Icon(Icons.code_rounded),
              label: const Text('View on GitHub'),
              onPressed: () => _open(context, _repoUrl),
            ),
          ),
        ],
      ),
    );
  }
}
