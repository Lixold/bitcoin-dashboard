import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/price_live_provider.dart';
import '../domain/price_tick.dart';

class PriceOverviewScreen extends ConsumerWidget {
  const PriceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final tickAsync = ref.watch(priceLiveProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(priceLiveProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            tickAsync.when(
              data: (tick) => _PriceCard(tick: tick),
              loading: () => _LoadingCard(text: l10n.priceLoading),
              error: (e, _) => _ErrorCard(
                message: l10n.priceError,
                retryLabel: l10n.priceRetry,
                onRetry: () => ref.invalidate(priceLiveProvider),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.priceSourceBinance,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends ConsumerWidget {
  const _PriceCard({required this.tick});

  final PriceTick tick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: r'$',
      decimalDigits: 2,
    );
    final time = DateFormat.Hms().format(tick.observedAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.priceLive, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              formatter.format(tick.price),
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.priceLastUpdated(time), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
