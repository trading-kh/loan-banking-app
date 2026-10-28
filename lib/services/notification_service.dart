// lib/services/notification_service.dart
import '../api_service.dart';

class NotificationService {
  static Future<void> init() async {}
  static Future<String?> getToken() async => null;
  static Future<void> registerWithBackend() async {
    final token = await getToken();
    if (token != null) {
      try {
        await ApiService.registerFcmToken(token);
      } catch (_) {}
    }
  }
}