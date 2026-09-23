import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../shared/utils/snackbars.dart';

/// About screen: version, legal links, contact, rate and share.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('About'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(Icons.edit_note,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(AppConfig.appName,
                    style: Theme.of(context).textTheme.titleLarge),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final v = snapshot.data;
                    return Text(
                      v == null ? '' : 'Version ${v.version} (${v.buildNumber})',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _openUrl(context, AppConfig.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Use'),
            onTap: () => _openUrl(context, AppConfig.termsUrl),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact Us'),
            subtitle: const Text(AppConfig.contactEmail),
            onTap: () => _contact(context),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate App'),
            onTap: () => _rate(context),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share App'),
            onTap: () => Share.share(
              'Check out ${AppConfig.appName}, an offline notes app: '
              '${AppConfig.playStoreUrl}',
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Noteflow keeps your notes on your device. Note content is never '
              'uploaded to our servers. Third-party services used: Google AdMob '
              '(ads) and Google Play Billing (Remove Ads purchase).',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showInfoSnackBar(context, 'Could not open link.');
    }
  }

  Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.contactEmail,
      queryParameters: {'subject': '${AppConfig.appName} feedback'},
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        showInfoSnackBar(
            context, 'No email app found. Email ${AppConfig.contactEmail}');
      }
    } catch (_) {
      if (context.mounted) {
        showInfoSnackBar(
            context, 'No email app found. Email ${AppConfig.contactEmail}');
      }
    }
  }

  Future<void> _rate(BuildContext context) async {
    try {
      if (await launchUrl(Uri.parse(AppConfig.marketUri),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (context.mounted) await _openUrl(context, AppConfig.playStoreUrl);
  }
}
