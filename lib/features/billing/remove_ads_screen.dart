import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/utils/snackbars.dart';
import 'billing_controller.dart';

/// Polished purchase screen for the one-time "Lifetime Remove Ads" product.
class RemoveAdsScreen extends ConsumerWidget {
  const RemoveAdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(billingControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    // Surface any transient message from billing.
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
          if (s.isPremium) {
            return _PremiumActive(scheme: scheme);
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 8),
              Icon(Icons.workspace_premium, size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Lifetime ad-free experience',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'One purchase. No subscription.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              const _Benefit(text: 'Remove all banner ads'),
              const _Benefit(text: 'Remove all interstitial ads'),
              const _Benefit(text: 'One-time payment, yours forever'),
              const _Benefit(text: 'Support ongoing development'),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lifetime Remove Ads'),
                      Text(
                        s.price,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (!s.available || s.purchasePending)
                    ? null
                    : () => ref.read(billingControllerProvider.notifier).buy(),
                child: s.purchasePending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Buy for ${s.price}'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: s.purchasePending
                    ? null
                    : () =>
                        ref.read(billingControllerProvider.notifier).restore(),
                child: const Text('Restore purchases'),
              ),
              if (!s.available)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'The store is unavailable right now. The rest of the app '
                    'works normally offline.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Payment is processed by Google Play. This unlocks an ad-free '
                'experience on this account.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
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
