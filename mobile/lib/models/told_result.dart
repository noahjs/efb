class ToldResult {
  final double? vrKias;
  final double? v50Kias;
  final double? groundRollFt;
  final double? totalDistanceFt;
  final double weight;
  final double pressureAltitude;
  final double? maxWeight;
  final String? weightLimitType;
  final bool isOverweight;
  final bool exceedsRunway;
  final DateTime calculatedAt;
  final String? metarRaw;

  const ToldResult({
    this.vrKias,
    this.v50Kias,
    this.groundRollFt,
    this.totalDistanceFt,
    required this.weight,
    required this.pressureAltitude,
    this.maxWeight,
    this.weightLimitType,
    this.isOverweight = false,
    this.exceedsRunway = false,
    required this.calculatedAt,
    this.metarRaw,
  });
}
