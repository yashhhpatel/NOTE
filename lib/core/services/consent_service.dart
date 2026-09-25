import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/monetization_config.dart';
import 'ads_service.dart';

/// Runs Google's User Messaging Platform (UMP) consent flow before the Mobile
/// Ads SDK is initialised, as required for GDPR/EEA + UK compliance when
/// showing personalized ads.
///
/// Everything here is designed to never block app startup or hang the UI:
/// - It must only be called after `runApp()` (fire-and-forget), never awaited
///   on the startup path.
/// - Every network/platform callback has a fallback path that still ends by
///   calling [AdsService.instance.init], so a UMP failure never leaves ads
///   permanently uninitialised.
/// - A hard timeout guarantees the flow completes even if a platform callback
///   is never invoked (defensive — the ANR investigated earlier showed a
///   different Play Services subsystem stalling in this same problem space).
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  static const _timeout = Duration(seconds: 10);

  /// Requests/shows the consent form if required, then initialises AdMob once
  /// consent is resolved (or determined unnecessary, or on any failure/
  /// timeout — ads still work for users where consent isn't required).
  Future<void> requestConsentAndInitAds() async {
    final completer = Completer<void>();
    final timeoutTimer = Timer(_timeout, () {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      final debugSettings = MonetizationConfig.useTestAds &&
              MonetizationConfig.consentTestDeviceIds.isNotEmpty
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              testIdentifiers: MonetizationConfig.consentTestDeviceIds,
            )
          : null;

      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          tagForUnderAgeOfConsent: false,
          consentDebugSettings: debugSettings,
        ),
        () => _loadAndShowFormIfRequired(completer),
        (FormError error) {
          // Non-fatal: proceed without a form (e.g. no network). AdMob's own
          // defaults apply; the app never depends on ads to function.
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future;
    timeoutTimer.cancel();
    await _initAdsIfAllowed();
  }

  void _loadAndShowFormIfRequired(Completer<void> completer) {
    try {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
        // Called once resolved: either no form was required, or the user
        // just finished interacting with it. A non-null error is logged only
        // via the message here; we still proceed to (possibly) init ads.
        if (!completer.isCompleted) completer.complete();
      });
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _initAdsIfAllowed() async {
    try {
      final canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (canRequestAds) {
        await AdsService.instance.init();
      }
    } catch (_) {
      // Ads are non-critical; never let this affect the rest of the app.
    }
  }

  /// Whether the user must be shown a way to change their consent choice
  /// (e.g. a "Privacy options" / "Manage ad consent" item in Settings).
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Re-opens the consent/privacy-options form so the user can change their
  /// choice. Returns true if the form was shown and dismissed without error.
  Future<bool> showPrivacyOptionsForm() async {
    FormError? resultError;
    try {
      // This future completes only after the listener below has already run.
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        resultError = error;
      });
      return resultError == null;
    } catch (_) {
      return false;
    }
  }
}
