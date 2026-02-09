/// Matches NOTAMs to procedure plates by analyzing NOTAM type, runway
/// references, navaid/lighting mentions, and procedure name keywords.
class NotamProcedureMatcher {
  static final _rwyRegex =
      RegExp(r'RWY\s+(\d{1,2}[LRC]?)', caseSensitive: false);

  /// Navaid keywords — matched with word boundaries to avoid false positives
  /// like "LOC" inside "LOCATION" or "GS" inside random text.
  static final _navaidPatterns = [
    'ILS', 'LOCALIZER', 'GLIDESLOPE', 'GLIDE SLOPE',
    'DME', 'VOR', 'VORTAC', 'NDB', 'RNAV', 'WAAS', 'LPV',
  ].map((kw) => RegExp('\\b$kw\\b', caseSensitive: false)).toList();

  /// Separate patterns for short keywords that need careful boundaries
  static final _locPattern = RegExp(r'\bLOC\b', caseSensitive: false);
  static final _gsPattern = RegExp(r'\bGS\b', caseSensitive: false);
  static final _gpsPattern = RegExp(r'\bGPS\b', caseSensitive: false);
  static final _lnavPattern = RegExp(r'\bLNAV\b', caseSensitive: false);
  static final _vnavPattern = RegExp(r'\bVNAV\b', caseSensitive: false);

  /// Lighting keywords — word-boundary matched
  static final _lightingPatterns = [
    'MALSR', 'MALSF', 'ALSF', 'SSALR', 'SSALF', 'ODALS',
    'REIL', 'PAPI', 'VASI', 'VGSI', 'TDZ',
    'HIRL', 'MIRL', 'LIRL', 'RCLS',
  ].map((kw) => RegExp('\\b$kw\\b', caseSensitive: false)).toList();

  /// NOTAM types that indicate a specific procedure category. When a NOTAM
  /// has one of these types, it should only match its own category — not bleed
  /// into other categories via navaid/lighting heuristics.
  static const _procedureTypes = {'IAP', 'SID', 'DP', 'STAR', 'ODP'};

  /// Returns the subset of [notams] that are relevant to the given procedure.
  static List<Map<String, dynamic>> match({
    required String chartName,
    required String chartCode,
    required List<dynamic> notams,
  }) {
    final upperChart = chartName.toUpperCase();
    final procRunway = _extractRunway(upperChart);

    final matched = <Map<String, dynamic>>[];
    for (final raw in notams) {
      final notam = raw as Map<String, dynamic>;
      if (_isRelevant(
        notam: notam,
        chartName: upperChart,
        chartCode: chartCode,
        procRunway: procRunway,
      )) {
        matched.add(notam);
      }
    }
    return matched;
  }

  static String? _extractRunway(String text) {
    final m = _rwyRegex.firstMatch(text);
    return m?.group(1)?.toUpperCase();
  }

  static Set<String> _extractAllRunways(String text) {
    return _rwyRegex
        .allMatches(text)
        .map((m) => m.group(1)!.toUpperCase())
        .toSet();
  }

  static bool _anyPatternMatches(String text, List<RegExp> patterns) {
    for (final p in patterns) {
      if (p.hasMatch(text)) return true;
    }
    return false;
  }

