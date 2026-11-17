import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// tools/mock_entra (Node ≥ 22) on a free port, with a fresh in-memory state.
/// The same fake the example app and rn-social-login's tests talk to.
class MockEntra {
  MockEntra._(this._process, this.baseUrl);

  static Future<MockEntra> start() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final process = await Process.start(
      'node',
      ['../../tools/mock_entra/server.js'],
      environment: {'PORT': '$port'},
    );
    final ready = Completer<void>();
    process.stdout.transform(utf8.decoder).listen((chunk) {
      if (chunk.contains('one-time passcode') && !ready.isCompleted) {
        ready.complete();
      }
    });
    process.stderr.transform(utf8.decoder).listen((chunk) {
      if (!ready.isCompleted) {
        ready.completeError(StateError('mock_entra failed: $chunk'));
      }
    });
    await ready.future.timeout(const Duration(seconds: 10));
    return MockEntra._(process, 'http://127.0.0.1:$port/mock-tenant');
  }

  final Process _process;
  final String baseUrl;

  /// Every request sent through [client]: path after [baseUrl] and form.
  final calls = <({String path, Map<String, String> form})>[];

  late final http.Client client = _RecordingClient(this);

  void stop() {
    client.close();
    _process.kill();
  }
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._mock);

  final MockEntra _mock;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request) {
      _mock.calls.add((
        path: request.url.toString().substring(_mock.baseUrl.length),
        form: request.bodyFields,
      ));
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
