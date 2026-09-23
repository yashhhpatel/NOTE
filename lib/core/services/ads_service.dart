import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/monetization_config.dart';

/// Thin wrapper over AdMob for initialization and interstitial ads. Banners are
/// created per-widget. Ads never load when the user owns "Remove Ads" — callers
/// pass the premium flag and this class no-ops accordingly.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  bool _initialised = false;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  int _transitionCount = 0;

  /// Only every Nth natural transition shows an interstitial, so ads never
  /// appear after every action.
  static const int _interstitialEveryN = 4;

  Future<void> init() async {
    if (_initialised) return;
    await MobileAds.instance.initialize();
    _initialised = true;
  }

  /// Preloads an interstitial so it is ready at the next natural transition.
  void loadInterstitial({required bool isPremium}) {
    if (isPremium || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: MonetizationConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  /// Shows the interstitial if one is ready and the user is not premium, then
  /// preloads the next. Safe to call frequently; it self-throttles by only
  /// showing when an ad happens to be loaded.
  void showInterstitialIfReady({required bool isPremium}) {
    if (isPremium) return;
    final ad = _interstitial;
    if (ad == null) {
      loadInterstitial(isPremium: isPremium);
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        loadInterstitial(isPremium: isPremium);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitial = null;
        loadInterstitial(isPremium: isPremium);
      },
    );
    ad.show();
    _interstitial = null;
  }

  /// Called at natural transitions (e.g. closing an editor). Shows an
  /// interstitial only on every Nth call, and only when not premium.
  void maybeShowOnTransition({required bool isPremium}) {
    if (isPremium) return;
    _transitionCount++;
    if (_transitionCount % _interstitialEveryN == 0) {
      showInterstitialIfReady(isPremium: isPremium);
    } else {
      loadInterstitial(isPremium: isPremium);
    }
  }

  String get bannerUnitId => MonetizationConfig.bannerAdUnitId;
}

