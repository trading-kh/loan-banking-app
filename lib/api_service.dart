import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// pubspec.yaml ត្រូវបន្ថែម៖
//   flutter_secure_storage: ^9.2.2
//   uuid: ^4.4.0

class ApiService {
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://bank-backend-f6ay.onrender.com');
  static const _timeout = Duration(seconds: 30); // Render free tier ដេកយូរ
  static final _secure = FlutterSecureStorage();
  static final _uuid = Uuid();

  static String? _token;
  static bool get hasToken => _token != null;

  // ============ TOKEN (រក្សាក្នុង Keystore/Keychain) ============
  static Future<void> loadToken() async {
    _token = await _secure.read(key: 'token');
  }

  static Future<void> _saveToken(String t) async {
    _token = t;
    await _secure.write(key: 'token', value: t);
  }

  static Future<void> logout() async {
    _token = null;
    await _secure.delete(key: 'token');
    await _secure.delete(key: 'saved_pin');
    final sp = await SharedPreferences.getInstance();
    await sp.remove('email');
  }

  static Future<String?> getSavedEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('email');
  }

  static Future<void> _saveEmail(String e) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('email', e);
  }

  /// PIN ដែល Backend បង្កើតឲ្យ Google User (រក្សាក្នុង secure storage)
  static Future<String?> getSavedPin() => _secure.read(key: 'saved_pin');
  static Future<void> clearSavedPin() => _secure.delete(key: 'saved_pin');

  // ============ HTTP ============
  static Map<String, String> _headers({String? idempotencyKey}) => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };

  static Future<dynamic> _handle(http.Response r) async {
    dynamic body = {};
    if (r.body.isNotEmpty) {
      try {
        body = jsonDecode(r.body);
      } catch (_) {
        // Render/proxy ត្រឡប់ HTML (502/503) ពេល Backend ដេក ឬគាំង → បង្ហាញលេខកូដឲ្យដឹង
        throw ApiException('Server error (${r.statusCode})',
            statusCode: r.statusCode, code: 'BAD_RESPONSE');
      }
    }
    if (r.statusCode >= 400) {
      throw ApiException(
        body is Map ? (body['error'] as String? ?? 'Error') : 'Server error',
        statusCode: r.statusCode,
        code: body is Map ? body['code'] as String? : null,
      );
    }
    if (body is Map && body['success'] == true) return body['data'];
    return body;
  }

  /// ព្យាយាមម្ដងទៀតពេល server កំពុងចាប់ផ្ដើមឡើងវិញ (dev reload) — កុំឱ្យកម្មវិធីបង្ហាញ "កំពុងផ្ទុក"
  /// មានតែការស្នើសម្រាប់ GET (មិនមានប្តូរទិន្នន័យ) — កុំព្យាយាមម្ដងទៀតប្រតិបត្តិការប៉ះ
  static Future<dynamic> _send(Future<http.Response> Function() req,
      {bool retryOnNetwork = false}) async {
    final maxAttempts = retryOnNetwork ? 4 : 1;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await _handle(await req().timeout(_timeout));
      } on TimeoutException {
        throw ApiException('ការតភ្ជាប់យឺតពេក សូមព្យាយាមម្ដងទៀត',
            code: 'TIMEOUT');
      } on http.ClientException {
        if (attempt == maxAttempts - 1) {
          throw ApiException('មិនមានអ៊ីនធឺណិត', code: 'NETWORK');
        }
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw ApiException('មិនមានអ៊ីនធឺណិត', code: 'NETWORK');
  }

  static Future<dynamic> _get(String p) => _send(
      () => http.get(Uri.parse('$baseUrl$p'), headers: _headers()),
      retryOnNetwork: true);

  static Future<dynamic> _post(String p, Map<String, dynamic> b,
          {String? idempotencyKey}) =>
      _send(() => http.post(Uri.parse('$baseUrl$p'),
          headers: _headers(idempotencyKey: idempotencyKey),
          body: jsonEncode(b)));

  static Future<dynamic> _patch(String p, Map<String, dynamic> b) =>
      _send(() => http.patch(Uri.parse('$baseUrl$p'),
          headers: _headers(), body: jsonEncode(b)));

  static Future<dynamic> _delete(String p) =>
      _send(() => http.delete(Uri.parse('$baseUrl$p'), headers: _headers()));

  // ============ AUTH ============
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String pin,
  }) async {
    final data = await _post('/auth/register', {
      'name': name, 'email': email, 'phone': phone, 'pin': pin,
    });
    await _saveToken(data['token']);
    await _saveEmail(email);
    return Map<String, dynamic>.from(data['user']);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String pin,
  }) async {
    final data = await _post('/auth/login', {'email': email, 'pin': pin});
    await _saveToken(data['token']);
    await _saveEmail(email);
    return Map<String, dynamic>.from(data['user']);
  }

  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final data = await _post('/auth/google', {'id_token': idToken});
    await _saveToken(data['token']);

    final email = data['user']['email'] as String? ?? '';
    if (email.isNotEmpty) await _saveEmail(email);

    if (data['generatedPin'] != null) {
      await _secure.write(key: 'saved_pin', value: data['generatedPin']);
    }
    return Map<String, dynamic>.from(data['user']);
  }

  static Future<Map<String, dynamic>> getMe() async =>
      Map<String, dynamic>.from(await _get('/me') as Map);

  /// រក្សាទុករូប Profile (data URL) ឬលុបដោយផ្ញើ null
  /// [thumb] = thumbnail 96px (data URL) សម្រាប់បង្ហាញក្នុងបញ្ជីអ្នកទទួល
  static Future<void> updateAvatar(String? dataUrl, {String? thumb}) =>
      _post('/me/avatar', {
        'avatar': dataUrl,
        if (thumb != null) 'thumb': thumb,
      });

  // ============ TRANSFERS (ថ្មី) ============

  /// ស្វែងរកអ្នកទទួល (លេខទូរស័ព្ទ / អ៊ីមែល / uid)
  /// Server ត្រឡប់៖ {recipient_id, name, masked_account}
  static Future<Map<String, dynamic>> lookupRecipient(String query) async =>
      Map<String, dynamic>.from(await _get(
              '/recipients/lookup?q=${Uri.encodeQueryComponent(query)}')
          as Map);

  /// បញ្ជីអ្នកទទួលដែលបានចុះឈ្មោះ (Server បិទបាំងលេខទូរស័ព្ទ/អ៊ីមែល)
  static Future<List<dynamic>> getRecipients({String? q, int limit = 50}) async =>
      await _get('/recipients?q=${Uri.encodeQueryComponent(q ?? '')}&limit=$limit')
          as List<dynamic>;

  /// ផ្ទេរលុយពិតប្រាកដ។ Server ជាអ្នកកាត់/បូកលុយ និងបង្កើតប្រតិបត្តិការទាំងពីរភាគី។
  /// [idempotencyKey] ត្រូវបង្កើតម្ដងក្នុងមួយការបញ្ជាក់ ហើយប្រើដដែលពេល retry
  static Future<Map<String, dynamic>> transfer({
    required String recipientId,
    required double amount,
    required String pin,
    required int cardId,
    String? note,
    String? idempotencyKey,
  }) async =>
      Map<String, dynamic>.from(await _post(
        '/transfers',
        {
          'recipient_id': recipientId,
          'amount': amount,
          'pin': pin,
          'card_id': cardId,
          if (note != null && note.isNotEmpty) 'note': note,
        },
        idempotencyKey: idempotencyKey ?? _uuid.v4(),
      ) as Map);

  static String newIdempotencyKey() => _uuid.v4();

  /// បង្កើត QR token ដែលមានអាយុខ្លី (សម្រាប់អ្នកទទួលបង្ហាញ)
  static Future<Map<String, dynamic>> createQr({double? amount}) async =>
      Map<String, dynamic>.from(await _post('/qr/create', {
        if (amount != null) 'amount': amount,
      }) as Map);

  /// បន្ទាប់ពីស្កេន QR ផ្ញើ token ទៅ Server ដើម្បីបានអ្នកទទួលពិតប្រាកដ
  static Future<Map<String, dynamic>> resolveQr(String qrToken) async =>
      Map<String, dynamic>.from(
          await _post('/qr/resolve', {'qr_token': qrToken}) as Map);

  /// ផ្ទេរចេញក្រៅ (ធនាគារ/MFIs/វ៉លឡេត)។ Server កាត់លុយ + fee ហើយកត់ត្រាតែម្ខាង។
  static Future<Map<String, dynamic>> transferExternal({
    required String bankCode,
    required String recipientName,
    required String recipientAccount,
    required double amount,
    required String pin,
    required int cardId,
    String? note,
    String? idempotencyKey,
  }) async =>
      Map<String, dynamic>.from(await _post(
        '/transfers/external',
        {
          'bank_code': bankCode,
          'recipient_name': recipientName,
          'recipient_account': recipientAccount,
          'amount': amount,
          'pin': pin,
          'card_id': cardId,
          if (note != null && note.isNotEmpty) 'note': note,
        },
        idempotencyKey: idempotencyKey ?? _uuid.v4(),
      ) as Map);

  /// បញ្ជី rails ដែល Backend គាំទ្រ (fee, min/max)
  static Future<List<dynamic>> getBanks() async =>
      await _get('/banks') as List<dynamic>;

  static Future<List<dynamic>> getExternalTransfers() async =>
      await _get('/transfers/external') as List<dynamic>;

  // ============ CARDS ============
  static Future<List<dynamic>> getCards() async =>
      await _get('/cards') as List<dynamic>;

  static Future<void> updateCard(int id,
          {bool? frozen, bool? online, double? dailyLimit}) =>
      _patch('/cards/$id', {
        if (frozen != null) 'frozen': frozen,
        if (online != null) 'online': online,
        if (dailyLimit != null) 'daily_limit': dailyLimit,
      });

  // ============ TRANSACTIONS ============
  static Future<List<dynamic>> getTransactions() async =>
      await _get('/transactions') as List<dynamic>;

  static Future<Map<String, dynamic>> createTransaction({
    required int cardId,
    required String title,
    required String category,
    required double amount,
    required bool isExpense,
    required int iconCode,
    required String pin,
  }) async =>
      Map<String, dynamic>.from(await _post('/transactions', {
        'card_id': cardId,
        'title': title,
        'category': category,
        'amount': amount,
        'is_expense': isExpense,
        'icon_code': iconCode,
        'pin': pin,
      }) as Map);

  static Future<List<dynamic>> searchTransactions({
    String? q, String? category, DateTime? from, DateTime? to,
    double? minAmount, double? maxAmount, bool? isExpense,
  }) async {
    final p = <String, String>{};
    if (q != null && q.isNotEmpty) p['q'] = q;
    if (category != null) p['category'] = category;
    if (from != null) p['from'] = from.toIso8601String();
    if (to != null) p['to'] = to.toIso8601String();
    if (minAmount != null) p['min_amount'] = minAmount.toString();
    if (maxAmount != null) p['max_amount'] = maxAmount.toString();
    if (isExpense != null) p['is_expense'] = isExpense.toString();
    final qs = p.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return await _get('/transactions/search${qs.isNotEmpty ? '?$qs' : ''}')
        as List<dynamic>;
  }

  // ============ GOALS ============
  static Future<List<dynamic>> getGoals() async =>
      await _get('/goals') as List<dynamic>;

  static Future<void> createGoal({
    required String name,
    required double target,
    int iconCode = 19,
    int color = 0xFF3D5AFE,
  }) =>
      _post('/goals', {
        'name': name, 'target': target,
        'icon_code': iconCode, 'color': color,
      });

  static Future<void> depositGoal(int id, double amount) =>
      _post('/goals/$id/deposit', {'amount': amount});

  // ============ NOTIFICATIONS ============
  static Future<List<dynamic>> getNotifications() async =>
      await _get('/notifications') as List<dynamic>;

  static Future<void> markAllRead() => _post('/notifications/read-all', {});

  // ============ LOANS (ម៉ាស៊ីនកម្ចី) ============
  /// កម្ចីដែលកំពុងដំណើរការ (អាច null បើអត់អានកម្ចីស្រាប់បាន)
  static Future<Map<String, dynamic>?> getLoan() async {
    final r = await _get('/loan');
    if (r == null) return null;
    if (r is Map && r.isEmpty) return null;
    return Map<String, dynamic>.from(r as Map);
  }

  /// បញ្ជីកម្ចីទាំងអស់ (បុព្វបទ + កំពុងដំណើរការ)
  static Future<List<dynamic>> getLoans() async {
    final r = await _get('/loans');
    if (r is Map) return (r['rows'] as List<dynamic>?) ?? [];
    return (r as List<dynamic>?) ?? [];
  }

  /// ព័ត៌មាន KYC របស់អ្នកប្រើ (null បើមិនទាន់បានបំពេញ)
  static Future<Map<String, dynamic>?> getLoanKyc() async {
    final r = await _get('/loan/kyc');
    if (r == null) return null;
    if (r is Map && r.isEmpty) return null;
    return Map<String, dynamic>.from(r as Map);
  }

  /// រក្សាទុក KYC — submit=true ដាក់ស្នើទៅការវាយតម្លៃ
  static Future<Map<String, dynamic>> saveLoanKyc(
      Map<String, dynamic> data, {bool submit = false}) async {
    final r = await _post('/loan/kyc', {...data, 'submit': submit});
    return Map<String, dynamic>.from(r as Map);
  }

  /// គណនាតារាងសងប្រាក់មុនស្នើ (មិនរក្សាទុក)
  static Future<Map<String, dynamic>> loanQuote({
    required double principal,
    required int months,
    required double annualRate,
    String interestMethod = 'annuity',
    double feePercent = 0,
  }) async {
    final r = await _post('/loan/quote', {
      'principal': principal,
      'months': months,
      'annual_rate': annualRate,
      'interest_method': interestMethod,
      'fee_percent': feePercent,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// ដាក់ស្នើសាកលកម្មកម្ចី (រង់ចាំការវាយតម្លៃ + អនុមត្ត)
  static Future<Map<String, dynamic>> applyLoan({
    required double principal,
    required int months,
    required double annualRate,
    required String province,
    required String district,
    required String commune,
    required String village,
    String interestMethod = 'annuity',
    String purpose = '',
  }) async {
    final r = await _post('/loan/apply', {
      'principal': principal,
      'months': months,
      'annual_rate': annualRate,
      'interest_method': interestMethod,
      'province': province,
      'district': district,
      'commune': commune,
      'village': village,
      'purpose': purpose,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// តារាងសងប្រាក់តាមខែ + កំណត់ចំនាំការបង់ (អានប្រាក់ដោយគ្មាន)
  static Future<Map<String, dynamic>> getLoanSchedule() async {
    final r = await _get('/loan/schedule');
    return Map<String, dynamic>.from(r as Map);
  }

  /// បង់វីនុបទ — amount=null បង់វីនុបទបន្ទាប់ទាំងអស់
  static Future<Map<String, dynamic>> payLoanInstallment(
      {double? amount, int? cardId}) async {
    final r = await _post('/loan/pay', {
      if (amount != null) 'amount': amount,
      if (cardId != null) 'card_id': cardId,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// ធ្វើការចុជ្ជាប្រាក់ផុតកំណត់ (បង្កើតកាតក្រង់ប្រមូល)
  static Future<void> syncLoanArrears() async => _post('/loan/sync', {});

  /// បើក/បិទបង់ស្វត្តកម្ម — ដកចំនួនពេលវីនុបទដល់កាលពីកាត
  static Future<Map<String, dynamic>> setLoanAutoDebit({required bool enabled}) async {
    final r = await _post('/loan/auto-debit', {'enabled': enabled});
    return Map<String, dynamic>.from(r as Map);
  }

  // ============ ANALYTICS ============
  static Future<Map<String, dynamic>> getAnalytics() async =>
      Map<String, dynamic>.from(await _get('/analytics') as Map);

  // ============ BUDGETS ============
  static Future<List<dynamic>> getBudgets() async =>
      await _get('/budgets') as List<dynamic>;

  static Future<void> createBudget(String category, double amount) =>
      _post('/budgets', {'category': category, 'amount': amount});

  static Future<void> updateBudget(int id, double amount) =>
      _patch('/budgets/$id', {'amount': amount});

  static Future<void> deleteBudget(int id) => _delete('/budgets/$id');

  // ============ STREAK ============
  static Future<Map<String, dynamic>> getStreak() async =>
      Map<String, dynamic>.from(await _get('/streak') as Map);

  static Future<Map<String, dynamic>> checkInStreak() async =>
      Map<String, dynamic>.from(await _post('/streak/check-in', {}) as Map);

  // ============ ACHIEVEMENTS ============
  static Future<List<dynamic>> getAchievements() async =>
      await _get('/achievements') as List<dynamic>;

  // ============ REMINDERS ============
  static Future<List<dynamic>> getReminders() async =>
      await _get('/reminders') as List<dynamic>;

  static Future<void> createReminder(String title, double amount,
          DateTime dueDate, {int iconCode = 16}) =>
      _post('/reminders', {
        'title': title,
        'amount': amount,
        'due_date': dueDate.toIso8601String().split('T')[0],
        'icon_code': iconCode,
      });

  static Future<void> setReminderPaid(int id, bool paid) =>
      _patch('/reminders/$id', {'paid': paid});

  static Future<void> deleteReminder(int id) => _delete('/reminders/$id');

  // ============ RECURRING ============
  static Future<List<dynamic>> getRecurring() async =>
      await _get('/recurring') as List<dynamic>;

  static Future<void> createRecurring({
    required String title,
    required double amount,
    required int cardId,
    required DateTime nextDate,
    String category = 'វិក្កយបត្រ',
    String frequency = 'monthly',
    int iconCode = 16,
  }) =>
      _post('/recurring', {
        'title': title,
        'amount': amount,
        'card_id': cardId,
        'next_date': nextDate.toIso8601String().split('T')[0],
        'category': category,
        'frequency': frequency,
        'icon_code': iconCode,
      });

  static Future<void> toggleRecurring(int id, bool active) =>
      _patch('/recurring/$id', {'active': active});

  static Future<void> deleteRecurring(int id) => _delete('/recurring/$id');

  static Future<Map<String, dynamic>> processRecurringDue() async =>
      Map<String, dynamic>.from(
          await _post('/recurring/process-due', {}) as Map);

  // ============ SPLITS ============
  static Future<List<dynamic>> getSplits() async =>
      await _get('/splits') as List<dynamic>;

  static Future<void> createSplit(
          String title, double total, List<String> participants) =>
      _post('/splits', {
        'title': title,
        'total_amount': total,
        'participants': participants,
      });

  // ============ VIRTUAL CARDS ============
  static Future<List<dynamic>> getVirtualCards() async =>
      await _get('/virtual-cards') as List<dynamic>;

  static Future<void> createVirtualCard(String name, {double limit = 500}) =>
      _post('/virtual-cards', {'name': name, 'limit_amount': limit});

  static Future<void> updateVirtualCard(int id,
          {bool? active, bool? frozen}) =>
      _patch('/virtual-cards/$id', {
        if (active != null) 'active': active,
        if (frozen != null) 'frozen': frozen,
      });

  static Future<void> deleteVirtualCard(int id) =>
      _delete('/virtual-cards/$id');

  // ============ REFERRAL ============
  static Future<Map<String, dynamic>> getReferral() async =>
      Map<String, dynamic>.from(await _get('/referral') as Map);

  static Future<Map<String, dynamic>> redeemReferral(String code) async =>
      Map<String, dynamic>.from(
          await _post('/referral/redeem', {'code': code}) as Map);

  // ============ CASHBACK ============
  static Future<Map<String, dynamic>> getCashback() async =>
      Map<String, dynamic>.from(await _get('/cashback') as Map);

  // ============ INSIGHTS ============
  static Future<Map<String, dynamic>> getInsights() async =>
      Map<String, dynamic>.from(await _get('/insights') as Map);

  // ============ FCM ============
  static Future<void> registerFcmToken(String token) =>
      _post('/fcm/register', {'token': token});

  // ============ CURRENCY ============
  static Future<Map<String, dynamic>> getCurrencyRates() async =>
      Map<String, dynamic>.from(await _get('/currency/rates') as Map);
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? code; // ឧ. WRONG_PIN, INSUFFICIENT_FUNDS, PIN_LOCKED
  ApiException(this.message, {this.statusCode = 0, this.code});
  @override
  String toString() => message;
}