  static bool _isRelevant({
    required Map<String, dynamic> notam,
    required String chartName,
    required String chartCode,
    required String? procRunway,
  }) {
    final text = ((notam['text'] as String?) ?? '').toUpperCase();
    final fullText = ((notam['fullText'] as String?) ?? '').toUpperCase();
    final type = ((notam['type'] as String?) ?? '').toUpperCase();
    final classification =
        ((notam['classification'] as String?) ?? '').toUpperCase();
    final searchText = '$text\n$fullText';
    final notamRunways = _extractAllRunways(searchText);

    bool sharesRunway() =>
        procRunway != null && notamRunways.contains(procRunway);

    bool isGenericNotam() => notamRunways.isEmpty;

    // ── 1. NOTAM type directly matches procedure category ──

    // IAP-typed NOTAMs → approach plates
    if (type == 'IAP' && chartCode == 'IAP') {
      return sharesRunway() || isGenericNotam();
    }

    // SID / DP / ODP-typed NOTAMs → departure plates
    if ((type == 'SID' || type == 'DP' || type == 'ODP') && chartCode == 'DP') {
      return sharesRunway() || isGenericNotam() || _nameMatch(chartName, searchText);
    }

    // STAR-typed NOTAMs → arrival plates
    if (type == 'STAR' && chartCode == 'STAR') {
      return sharesRunway() || isGenericNotam() || _nameMatch(chartName, searchText);
    }

    // If this NOTAM has a procedure-specific type but it didn't match above,
    // it belongs to a different procedure category. Don't let it bleed through
    // via the heuristic strategies below.
    if (_procedureTypes.contains(type) && chartCode != 'APD') {
      // Exception: IAP-typed NOTAM can still match via runway for same runway
      // procedures in other categories — but only through name match.
      return _nameMatch(chartName, searchText);
    }

    // ── 2. Runway NOTAMs affect any procedure using that runway ──
    if (type == 'RWY' && sharesRunway()) return true;

    // ── 3. Classification-based matching ──
    if (classification.contains('INSTRUMENT APPROACH') && chartCode == 'IAP') {
      return sharesRunway() || isGenericNotam();
    }
    if (classification.contains('DEPARTURE') && chartCode == 'DP') {
      return sharesRunway() || isGenericNotam() || _nameMatch(chartName, searchText);
    }
    if (classification.contains('ARRIVAL') && chartCode == 'STAR') {
      return sharesRunway() || isGenericNotam() || _nameMatch(chartName, searchText);
    }

    // ── 4. Navaid NOTAMs for approach plates ──
    if (chartCode == 'IAP' && sharesRunway()) {
      if (_navaidMatchesChart(chartName, searchText)) return true;
    }

    // ── 5. Lighting NOTAMs for approach plates ──
    if (chartCode == 'IAP' &&
        sharesRunway() &&
        _anyPatternMatches(searchText, _lightingPatterns)) {
      return true;
    }

    // ── 6. Airport diagram: surface NOTAMs ──
    if (chartCode == 'APD') {
      if (const {'RWY', 'TWY', 'AD', 'APRON', 'CONSTRUCTION'}.contains(type)) {
        return true;
      }
      if (classification.contains('RUNWAY') ||
          classification.contains('TAXIWAY') ||
          classification.contains('APRON') ||
          classification.contains('AERODROME') ||
          classification.contains('AIRPORT')) {
        return true;
      }
    }

    // ── 7. Direct procedure name mention in NOTAM text ──
    if (_nameMatch(chartName, searchText)) return true;

    // ── 8. OBSTACLE NOTAMs for departure plates with matching runway ──
    if (chartCode == 'DP' &&
        (type == 'OBST' || classification.contains('OBSTACLE')) &&
        sharesRunway()) {
      return true;
    }

    return false;
  }

  /// Checks if a NOTAM's navaid mentions are relevant to the chart type.
  /// Uses word-boundary matching to avoid false positives.
  static bool _navaidMatchesChart(String chartName, String notamText) {
    // ILS/LOC/GS NOTAMs → ILS/LOC charts
    final isIlsLocChart =
        chartName.contains('ILS') || _locPattern.hasMatch(chartName);
    if (isIlsLocChart) {
      if (notamText.contains('ILS') ||
          _locPattern.hasMatch(notamText) ||
          notamText.contains('LOCALIZER') ||
          _gsPattern.hasMatch(notamText) ||
          notamText.contains('GLIDESLOPE') ||
          notamText.contains('GLIDE SLOPE')) {
        return true;
      }
    }
    // VOR NOTAMs → VOR charts
    if (chartName.contains('VOR') &&
        (notamText.contains('VOR') || notamText.contains('VORTAC'))) {
      return true;
    }
    // NDB NOTAMs → NDB charts
    if (chartName.contains('NDB') && notamText.contains('NDB')) return true;
    // GPS/RNAV/WAAS NOTAMs → RNAV/GPS charts
    final isRnavChart =
        chartName.contains('RNAV') || _gpsPattern.hasMatch(chartName);
    if (isRnavChart) {
      if (_gpsPattern.hasMatch(notamText) ||
          notamText.contains('RNAV') ||
          notamText.contains('WAAS') ||
          _lnavPattern.hasMatch(notamText) ||
          _vnavPattern.hasMatch(notamText) ||
          notamText.contains('LPV')) {
        return true;
      }
    }
    // DME NOTAMs → charts that use DME
    if (chartName.contains('DME') && notamText.contains('DME')) return true;
    return false;
  }

  /// Checks if the procedure name appears in the NOTAM text.
  static bool _nameMatch(String chartName, String notamText) {
    if (notamText.contains(chartName)) return true;

    // Strip "RWY XX" suffix for approaches and check the type prefix
    // e.g., "ILS OR LOC RWY 35R" → check "ILS OR LOC RWY 35R" already done,
    // but also try full name like "RNAV (GPS) Y RWY 35R"
    final rwyIdx = chartName.indexOf(' RWY');
    if (rwyIdx > 0) {
      final prefix = chartName.substring(0, rwyIdx).trim();
      // Only match if prefix is specific enough (e.g., "RNAV (GPS) Y" not "ILS")
      if (prefix.length >= 8 && notamText.contains(prefix)) return true;
    }

    // For SIDs/STARs: match names like "ZIMMR THREE", "DENVER TWO"
    // Strip common suffixes and continuation markers
    final cleaned = chartName
        .replaceAll(RegExp(r',\s*CONT\.\d+$'), '')
        .replaceAll(RegExp(r'\s+\(RNAV\)$'), '')
        .replaceAll(RegExp(r'\s+(DEPARTURE|ARRIVAL|TRANSITION)$'), '')
        .trim();
    if (cleaned.length >= 6 && cleaned != chartName && notamText.contains(cleaned)) {
      return true;
    }

    return false;
  }
}
