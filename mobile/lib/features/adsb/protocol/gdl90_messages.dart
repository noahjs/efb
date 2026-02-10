/// GDL 90 message ID constants.
///
/// Reference: FAA GDL 90 Data Interface Specification, Rev A.
class Gdl90MessageId {
  Gdl90MessageId._();

  static const int heartbeat = 0x00;
  static const int uatUplink = 0x07;
  static const int heightAboveTerrain = 0x09;
  static const int ownshipReport = 0x0A;
  static const int ownshipGeoAltitude = 0x0B;
  static const int trafficReport = 0x14;
  static const int foreflightExtended = 0x65;

  // Stratux non-standard extensions
  static const int stratuxAhrs = 0x4C;
  static const int stratuxHeartbeat = 0xCC;
}
