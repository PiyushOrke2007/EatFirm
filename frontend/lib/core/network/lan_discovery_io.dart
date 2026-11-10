import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<String?> discoverApiBaseUrl({
  required int discoveryPort,
  required int apiPort,
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;
  final result = Completer<String?>();
  final timeout = Timer(const Duration(seconds: 2), () {
    if (!result.isCompleted) {
      result.complete(null);
    }
  });

  try {
    socket.send(
      utf8.encode('EATFIRM_DISCOVERY_V1'),
      InternetAddress('255.255.255.255'),
      discoveryPort,
    );

    socket.listen((event) {
      if (event != RawSocketEvent.read || result.isCompleted) {
        return;
      }
      final datagram = socket.receive();
      if (datagram == null) {
        return;
      }
      final url = _parseResponse(datagram);
      if (url != null) {
        result.complete(url);
      }
    });

    return await result.future;
  } on SocketException {
    return null;
  } finally {
    timeout.cancel();
    socket.close();
  }
}

String? _parseResponse(Datagram datagram) {
  try {
    final payload = jsonDecode(utf8.decode(datagram.data));
    if (payload is! Map ||
        payload['service'] != 'eatfirm-api' ||
        payload['port'] is! int) {
      return null;
    }

    return 'http://${datagram.address.address}:${payload['port']}/api/v1';
  } on FormatException {
    return null;
  }
}
