class LogbookEntry {
  final int? id;
  final String? date;
  final int? aircraftId;
  final String? aircraftIdentifier;
  final String? aircraftType;
  final String? fromAirport;
  final String? toAirport;
  final String? route;

  // Start & End
  final double? hobbsStart;
  final double? hobbsEnd;
  final double? tachStart;
  final double? tachEnd;
  final String? timeOut;
  final String? timeOff;
  final String? timeOn;
  final String? timeIn;

  // Times (decimal hours)
  final double totalTime;
  final double pic;
  final double sic;
  final double night;
  final double solo;
  final double crossCountry;
  final double? distance;
  final double actualInstrument;
  final double simulatedInstrument;

  // Takeoffs & Landings
  final int dayTakeoffs;
  final int nightTakeoffs;
  final int dayLandingsFullStop;
  final int nightLandingsFullStop;
  final int allLandings;

  // Instrument
  final int holds;
  final String? approaches;

  // Training
  final double dualGiven;
  final double dualReceived;
  final double simulatedFlight;
  final double groundTraining;

  // People & Remarks
  final String? instructorName;
  final String? instructorComments;
  final String? person1;
  final String? person2;
  final String? person3;
  final String? person4;
  final String? person5;
  final String? person6;
  final bool flightReview;
  final bool checkride;
  final bool ipc;
  final String? comments;

  // Metadata
  final String? createdAt;
  final String? updatedAt;

  const LogbookEntry({
    this.id,
    this.date,
    this.aircraftId,
    this.aircraftIdentifier,
    this.aircraftType,
    this.fromAirport,
    this.toAirport,
    this.route,
    this.hobbsStart,
    this.hobbsEnd,
    this.tachStart,
    this.tachEnd,
    this.timeOut,
    this.timeOff,
    this.timeOn,
    this.timeIn,
    this.totalTime = 0,
    this.pic = 0,
    this.sic = 0,
    this.night = 0,
    this.solo = 0,
    this.crossCountry = 0,
    this.distance,
    this.actualInstrument = 0,
    this.simulatedInstrument = 0,
    this.dayTakeoffs = 0,
    this.nightTakeoffs = 0,
    this.dayLandingsFullStop = 0,
    this.nightLandingsFullStop = 0,
    this.allLandings = 0,
    this.holds = 0,
    this.approaches,
    this.dualGiven = 0,
    this.dualReceived = 0,
    this.simulatedFlight = 0,
    this.groundTraining = 0,
    this.instructorName,
    this.instructorComments,
    this.person1,
    this.person2,
    this.person3,
    this.person4,
    this.person5,
    this.person6,
    this.flightReview = false,
    this.checkride = false,
    this.ipc = false,
    this.comments,
    this.createdAt,
    this.updatedAt,
  });

