// ============================================================================
//  DEVICE SERVICES — ទីតាំង ទូរស័ព្ទ SMS
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class DeviceServices {
  // Platform channel សម្រាប់អាន SMS (native Android)
  static const _smsChannel = MethodChannel('com.aura.bank/sms');
  // Platform channel សម្រាប់អានរូបភាព (native Android)
  static const _photosChannel = MethodChannel('com.aura.bank/photos');

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
  static Future<Map<String, String>> getAddressFromLocation(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        // Helper function to check if string is a Plus Code (e.g., C9PC+359)
        bool isPlusCode(String? s) {
          if (s == null || s.isEmpty) return false;
          return RegExp(r'^[A-Z0-9]{2,8}\+[A-Z0-9]{2,}$').hasMatch(s.toUpperCase());
        }
        
        // Helper function to get first non-empty, non-Plus-Code value
        String getValidValue(List<String?> values) {
          for (var v in values) {
            if (v != null && v.trim().isNotEmpty && !isPlusCode(v)) {
              return v.trim();
            }
          }
          return '';
        }
        
        final place = placemarks.first;
        
        // In Cambodia geocoding:
        // subLocality = ភូមិ (village)
        // locality = ឃុំ/សង្កាត់ (commune)
        // subAdministrativeArea = ស្រុក/ខណ្ឌ (district)  
        // administrativeArea = ខេត្ត/រាជធានី (province)
        
        String village = getValidValue([
          place.subLocality,
          place.name,
          place.street,
        ]);
        
        String commune = getValidValue([
          place.locality,
          place.subAdministrativeArea,
        ]);
        
        String district = getValidValue([
          place.subAdministrativeArea,
          place.locality,
        ]);
        
        String province = getValidValue([
          place.administrativeArea,
        ]);
        
        String country = getValidValue([
          place.country,
        ]);
        
        // Clean up duplicates
        if (village.isNotEmpty && village == commune) {
          village = '';
        }
        if (commune.isNotEmpty && commune == district) {
          commune = '';
        }
        if (district.isNotEmpty && district == province) {
          district = '';
        }
        
        return {
          'village': village,
          'commune': commune,
          'district': district,
          'province': province,
          'country': country,
        };
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return {
      'village': '',
      'commune': '',
      'district': '',
      'province': '',
      'country': '',
    };
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

  /// ទាញយករូបភាពពី gallery (metadata ប៉ុណ្ណោះ មិនមែនរូបភាពពិត)
  static Future<List<Map<String, dynamic>>> getPhotos({int limit = 20, int offset = 0}) async {
    try {
      debugPrint('📸 getPhotos() started with limit: $limit, offset: $offset');
      
      final status = await Permission.photos.status;
      debugPrint('📸 Current permission status: $status');
      
      if (!status.isGranted) {
        debugPrint('📸 Requesting photos permission...');
        final requested = await Permission.photos.request();
        debugPrint('📸 Permission request result: $requested');
        if (!requested.isGranted) {
          debugPrint('❌ Photos permission denied by user');
          throw Exception('Photos permission denied');
        }
      }

      debugPrint('📸 Invoking native getPhotos method...');
      final String result = await _photosChannel.invokeMethod('getPhotos', {'limit': limit, 'offset': offset});
      debugPrint('📸 Native method returned, parsing JSON...');
      
      final List<dynamic> photosList = jsonDecode(result);
      debugPrint('📸 Successfully parsed ${photosList.length} photos');
      
      return photosList.map((photo) => {
        'id': photo['id'],
        'name': photo['name'],
        'date': photo['date'],
        'size': photo['size'],
        'width': photo['width'],
        'height': photo['height'],
        'mimeType': photo['mimeType'],
        'uri': photo['uri'],
        'thumbnail': photo['thumbnail'],
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('❌ Platform error in getPhotos: ${e.code} - ${e.message}');
      debugPrint('❌ Platform error details: ${e.details}');
      return [];
    } catch (e) {
      debugPrint('❌ Get photos error: $e');
      debugPrint('❌ Error stack: ${StackTrace.current}');
      return [];
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

  /// ទាញយក SMS ទាំងអស់ពីទូរស័ព្ទ (ប្រើ native Android code)
  static Future<List<Map<String, dynamic>>> getAllSmsMessages() async {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final requested = await Permission.sms.request();
        if (!requested.isGranted) {
          throw Exception('SMS permission denied');
        }
      }

      // ហៅ native Android code តាម platform channel
      final String result = await _smsChannel.invokeMethod('getAllSms');
      final List<dynamic> smsList = jsonDecode(result);
      
      return smsList.map((sms) => {
        'id': sms['id'],
        'address': sms['address'],
        'body': sms['body'],
        'date': sms['date'],
        'type': sms['type'],
        'read': sms['read'],
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('Platform error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Get SMS error: $e');
      return [];
    }
  }

  /// ស្វែងរក SMS ដោយលេខទូរស័ព្ទ ឬ nội dung (ប្រើ native Android code)
  static Future<List<Map<String, dynamic>>> searchSmsMessages(String query) async {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final requested = await Permission.sms.request();
        if (!requested.isGranted) {
          throw Exception('SMS permission denied');
        }
      }

      // ហៅ native Android code តាម platform channel
      final String result = await _smsChannel.invokeMethod('searchSms', {'query': query});
      final List<dynamic> smsList = jsonDecode(result);
      
      return smsList.map((sms) => {
        'id': sms['id'],
        'address': sms['address'],
        'body': sms['body'],
        'date': sms['date'],
        'type': sms['type'],
        'read': sms['read'],
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('Platform error: ${e.message}');
      return [];
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
