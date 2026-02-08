class Procedure {
  final int id;
  final String airportIdentifier;
  final String chartCode;
  final String chartName;
  final String pdfName;
  final int chartSeq;
  final String? userAction;
  final String? faanfd18;
  final String? copter;
  final String cycle;
  final String? stateCode;
  final String? cityName;
  final String? volume;

  const Procedure({
    required this.id,
    required this.airportIdentifier,
    required this.chartCode,
    required this.chartName,
    required this.pdfName,
    this.chartSeq = 0,
    this.userAction,
    this.faanfd18,
    this.copter,
    required this.cycle,
    this.stateCode,
    this.cityName,
    this.volume,
  });

  factory Procedure.fromJson(Map<String, dynamic> json) {
    return Procedure(
      id: json['id'] as int,
      airportIdentifier: json['airport_identifier'] as String,
      chartCode: json['chart_code'] as String,
      chartName: json['chart_name'] as String,
      pdfName: json['pdf_name'] as String,
      chartSeq: (json['chart_seq'] as int?) ?? 0,
      userAction: json['user_action'] as String?,
      faanfd18: json['faanfd18'] as String?,
      copter: json['copter'] as String?,
      cycle: json['cycle'] as String,
      stateCode: json['state_code'] as String?,
      cityName: json['city_name'] as String?,
      volume: json['volume'] as String?,
    );
  }

  String get categoryLabel {
    switch (chartCode) {
      case 'APD':
        return 'Airport Diagram';
      case 'IAP':
        return 'Approach';
      case 'DP':
        return 'Departure';
      case 'STAR':
        return 'Arrival';
      case 'MIN':
        return 'Minimums';
      case 'HOT':
        return 'Hot Spot';
      case 'LAH':
        return 'LAHSO';
      default:
        return chartCode;
    }
  }

  bool get isGraphical {
    return chartCode == 'APD' ||
        chartCode == 'IAP' ||
        chartCode == 'DP' ||
        chartCode == 'STAR';
  }
}
