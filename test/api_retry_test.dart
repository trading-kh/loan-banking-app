import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/api_service.dart';

const _port = 34567;

void main() {
  test('GET retries while the server is restarting, then succeeds', () async {
    // ១) មិនមាន server បើក → ត្រូវព្យាយាមម្ដងទៀត រហូតដល់បរាជ័យ
    final sw = Stopwatch()..start();
    await expectLater(
      ApiService.getMe(),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'NETWORK')),
    );
    sw.stop();
    // ព្យាយាម ៤ ដង (រង់ចាំ 400+800+1200ms) → ត្រូវយកពេលយ៉ាងតិច ២ វិនាទី
    expect(sw.elapsedMilliseconds, greaterThan(2000),
        reason: 'ត្រូវព្យាយាមម្ដងទៀតពេល server មិនឆ្លើយតប');

    // ២) server ឡើងវិញ → បញ្ជូនជាភាសាភ្លាម
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
    server.listen((req) async {
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'success': true,
        'data': {'id': 3, 'name': 'Vannsary', 'data_version': 4},
      }));
      await req.response.close();
    });

    final me = await ApiService.getMe();
    expect(me['name'], 'Vannsary');
    expect(me['data_version'], 4);

    await server.close(force: true);
  });
}
