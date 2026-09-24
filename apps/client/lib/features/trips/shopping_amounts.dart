/// Display formatting for shopping item amounts. Stored values stay exact on
/// the server; doubles here are for presentation only.
library;

class DemandAmount {
  const DemandAmount({
    required this.dimension,
    required this.unit,
    required this.min,
    required this.max,
  });

  final String dimension;
  final String unit;
  final double min;
  final double max;
}

class ShoppingEstimateView {
  const ShoppingEstimateView({
    required this.amount,
    required this.unit,
    required this.buyCount,
    required this.buySize,
    required this.crossesDimension,
    required this.remainderApplied,
  });

  final double amount;
  final String unit;
  final int? buyCount;
  final double? buySize;
  final bool crossesDimension;

  /// True when an exact amount already at home was subtracted on the server.
  final bool remainderApplied;
}

double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}');

List<DemandAmount> demandFrom(Map<String, Object?> item) {
  final raw = item['demand'];
  if (raw is! List) return const [];
  return [
    for (final entry in raw.whereType<Map>())
      if (_number(entry['min']) case final min?)
        if (_number(entry['max']) case final max?)
          DemandAmount(
            dimension: '${entry['dimension'] ?? 'COUNT'}',
            unit: '${entry['unit'] ?? 'piece'}',
            min: min,
            max: max,
          ),
  ];
}

ShoppingEstimateView? estimateFrom(Map<String, Object?> item) {
  final raw = item['estimate'];
  if (raw is! Map) return null;
  final amount = _number(raw['amount']);
  final unit = raw['unit'];
  if (amount == null || unit is! String) return null;
  final buy = raw['buy'];
  return ShoppingEstimateView(
    amount: amount,
    unit: unit,
    buyCount: buy is Map ? _number(buy['count'])?.round() : null,
    buySize: buy is Map ? _number(buy['size']) : null,
    crossesDimension: raw['crossesDimension'] == true,
    remainderApplied: raw['remainderApplied'] == true,
  );
}

String _trim(double value, int decimals) {
  final fixed = value.toStringAsFixed(decimals);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}

String _pluralUnit(String unit, double amount) {
  if (amount == 1 || unit.endsWith('s')) return unit;
  if (RegExp(r'(ch|sh|x)$').hasMatch(unit)) return '${unit}es';
  return '${unit}s';
}

({double factor, String unit, int decimals}) _scale(double max, String unit) {
  if (unit == 'g' && max >= 1000) {
    return (factor: 1000, unit: 'kg', decimals: 2);
  }
  if (unit == 'ml' && max >= 1000) {
    return (factor: 1000, unit: 'L', decimals: 2);
  }
  return (factor: 1, unit: unit, decimals: 1);
}

String formatAmount(double amount, String unit) =>
    formatRange(amount, amount, unit);

String formatRange(double min, double max, String unit) {
  final scale = _scale(max, unit);
  final low = _trim(min / scale.factor, scale.decimals);
  final high = _trim(max / scale.factor, scale.decimals);
  final metric = unit == 'g' || unit == 'ml';
  final label = metric ? scale.unit : _pluralUnit(scale.unit, max);
  return low == high ? '$high $label' : '$low–$high $label';
}

/// Size bands apply only to grams and millilitres; count units keep one
/// decimal so "12 pieces" never becomes "10 pieces".
double roundEstimate(double amount, String unit) {
  if (amount < 10 || (unit != 'g' && unit != 'ml')) {
    return (amount * 10).round() / 10;
  }
  if (amount < 100) return (amount / 5).round() * 5;
  if (amount < 1000) return (amount / 10).round() * 10;
  return (amount / 50).round() * 50;
}

String exactSummary(List<DemandAmount> demand, {required bool unmeasured}) {
  if (demand.isEmpty) return unmeasured ? 'Some to taste' : '';
  final amounts = demand.map(
    (entry) => formatRange(entry.min, entry.max, entry.unit),
  );
  return [...amounts, if (unmeasured) 'some to taste'].join(' + ');
}

String estimateSummary(
  ShoppingEstimateView estimate, {
  required String status,
}) {
  final prefix = status == 'PARTIALLY_AVAILABLE' && estimate.remainderApplied
      ? 'Still need ≈ '
      : '≈ ';
  final rounded = roundEstimate(estimate.amount, estimate.unit);
  final amount = '$prefix${formatAmount(rounded, estimate.unit)}';
  final count = estimate.buyCount;
  final size = estimate.buySize;
  if (count == null || size == null) return amount;
  return '$amount · buy $count × ${formatAmount(size, estimate.unit)}';
}

String shoppingItemSummary(Map<String, Object?> item) {
  final manualAmount = _number(item['manualQuantity']);
  final manualUnit = item['manualUnit'];
  if (manualAmount != null && manualUnit is String && manualUnit.isNotEmpty) {
    return formatAmount(manualAmount, manualUnit);
  }
  if (manualAmount != null) return _trim(manualAmount, 2);
  final estimate = estimateFrom(item);
  if (estimate != null) {
    return estimateSummary(estimate, status: '${item['status'] ?? ''}');
  }
  return exactSummary(demandFrom(item), unmeasured: item['unmeasured'] == true);
}

String contributionAmount(Map<Object?, Object?> contribution) {
  final min = _number(contribution['quantityMin']);
  if (min == null) return 'To taste';
  final max = _number(contribution['quantityMax']) ?? min;
  final unit = contribution['unit'];
  final low = _trim(min, 3);
  final high = _trim(max, 3);
  final amount = low == high ? high : '$low–$high';
  return unit is String && unit.trim().isNotEmpty
      ? '$amount ${unit.trim()}'
      : amount;
}

String? crossDimensionNote(ShoppingEstimateView estimate, String displayName) {
  if (!estimate.crossesDimension) return null;
  final kind = switch (estimate.unit) {
    'g' => 'weight',
    'ml' => 'volume',
    _ => 'size',
  };
  return 'Estimate uses a typical $kind for ${displayName.toLowerCase()}, so check the pack.';
}