  factory LogbookEntry.fromJson(Map<String, dynamic> json) {
    return LogbookEntry(
      id: json['id'] as int?,
      date: json['date'] as String?,
      aircraftId: json['aircraft_id'] as int?,
      aircraftIdentifier: json['aircraft_identifier'] as String?,
      aircraftType: json['aircraft_type'] as String?,
      fromAirport: json['from_airport'] as String?,
      toAirport: json['to_airport'] as String?,
      route: json['route'] as String?,
      hobbsStart: (json['hobbs_start'] as num?)?.toDouble(),
      hobbsEnd: (json['hobbs_end'] as num?)?.toDouble(),
      tachStart: (json['tach_start'] as num?)?.toDouble(),
      tachEnd: (json['tach_end'] as num?)?.toDouble(),
      timeOut: json['time_out'] as String?,
      timeOff: json['time_off'] as String?,
      timeOn: json['time_on'] as String?,
      timeIn: json['time_in'] as String?,
      totalTime: (json['total_time'] as num?)?.toDouble() ?? 0,
      pic: (json['pic'] as num?)?.toDouble() ?? 0,
      sic: (json['sic'] as num?)?.toDouble() ?? 0,
      night: (json['night'] as num?)?.toDouble() ?? 0,
      solo: (json['solo'] as num?)?.toDouble() ?? 0,
      crossCountry: (json['cross_country'] as num?)?.toDouble() ?? 0,
      distance: (json['distance'] as num?)?.toDouble(),
      actualInstrument: (json['actual_instrument'] as num?)?.toDouble() ?? 0,
      simulatedInstrument:
          (json['simulated_instrument'] as num?)?.toDouble() ?? 0,
      dayTakeoffs: (json['day_takeoffs'] as int?) ?? 0,
      nightTakeoffs: (json['night_takeoffs'] as int?) ?? 0,
      dayLandingsFullStop: (json['day_landings_full_stop'] as int?) ?? 0,
      nightLandingsFullStop: (json['night_landings_full_stop'] as int?) ?? 0,
      allLandings: (json['all_landings'] as int?) ?? 0,
      holds: (json['holds'] as int?) ?? 0,
      approaches: json['approaches'] as String?,
      dualGiven: (json['dual_given'] as num?)?.toDouble() ?? 0,
      dualReceived: (json['dual_received'] as num?)?.toDouble() ?? 0,
      simulatedFlight: (json['simulated_flight'] as num?)?.toDouble() ?? 0,
      groundTraining: (json['ground_training'] as num?)?.toDouble() ?? 0,
      instructorName: json['instructor_name'] as String?,
      instructorComments: json['instructor_comments'] as String?,
      person1: json['person1'] as String?,
      person2: json['person2'] as String?,
      person3: json['person3'] as String?,
      person4: json['person4'] as String?,
      person5: json['person5'] as String?,
      person6: json['person6'] as String?,
      flightReview: (json['flight_review'] as bool?) ?? false,
      checkride: (json['checkride'] as bool?) ?? false,
      ipc: (json['ipc'] as bool?) ?? false,
      comments: json['comments'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'aircraft_id': aircraftId,
      'aircraft_identifier': aircraftIdentifier,
      'aircraft_type': aircraftType,
      'from_airport': fromAirport,
      'to_airport': toAirport,
      'route': route,
      'hobbs_start': hobbsStart,
      'hobbs_end': hobbsEnd,
      'tach_start': tachStart,
      'tach_end': tachEnd,
      'time_out': timeOut,
      'time_off': timeOff,
      'time_on': timeOn,
      'time_in': timeIn,
      'total_time': totalTime,
      'pic': pic,
      'sic': sic,
      'night': night,
      'solo': solo,
      'cross_country': crossCountry,
      'distance': distance,
      'actual_instrument': actualInstrument,
      'simulated_instrument': simulatedInstrument,
      'day_takeoffs': dayTakeoffs,
      'night_takeoffs': nightTakeoffs,
      'day_landings_full_stop': dayLandingsFullStop,
      'night_landings_full_stop': nightLandingsFullStop,
      'all_landings': allLandings,
      'holds': holds,
      'approaches': approaches,
      'dual_given': dualGiven,
      'dual_received': dualReceived,
      'simulated_flight': simulatedFlight,
      'ground_training': groundTraining,
      'instructor_name': instructorName,
      'instructor_comments': instructorComments,
      'person1': person1,
      'person2': person2,
      'person3': person3,
      'person4': person4,
      'person5': person5,
      'person6': person6,
      'flight_review': flightReview,
      'checkride': checkride,
      'ipc': ipc,
      'comments': comments,
    };
  }

  LogbookEntry copyWith({
    int? id,
    String? date,
    int? aircraftId,
    String? aircraftIdentifier,
    String? aircraftType,
    String? fromAirport,
    String? toAirport,
    String? route,
    double? hobbsStart,
    double? hobbsEnd,
    double? tachStart,
    double? tachEnd,
    String? timeOut,
    String? timeOff,
    String? timeOn,
    String? timeIn,
    double? totalTime,
    double? pic,
    double? sic,
    double? night,
    double? solo,
    double? crossCountry,
    double? distance,
    double? actualInstrument,
    double? simulatedInstrument,
    int? dayTakeoffs,
    int? nightTakeoffs,
    int? dayLandingsFullStop,
    int? nightLandingsFullStop,
    int? allLandings,
    int? holds,
    String? approaches,
    double? dualGiven,
    double? dualReceived,
    double? simulatedFlight,
    double? groundTraining,
    String? instructorName,
    String? instructorComments,
    String? person1,
    String? person2,
    String? person3,
    String? person4,
    String? person5,
    String? person6,
    bool? flightReview,
    bool? checkride,
    bool? ipc,
    String? comments,
    String? createdAt,
    String? updatedAt,
  }) {
    return LogbookEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      aircraftId: aircraftId ?? this.aircraftId,
      aircraftIdentifier: aircraftIdentifier ?? this.aircraftIdentifier,
      aircraftType: aircraftType ?? this.aircraftType,
      fromAirport: fromAirport ?? this.fromAirport,
      toAirport: toAirport ?? this.toAirport,
      route: route ?? this.route,
      hobbsStart: hobbsStart ?? this.hobbsStart,
      hobbsEnd: hobbsEnd ?? this.hobbsEnd,
      tachStart: tachStart ?? this.tachStart,
      tachEnd: tachEnd ?? this.tachEnd,
      timeOut: timeOut ?? this.timeOut,
      timeOff: timeOff ?? this.timeOff,
      timeOn: timeOn ?? this.timeOn,
      timeIn: timeIn ?? this.timeIn,
      totalTime: totalTime ?? this.totalTime,
      pic: pic ?? this.pic,
      sic: sic ?? this.sic,
      night: night ?? this.night,
      solo: solo ?? this.solo,
      crossCountry: crossCountry ?? this.crossCountry,
      distance: distance ?? this.distance,
      actualInstrument: actualInstrument ?? this.actualInstrument,
      simulatedInstrument: simulatedInstrument ?? this.simulatedInstrument,
      dayTakeoffs: dayTakeoffs ?? this.dayTakeoffs,
      nightTakeoffs: nightTakeoffs ?? this.nightTakeoffs,
      dayLandingsFullStop: dayLandingsFullStop ?? this.dayLandingsFullStop,
      nightLandingsFullStop:
          nightLandingsFullStop ?? this.nightLandingsFullStop,
      allLandings: allLandings ?? this.allLandings,
      holds: holds ?? this.holds,
      approaches: approaches ?? this.approaches,
      dualGiven: dualGiven ?? this.dualGiven,
      dualReceived: dualReceived ?? this.dualReceived,
      simulatedFlight: simulatedFlight ?? this.simulatedFlight,
      groundTraining: groundTraining ?? this.groundTraining,
      instructorName: instructorName ?? this.instructorName,
      instructorComments: instructorComments ?? this.instructorComments,
      person1: person1 ?? this.person1,
      person2: person2 ?? this.person2,
      person3: person3 ?? this.person3,
      person4: person4 ?? this.person4,
      person5: person5 ?? this.person5,
      person6: person6 ?? this.person6,
      flightReview: flightReview ?? this.flightReview,
      checkride: checkride ?? this.checkride,
      ipc: ipc ?? this.ipc,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
