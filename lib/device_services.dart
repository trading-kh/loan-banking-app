// ============================================================================
//  DEVICE SERVICES — ទីតាំង ទូរស័ព្ទ SMS
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class DeviceServices {

  // ==========================================================================
  // 📍 LOCATION SERVICES
  // ==========================================================================

  /// ពិនិត្យ និងស្នើសុំ location permission
  static Future<bool> requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    
    if (status.isGranted) return true;
    
    status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// ទទួលបានទីតាំងបច្ចុប្បន្ន
  static Future<Position?> getCurrentLocation() async {
    try {
      // ពិនិត្យ permission
      if (!await requestLocationPermission()) {
        return null;
      }

      // ពិនិត្យ location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // ទទួលទីតាំង
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  /// បំប្លែងទីតាំងទៅជាអាសយដ្ឋាន
  static Future<String> getAddressFromLocation(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  /// គណនាចម្ងាយរវាងទីតាំងពីរ (គីឡូម៉ែត្រ)
  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
  }

  // ==========================================================================
  // 📞 PHONE SERVICES
  // ==========================================================================

  /// ហៅទូរស័ព្ទទៅលេខណាមួយ
  static Future<bool> makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      return true;
      }
    } catch (e) {
      debugPrint('Phone call error: $e');
    }
    return false;
  }

  /// ហៅ Customer Service
  static Future<bool> callCustomerService() async {
    return await makePhoneCall('+85523456789'); // លេខ Customer Service
  }

  /// ហៅ Hotline
  static Future<bool> callHotline() async {
    return await makePhoneCall('+855123456789'); // លេខ Hotline
  }

  /// ទទួលលេខទូរស័ព្ទរបស់ឧបករណ៍ (តម្រូវឱ្យមាន READ_PHONE_NUMBERS permission)
  static Future<String?> getDevicePhoneNumber() async {
    try {
      // Note: មុខងារនេះអាចមិនដើរលើឧបករណ៍ខ្លះ
      // ដោយសារ carrier restrictions
      return null; // មិនមាន API ត្រង់ក្នុង Flutter
    } catch (e) {
      debugPrint('Get phone number error: $e');
      return null;
    }
  }

  /// ទាញយក contacts ទាំងអស់ពីទូរស័ព្ទ
  static Future<List<Map<String, dynamic>>> getAllContacts() async {
    try {
      final status = await Permission.contacts.status;
      if (!status.isGranted) {
        final requested = await Permission.contacts.request();
        if (!requested.isGranted) {
          throw Exception('Contacts permission denied');
        }
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      return contacts.map((c) => {
        'id': c.id,
        'displayName': c.displayName,
        'phones': c.phones.map((p) => p.number).toList(),
        'emails': c.emails.map((e) => e.address).toList(),
      }).toList();
    } catch (e) {
      debugPrint('Get contacts error: $e');
      return [];
    }
  }

  /// ស្វែងរក contact ដោយឈ្មោះ ឬលេខទូរស័ព្ទ
  static Future<List<Map<String, dynamic>>> searchContacts(String query) async {
    try {
      final allContacts = await getAllContacts();
      final lowerQuery = query.toLowerCase();
      
      return allContacts.where((c) {
        final name = (c['displayName'] as String?)?.toLowerCase() ?? '';
        final phones = (c['phones'] as List).cast<String>();
        return name.contains(lowerQuery) || 
               phones.any((p) => p.contains(query));
      }).toList();
    } catch (e) {
      debugPrint('Search contacts error: $e');
      return [];
    }
  }

  // ==========================================================================
  // 💬 SMS SERVICES
  // ==========================================================================

  /// ស្នើសុំ SMS permissions (url_launcher មិនត្រូវការ permission ទេ)
  static Future<bool> requestSmsPermissions() async {
    return true;
  }

  /// ផ្ញើ SMS
  static Future<bool> sendSms(String phoneNumber, String message) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
    } catch (e) {
      debugPrint('Send SMS error: $e');
    }
    return false;
  }

  /// ទាញយក SMS ទាំងអស់ពីទូរស័ព្ទ (តម្រូវឱ្យមាន native Android code)
  static Future<List<Map<String, dynamic>>> getAllSmsMessages() async {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final requested = await Permission.sms.request();
        if (!requested.isGranted) {
          throw Exception('SMS permission denied');
        }
      }

      // TODO: Implement native Android SMS reading via platform channel
      // For now, return empty list
      // Native code needed: query ContentResolver for "content://sms/"
      debugPrint('⚠️ SMS reading not yet implemented (needs native code)');
      return [];
    } catch (e) {
      debugPrint('Get SMS error: $e');
      return [];
    }
  }

  /// ស្វែងរក SMS ដោយលេខទូរស័ព្ទ ឬ nội dung
  static Future<List<Map<String, dynamic>>> searchSmsMessages(String query) async {
    try {
      final allSms = await getAllSmsMessages();
      final lowerQuery = query.toLowerCase();
      
      return allSms.where((sms) {
        final address = (sms['address'] as String?)?.toLowerCase() ?? '';
        final body = (sms['body'] as String?)?.toLowerCase() ?? '';
        return address.contains(lowerQuery) || body.contains(lowerQuery);
      }).toList();
    } catch (e) {
      debugPrint('Search SMS error: $e');
      return [];
    }
  }

  /// ទាញយក OTP ពី SMS body
  static String? extractOtp(String smsBody, {int length = 6}) {
    // ស្វែងរកលេខ $length ខ្ទង់
    final regex = RegExp('\\b\\d{$length}\\b');
    final match = regex.firstMatch(smsBody);
    return match?.group(0);
  }

  // ==========================================================================
  // 🎯 UTILITY METHODS
  // ==========================================================================

  /// ពិនិត្យ permissions ទាំងអស់
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'location': await Permission.locationWhenInUse.status.isGranted,
    };
  }

  /// ស្នើសុំ permissions ទាំងអស់ពេលចាប់ផ្តើមកម្មវិធី
  static Future<Map<String, bool>> requestAllPermissionsAtStartup() async {
    final results = <String, bool>{};

    // Location
    final locStatus = await Permission.locationWhenInUse.request();
    results['location'] = locStatus.isGranted;

    // Phone (សម្រាប់ហៅទូរស័ព្ទ)
    final phoneStatus = await Permission.phone.request();
    results['phone'] = phoneStatus.isGranted;

    // SMS (សម្រាប់ផ្ញើ SMS)
    final smsStatus = await Permission.sms.request();
    results['sms'] = smsStatus.isGranted;

    // Contacts (សម្រាប់អាន contacts)
    final contactsStatus = await Permission.contacts.request();
    results['contacts'] = contactsStatus.isGranted;

    debugPrint('🔐 Device permissions: $results');
    return results;
  }

  /// ស្នើសុំ permissions ទាំងអស់
  static Future<bool> requestAllPermissions() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// បង្ហាញ dialog ស្នើសុំ permission
  static Future<void> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onGrant,
  }) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('បោះបង់'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onGrant();
            },
            child: const Text('អនុញ្ញាត'),
          ),
        ],
      ),
    );
  }
}
