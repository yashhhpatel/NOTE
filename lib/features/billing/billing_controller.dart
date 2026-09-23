import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/monetization_config.dart';
import '../../core/providers.dart';
import '../../data/repositories/settings_repository.dart';

/// Immutable billing UI state.
@immutable
class BillingState {
  const BillingState({
    this.available = false,
    this.product,
    this.isPremium = false,
    this.purchasePending = false,
    this.message,
  });

  /// Whether the store (Play Billing) is available on this device.
  final bool available;

  /// The "Remove Ads" product details from the store, if loaded.
  final ProductDetails? product;

  /// Whether the lifetime remove-ads entitlement is active.
  final bool isPremium;

  /// A purchase/restore is in flight.
  final bool purchasePending;

  /// A user-facing message from the last operation.
  final String? message;

  /// Localized price from the store, or the configured fallback.
  String get price =>
      product?.price ?? MonetizationConfig.removeAdsFallbackPrice;

  BillingState copyWith({
    bool? available,
    ProductDetails? product,
    bool? isPremium,
    bool? purchasePending,
    String? message,
  }) {
    return BillingState(
      available: available ?? this.available,
      product: product ?? this.product,
      isPremium: isPremium ?? this.isPremium,
      purchasePending: purchasePending ?? this.purchasePending,
      message: message,
    );
  }
}

/// Drives Google Play Billing for the one-time "Lifetime Remove Ads" product.
///
/// Handles product loading, purchase, restore, pending/cancelled/failed/
/// already-owned states, and persists the entitlement locally so ads stay off
/// even before billing re-connects.
class BillingController extends AsyncNotifier<BillingState> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  Future<BillingState> build() async {
    // Start from the locally persisted entitlement so the UI/ads reflect it
    // immediately, independent of store connectivity.
    final persistedPremium =
        (await _settings.get(SettingsRepository.kPremium)) == 'true';

    ref.onDispose(() => _sub?.cancel());

    final available = await _iap.isAvailable();
    if (!available) {
      return BillingState(available: false, isPremium: persistedPremium);
    }

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        state = AsyncData(_current.copyWith(message: 'Store error: $e'));
      },
    );

    ProductDetails? product;
    final response = await _iap
        .queryProductDetails({MonetizationConfig.removeAdsProductId});
    if (response.productDetails.isNotEmpty) {
      product = response.productDetails.first;
    }

    return BillingState(
      available: true,
      product: product,
      isPremium: persistedPremium,
    );
  }

  BillingState get _current =>
      state.value ?? const BillingState();

  /// Starts the purchase flow for the lifetime remove-ads product.
  Future<void> buy() async {
    final product = _current.product;
    if (product == null) {
      state = AsyncData(_current.copyWith(
          message: 'Product not available. Try again later.'));
      return;
    }
    state = AsyncData(_current.copyWith(purchasePending: true, message: null));
    try {
      final param = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      state = AsyncData(_current.copyWith(
          purchasePending: false, message: 'Could not start purchase: $e'));
    }
  }

  /// Restores a previously-purchased entitlement.
  Future<void> restore() async {
    state = AsyncData(_current.copyWith(purchasePending: true, message: null));
    try {
      await _iap.restorePurchases();
      // Results arrive via the purchase stream; give it a beat, then if still
      // not premium, report nothing found.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_current.isPremium) {
        state = AsyncData(_current.copyWith(
            purchasePending: false, message: 'No active purchase found.'));
      } else {
        state = AsyncData(_current.copyWith(purchasePending: false));
      }
    } catch (e) {
      state = AsyncData(_current.copyWith(
          purchasePending: false, message: 'Restore failed: $e'));
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != MonetizationConfig.removeAdsProductId) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = AsyncData(_current.copyWith(
              purchasePending: true, message: 'Purchase pending…'));
        case PurchaseStatus.canceled:
          state = AsyncData(_current.copyWith(
              purchasePending: false, message: 'Purchase cancelled.'));
        case PurchaseStatus.error:
          state = AsyncData(_current.copyWith(
              purchasePending: false,
              message: purchase.error?.message ?? 'Purchase failed.'));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantPremium();
          state = AsyncData(_current.copyWith(
            isPremium: true,
            purchasePending: false,
            message: purchase.status == PurchaseStatus.restored
                ? 'Purchase restored.'
                : 'Thank you! Ads removed.',
          ));
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _grantPremium() async {
    await _settings.set(SettingsRepository.kPremium, 'true');
  }
}

final billingControllerProvider =
    AsyncNotifierProvider<BillingController, BillingState>(
  BillingController.new,
);

/// Convenience: whether ads should be hidden. True while entitlement is active;
/// defaults to false (ads on) until billing state loads.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(billingControllerProvider).maybeWhen(
        data: (s) => s.isPremium,
        orElse: () => false,
      );
});
