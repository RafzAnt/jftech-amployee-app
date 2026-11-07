import 'package:flutter_test/flutter_test.dart';

import 'package:jftech/services/auth_service.dart';

void main() {
  test('only the IP of the server computer is needed for a local server', () {
    // Port 8001 is the one `./serve.sh` uses; 8000 on the development computer is another project.
    expect(AuthService.normalizeUrl('192.168.1.22'), 'http://192.168.1.22:8001/backend/api');
    expect(AuthService.normalizeUrl('  192.168.1.22  '), 'http://192.168.1.22:8001/backend/api');
    expect(AuthService.normalizeUrl('192.168.1.22/'), 'http://192.168.1.22:8001/backend/api');
    expect(AuthService.normalizeUrl('http://192.168.1.22'), 'http://192.168.1.22:8001/backend/api');
  });

  test('a port or a full address that was typed is kept', () {
    expect(AuthService.normalizeUrl('192.168.1.22:8080'), 'http://192.168.1.22:8080/backend/api');
    expect(AuthService.normalizeUrl('http://192.168.1.22:8000/backend/api'), 'http://192.168.1.22:8000/backend/api');
    expect(AuthService.normalizeUrl('192.168.1.22:8001/backend/api/'), 'http://192.168.1.22:8001/backend/api');
    expect(AuthService.normalizeUrl(AuthService.productionBaseUrl), AuthService.productionBaseUrl);
  });

  test('what the app builds from an IP is a valid address, anything else says what to type', () {
    expect(AuthService.validateBaseUrl(AuthService.normalizeUrl('192.168.1.22')), isNull);
    expect(AuthService.validateBaseUrl(AuthService.normalizeUrl('10.0.2.2')), isNull);
    expect(AuthService.validateBaseUrl(AuthService.productionBaseUrl), isNull);
    expect(AuthService.validateBaseUrl(''), contains('cannot be empty'));
    expect(AuthService.validateBaseUrl(AuthService.normalizeUrl('my-laptop')), contains('IP of the server computer'));
    expect(AuthService.validateBaseUrl('http://192.168.1.22:8001/other'), contains('/backend/api'));
  });
}
