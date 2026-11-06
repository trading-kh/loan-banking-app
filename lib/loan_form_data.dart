// ============================================================================
//  LOAN FORM DATA — ទិន្នន័យទម្រង់ស្នើសុំឥណទាន
// ============================================================================

import 'id_scan_screen.dart';

class LoanFormData {
  // Currency
  String currency; // 'KHR' or 'USD'
  
  // Loan details
  double amount;
  int? durationMonths;
  String purpose;
  String? loanTarget;
  
  // Region
  String? province;
  String? district;
  String? commune;
  String? village;
  String? address;
  
  // From ID scan
  IdCardData? scannedId;
  
  // From KYC
  String? phone;
  String? fullName;
  String? nationalId;
  
  // Backend response
  String? referenceNumber;
  Map<String, dynamic>? loanResponse;

  LoanFormData({
    this.currency = 'KHR',
    this.amount = 0,
    this.durationMonths,
    this.purpose = '',
    this.loanTarget,
    this.province,
    this.district,
    this.commune,
    this.village,
    this.address,
    this.scannedId,
    this.phone,
    this.fullName,
    this.nationalId,
    this.referenceNumber,
    this.loanResponse,
  });

  bool get isValid =>
      amount > 0 &&
      durationMonths != null &&
      province != null &&
      district != null &&
      commune != null &&
      village != null;

  Map<String, dynamic> toKycPayload() {
    final dob = scannedId?.dob;
    final dobStr = dob != null
        ? '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}'
        : '';

    return {
      'full_name': fullName ?? scannedId?.fullName ?? '',
      'national_id': nationalId ?? scannedId?.idNumber ?? '',
      'dob': dobStr,
      'gender': scannedId?.gender ?? '',
      'phone': phone ?? '',
      'province': province ?? '',
      'district': district ?? '',
      'commune': commune ?? '',
      'village': village ?? '',
      'birth_place': scannedId?.birthPlace ?? '',
      'occupation': '',
      'business_name': '',
      'business_type': loanTarget ?? '',
      'business_years': 0,
      'monthly_income': 0,
      'monthly_expense': 0,
      'existing_debt': 0,
      'bank_name': '',
      'bank_account': '',
      'submit': true,
    };
  }

  Map<String, dynamic> toApplyPayload() {
    return {
      'principal': amount,
      'months': durationMonths ?? 12,
      'annual_rate': 21.6,
      'interest_method': 'annuity',
      'province': province ?? '',
      'district': district ?? '',
      'commune': commune ?? '',
      'village': village ?? '',
      'purpose': '${loanTarget ?? ''}: $purpose'.trim(),
      'currency': currency,
    };
  }
}
