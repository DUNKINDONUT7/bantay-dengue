/// Local, opaque check-in token for an appointment QR code.
///
/// The token is just the appointment's UUID behind a fixed prefix — it
/// carries no patient name, contact info, or other personal data (RLS on
/// `appointments` already gates who can resolve an id into anything useful),
/// and needs no server round trip or signing secret to generate or read.
const String _prefix = 'bantaydengue:appointment:';

String encodeAppointmentCheckIn(String appointmentId) =>
    '$_prefix$appointmentId';

/// Returns the appointment id if [raw] is a recognized check-in code,
/// otherwise null (e.g. someone scanned an unrelated QR code).
String? decodeAppointmentCheckIn(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.startsWith(_prefix)) return null;
  final id = trimmed.substring(_prefix.length).trim();
  return id.isEmpty ? null : id;
}
