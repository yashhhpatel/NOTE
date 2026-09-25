/// Static app metadata and configurable external links.
///
/// The privacy/terms URLs are placeholders to be pointed at real hosted pages
/// before release. Nothing here is a secret.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Noteflow';
  static const String packageId = 'com.noteflow.app';

  /// Contact email shown under "Contact Us".
  static const String contactEmail = 'aakashmangukiya10@gmail.com';
  static const String contactName = 'Aakash Mangukiya';

  /// Configure these before release (host your own pages).
  static const String privacyPolicyUrl =
      'https://api.buildprivacypolicy.com/policy/87a533cd-9e4a-4938-bd90-15c582734a7f';
  static const String termsUrl = 'https://noteflow.app/terms';

  /// Play Store listing (used by Rate / Share).
  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$packageId';
  static String get marketUri => 'market://details?id=$packageId';
}
