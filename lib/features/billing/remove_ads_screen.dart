import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/utils/snackbars.dart';
import 'billing_controller.dart';

/// Purchase screen for the one-time "Lifetime Remove Ads" product. Wired to
/// the real Google Play Billing flow in [BillingController] (in_app_purchase):
/// buy/restore, pending/cancelled/failed/already-owned states, and a price
/// that falls back to the configured display price until the store connects.
class RemoveAdsScreen extends ConsumerWidget {
  const RemoveAdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(billingControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    // Surface any transient message from billing (purchase result, restore
    // result, errors) as a snackbar.
    ref.listen(billingControllerProvider, (prev, next) {
      final msg = next.valueOrNull?.message;
      if (msg != null && msg != prev?.valueOrNull?.message) {
        showInfoSnackBar(context, msg);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Remove Ads'),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Store unavailable: $e')),
        data: (s) {
          if (s.isPremium) return _PremiumActive(scheme: scheme);
          return _Offer(state: s, scheme: scheme);
        },
      ),
    );
  }
}

class _Offer extends ConsumerWidget {
  const _Offer({required this.state, required this.scheme});
  final BillingState state;
  final ColorScheme scheme;

  static const _benefits = [
    'No banner ads',
    'No interstitial ads',
    'Enjoy the app without interruptions',
    'One-time payment — no subscription, no recurring charges',
    'Ads-free access stays active permanently after purchase',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Center(
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary, width: 2.5),
            ),
            child: Icon(Icons.military_tech, size: 52, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Lifetime Ads-Free',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'One-time purchase • ${state.price}',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (final benefit in _benefits) _BenefitRow(text: benefit),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              shape: const StadiumBorder(),
            ),
            onPressed: (!state.available || state.purchasePending)
                ? null
                : () => ref.read(billingControllerProvider.notifier).buy(),
            child: state.purchasePending
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Purchase for ${state.price}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: state.purchasePending
                ? null
                : () => ref.read(billingControllerProvider.notifier).restore(),
            child: const Text('Restore purchases'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.available
              ? 'Live store price will appear here once the product is '
                  'configured in Google Play and the store is reachable. The '
                  'amount charged is always the Play Console price.'
              : 'The store is unavailable right now. The rest of the app '
                  'works normally offline.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _PremiumActive extends StatelessWidget {
  const _PremiumActive({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Ads removed',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Thanks for your support! You have the lifetime ad-free version.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
