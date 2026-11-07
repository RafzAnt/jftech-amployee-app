import 'package:flutter_test/flutter_test.dart';

import 'package:jftech/utils/coordinates.dart';

void main() {
  test('coordinates are read from what Google Maps gives', () {
    expect(parseCoordinates('9.6541, 124.1234'), (latitude: 9.6541, longitude: 124.1234));
    expect(parseCoordinates('  9.6541 124.1234 '), (latitude: 9.6541, longitude: 124.1234));
    expect(parseCoordinates('(9.6541, 124.1234)'), (latitude: 9.6541, longitude: 124.1234));
    expect(parseCoordinates('https://www.google.com/maps/place/Balilihan/@9.6541,124.1234,17z'), (latitude: 9.6541, longitude: 124.1234));
    expect(parseCoordinates('https://www.google.com/maps?q=9.6541,124.1234'), (latitude: 9.6541, longitude: 124.1234));
    expect(parseCoordinates('https://www.google.com/maps/place/x/data=!3d9.6541!4d124.1234'), (latitude: 9.6541, longitude: 124.1234));
  });

  test('anything else is refused, with a message for the person', () {
    for (final bad in ['', 'near the church', '9.6541', '124.1234, 9.6541', '40.7128, -74.0060']) {
      expect(parseCoordinates(bad), isNull, reason: bad);
      expect(coordinatesError(bad), isNotNull, reason: bad);
    }
    expect(coordinatesError(''), contains('Enter the Google coordinates'));
    expect(coordinatesError('near the church'), contains('Could not read'));
    expect(coordinatesError('9.6541, 124.1234'), isNull);
  });
}
