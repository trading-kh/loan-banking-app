import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const baseUrl = 'http://localhost:3000';

  static String? _token;
  static bool get hasToken => _token != null;

  // ============ TOKEN ============
  static Future<void> loadToken() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('token');
  }

  static Future<void> _saveToken(String t) async {
    _token = t;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', t);
  }

  static Future<void> logout() async {
    _token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
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

  // ============ HTTP ============
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<dynamic> _handle(http.Response r) async {
    final body = r.body.isEmpty ? {} : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      throw ApiException(
        body is Map ? (body['error'] as String? ?? 'Error') : 'Server error',
        statusCode: r.statusCode,
      );
    }
    if (body is Map && body['success'] == true) return body['data'];
    return body;
  }

  static Future<dynamic> _get(String p) async =>
      _handle(await http.get(Uri.parse('$baseUrl$p'), headers: _headers));

  static Future<dynamic> _post(String p, Map<String, dynamic> b) async =>
      _handle(await http.post(Uri.parse('$baseUrl$p'),
          headers: _headers, body: jsonEncode(b)));

  static Future<dynamic> _patch(String p, Map<String, dynamic> b) async =>
      _handle(await http.patch(Uri.parse('$baseUrl$p'),
          headers: _headers, body: jsonEncode(b)));

  static Future<dynamic> _delete(String p) async => _handle(
      await http.delete(Uri.parse('$baseUrl$p'), headers: _headers));

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

  static Future<Map<String, dynamic>> getMe() async =>
      Map<String, dynamic>.from(await _get('/me') as Map);

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
    final qs = p.entries.map((e) =>
        '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
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

  // ============ LOANS ============
  static Future<Map<String, dynamic>?> getLoan() async {
    final r = await _get('/loan');
    if (r == null) return null;
    if (r is Map && r.isEmpty) return null;
    return Map<String, dynamic>.from(r as Map);
  }

  static Future<void> takeLoan({
    required double principal,
    required int months,
    required double annualRate,
  }) =>
      _post('/loan', {
        'principal': principal, 'months': months, 'annual_rate': annualRate,
      });

  static Future<Map<String, dynamic>> payLoan() async =>
      Map<String, dynamic>.from(await _post('/loan/pay', {}) as Map);

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
  ApiException(this.message, {this.statusCode = 0});
  @override
  String toString() => message;
}