import 'dart:io';

/// Central, non-secret configuration for ads and billing.
///
/// The values below are Google's official **test** identifiers so the app is
/// fully functional in development without a Play/AdMob account. Before a
/// production release, replace them with your real IDs:
///  - AdMob app id in `android/app/src/main/AndroidManifest.xml`
///  - the ad unit ids below
///  - the Play product id below (create the in-app product in Play Console)
///
/// None of these are secrets (ad unit ids and product ids are public), so this
/// file is safe to commit. Keystores and API keys stay out of source control.
class MonetizationConfig {
  const MonetizationConfig._();

  /// When true, AdMob is put in test-device mode and only test ads load.
  /// Set to false once real ad unit ids are configured for release.
  static const bool useTestAds = true;

  /// Google's sample banner ad unit (Android). Replace for production.
  static String get bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  /// Google's sample interstitial ad unit (Android). Replace for production.
  static String get interstitialAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  /// Play Console in-app product id for the lifetime "Remove Ads" purchase.
  /// Must match the product id you create in the Play Console.
  static const String removeAdsProductId = 'noteflow_remove_ads_lifetime';

  /// Display price shown as a fallback before Play returns the localized price.
  static const String removeAdsFallbackPrice = '₹2,999';

  /// Test device IDs for forcing the UMP (consent) debug geography — e.g. to
  /// test the EEA consent form on a device/emulator that isn't actually in
  /// the EEA. Find your device's id in logcat ("Use new
  /// ConsentDebugSettings.Builder().addTestDeviceHashedId(...)"). Leave empty
  /// for production; only used when [useTestAds] is true.
  static const List<String> consentTestDeviceIds = [];
}
