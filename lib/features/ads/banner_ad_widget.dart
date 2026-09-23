import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/services/ads_service.dart';
import '../billing/billing_controller.dart';

/// A bottom banner ad that renders only when the user is not premium and the
/// ad has loaded. Collapses to nothing otherwise, so it never covers content.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load() {
    if (_ad != null) return;
    final banner = BannerAd(
      adUnitId: AdsService.instance.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    );
    _ad = banner;
    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) return const SizedBox.shrink();

    // Kick off a load once we know the user is not premium.
    if (_ad == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (!_loaded || _ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
