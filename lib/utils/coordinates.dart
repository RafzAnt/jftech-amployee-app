// Google coordinates of the place where a client was installed. People copy them from Google Maps ("9.6541, 124.1234" from the
// press-and-hold menu), or paste the address of the map page.

/// The Philippines: a swapped pair (longitude first) or a typing slip falls outside and is refused.
const _latitudeRange = (4.0, 22.0);
const _longitudeRange = (116.0, 128.0);

final _number = r'(-?\d{1,3}(?:\.\d+)?)';

/// [latitude, longitude] of what was typed or pasted, or null when it cannot be read or lies outside the Philippines.
({double latitude, double longitude})? parseCoordinates(String text) {
  final cleaned = Uri.decodeFull(text.trim());
  if (cleaned.isEmpty) return null;

  final patterns = [
    RegExp('!3d$_number!4d$_number'),
    RegExp('@$_number,$_number'),
    RegExp('[?&](?:q|query|ll|destination)=$_number[,+ ]\\s*$_number'),
    RegExp('^\\(?\\s*$_number\\s*[,;\\s]\\s*$_number\\s*\\)?\$'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(cleaned);
    if (match == null) continue;
    final latitude = double.parse(match.group(1)!);
    final longitude = double.parse(match.group(2)!);
    if (latitude < _latitudeRange.$1 || latitude > _latitudeRange.$2 || longitude < _longitudeRange.$1 || longitude > _longitudeRange.$2) {
      return null;
    }
    return (latitude: latitude, longitude: longitude);
  }
  return null;
}

/// A message for the person when the coordinates cannot be used, or null when they are fine.
String? coordinatesError(String text) {
  if (text.trim().isEmpty) return 'Enter the Google coordinates of the client, for example 9.6541, 124.1234.';
  if (parseCoordinates(text) == null) {
    return 'Could not read the coordinates. Copy them from Google Maps as latitude, longitude, for example 9.6541, 124.1234.';
  }
  return null;
}
