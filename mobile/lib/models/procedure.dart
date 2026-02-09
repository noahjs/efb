class GeorefData {
  final List<double> bbox; // [x1, y1, x2, y2] in PDF points
  final List<List<double>> gpts; // [[lat, lng], ...] ground points
  final List<List<double>> lpts; // [[x, y], ...] logical points
  final String? wkt;
  final double pageWidthPt;
  final double pageHeightPt;

  const GeorefData({
    required this.bbox,
    required this.gpts,
    required this.lpts,
    this.wkt,
    required this.pageWidthPt,
    required this.pageHeightPt,
  });

  factory GeorefData.fromJson(Map<String, dynamic> json) {
    return GeorefData(
      bbox: (json['bbox'] as List).map((e) => (e as num).toDouble()).toList(),
      gpts: (json['gpts'] as List)
          .map((p) =>
              (p as List).map((e) => (e as num).toDouble()).toList())
          .toList(),
      lpts: (json['lpts'] as List)
          .map((p) =>
              (p as List).map((e) => (e as num).toDouble()).toList())
          .toList(),
      wkt: json['wkt'] as String?,
      pageWidthPt: (json['pageWidthPt'] as num).toDouble(),
      pageHeightPt: (json['pageHeightPt'] as num).toDouble(),
    );
  }

  /// Computes the 4 corner coordinates [lng, lat] for Mapbox ImageSource.
  ///
  /// The rendered PNG is the full PDF page. The georef viewport (BBox) covers
  /// only a portion of the page. We need the geographic coordinates of the
  /// full page corners, so we extrapolate beyond the LPTS→GPTS mapping.
  ///
  /// Returns [[topLeftLng, topLeftLat], [topRightLng, topRightLat],
  ///          [bottomRightLng, bottomRightLat], [bottomLeftLng, bottomLeftLat]]
  List<List<double>> get cornerCoordinates {
    if (gpts.length < 4 || lpts.length < 4) return [];

    // Build an affine transform from LPTS→GPTS using least-squares.
    // An affine transform: lat = a*lx + b*ly + c, lng = d*lx + e*ly + f
    // With 4 points we're slightly over-determined, which is fine.

    // Use the first 3 points to compute exact affine coefficients,
    // which is sufficient for the near-linear LPTS→GPTS mapping.
    final l0 = lpts[0], l1 = lpts[1], l2 = lpts[2];
    final g0 = gpts[0], g1 = gpts[1], g2 = gpts[2]; // [lat, lng]

    // Solve: [g] = [l] * [coeffs]
    // | g0_lat |   | l0x  l0y  1 |   | a |
    // | g1_lat | = | l1x  l1y  1 | * | b |
    // | g2_lat |   | l2x  l2y  1 |   | c |
    final det = l0[0] * (l1[1] - l2[1]) -
        l0[1] * (l1[0] - l2[0]) +
        (l1[0] * l2[1] - l2[0] * l1[1]);

    if (det.abs() < 1e-15) return [];

    final invDet = 1.0 / det;

    // Inverse of 3x3 matrix for LPTS
    final i00 = (l1[1] - l2[1]) * invDet;
    final i01 = (l2[1] - l0[1]) * invDet;
    final i02 = (l0[1] - l1[1]) * invDet;
    final i10 = (l2[0] - l1[0]) * invDet;
    final i11 = (l0[0] - l2[0]) * invDet;
    final i12 = (l1[0] - l0[0]) * invDet;
    final i20 = (l1[0] * l2[1] - l2[0] * l1[1]) * invDet;
    final i21 = (l2[0] * l0[1] - l0[0] * l2[1]) * invDet;
    final i22 = (l0[0] * l1[1] - l1[0] * l0[1]) * invDet;

    // Affine coefficients for latitude: lat = a*lx + b*ly + c
    final a = i00 * g0[0] + i01 * g1[0] + i02 * g2[0];
    final b = i10 * g0[0] + i11 * g1[0] + i12 * g2[0];
    final c = i20 * g0[0] + i21 * g1[0] + i22 * g2[0];

    // Affine coefficients for longitude: lng = d*lx + e*ly + f
    final d = i00 * g0[1] + i01 * g1[1] + i02 * g2[1];
    final e = i10 * g0[1] + i11 * g1[1] + i12 * g2[1];
    final f = i20 * g0[1] + i21 * g1[1] + i22 * g2[1];

    // Convert PDF page corners to LPTS coordinates.
    // LPTS maps into the BBox rectangle on the page.
    // A point (px, py) in PDF space → LPTS via:
    //   lx = (px - bboxX1) / (bboxX2 - bboxX1)
    //   ly = (py - bboxY1) / (bboxY2 - bboxY1)
    // (PDF y=0 is at bottom of page)
    final bx1 = bbox[0], by1 = bbox[1], bx2 = bbox[2], by2 = bbox[3];
    final bw = bx2 - bx1;
    final bh = by2 - by1;
    if (bw.abs() < 1e-10 || bh.abs() < 1e-10) return [];

    // Full page corners in PDF coordinates:
    // Top-left:     (0, pageHeight)  — PDF y increases upward
    // Top-right:    (pageWidth, pageHeight)
    // Bottom-right: (pageWidth, 0)
    // Bottom-left:  (0, 0)
    List<double> pdfToGeo(double px, double py) {
      final lx = (px - bx1) / bw;
      final ly = (py - by1) / bh;
      final lat = a * lx + b * ly + c;
      final lng = d * lx + e * ly + f;
      return [lng, lat]; // Mapbox expects [lng, lat]
    }

    return [
      pdfToGeo(0, pageHeightPt),               // top-left
      pdfToGeo(pageWidthPt, pageHeightPt),      // top-right
      pdfToGeo(pageWidthPt, 0),                 // bottom-right
      pdfToGeo(0, 0),                           // bottom-left
    ];
  }
}

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
