// ============================================================================
//  ID CARD SCAN SCREEN — ស្កេនអត្តសញ្ញាបណ្ណ (Auto-scan)
//  ប្រើកាមេរ៉ាថតរូបអត្តសញ្ញាបណ្ណដោយស្វ័យប្រវត្តិ
// ============================================================================
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'main.dart';

/// លទ្ធផលស្កេនអត្តសញ្ញាបណ្ណ
class IdCardData {
  final String idNumber;
  final String fullName;
  final String surname;
  final String givenName;
  final DateTime? dob;
  final String gender;
  final DateTime? expiryDate;
  final DateTime? issueDate;
  final String nationality;
  final String? address;
  final String? birthPlace;

  IdCardData({
    required this.idNumber,
    required this.fullName,
    required this.surname,
    required this.givenName,
    this.dob,
    required this.gender,
    this.expiryDate,
    this.issueDate,
    required this.nationality,
    this.address,
    this.birthPlace,
  });

  /// ពិនិត្យមើលថាតើអត្តសញ្ញាបណ្ណផុតកំណត់ឬអត់
  /// Conservative approach: សន្មតថាមិនផុតកំណត់លើកលែងតែ date ច្បាស់លាស់
  bool get isExpired {
    final now = DateTime.now();
    
    // ពិនិត្យ MRZ expiry date (ត្រូវ year >= 2020 ទើបជឿទុកចិត្ត)
    if (expiryDate != null) {
      if (expiryDate!.year >= 2020 && expiryDate!.isBefore(now)) {
        return true;
      }
    }
    
    // ពិនិត្យ issue date + 10 years (ត្រូវ year >= 2010 ទើបជឿទុកចិត្ត)
    if (issueDate != null && issueDate!.year >= 2010) {
      final tenYearsLater = DateTime(issueDate!.year + 10, issueDate!.month, issueDate!.day);
      if (tenYearsLater.isBefore(now)) {
        return true;
      }
    }
    
    // Default: មិនផុតកំណត់ (conservative)
    return false;
  }
}

class IdCardScanScreen extends StatefulWidget {
  const IdCardScanScreen({super.key});
  @override
  State<IdCardScanScreen> createState() => _IdCardScanScreenState();
}

class _IdCardScanScreenState extends State<IdCardScanScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _processing = false;
  String? _error;
  bool _scanComplete = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  TextRecognizer? _textRecognizer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    // ប្រើទាំង Latin និង Khmer script
    _textRecognizer = TextRecognizer();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _textRecognizer?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'រកមិនឃើញកាមេរ៉ា');
        return;
      }
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startAutoScan();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'កំហុសកាមេរ៉ា: $e');
    }
  }

  /// ចាប់ផ្តើមស្កេនដោយស្វ័យប្រវត្តិ
  void _startAutoScan() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // ថតរូបរៀងរាល់ 2 វិនាទី
    Future.doWhile(() async {
      if (!mounted || _scanComplete || _processing) return false;
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted || _scanComplete || _processing) return false;
      await _captureAndAnalyze();
      return !_scanComplete;
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_processing || _scanComplete) return;

    setState(() => _processing = true);

    try {
      final image = await _controller!.takePicture();
      final imageFile = File(image.path);
      final inputImage = InputImage.fromFile(imageFile);

      final RecognizedText recognizedText =
          await _textRecognizer!.processImage(inputImage);

      final idData = _parseIdCard(recognizedText.text);

      if (mounted && idData != null) {
        setState(() => _scanComplete = true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, idData);
        }
      }
    } catch (e) {
      // បន្តស្កេន កុំបង្ហាញកំហុស
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// វិភាគអត្ថបទពីអត្តសញ្ញាបណ្ណកម្ពុជា
  IdCardData? _parseIdCard(String text) {
    // Debug: បង្ហាញអត្ថបទដែល OCR ចាប់បាន
    debugPrint('=== OCR CAPTURED TEXT ===');
    debugPrint(text);
    debugPrint('=== END OCR TEXT ===');
    
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    // Debug: បង្ហាញបន្ទាត់ទាំងអស់
    debugPrint('=== PARSED LINES (${lines.length}) ===');
    for (var i = 0; i < lines.length; i++) {
      debugPrint('Line $i: ${lines[i]}');
    }
    debugPrint('=== END LINES ===');

    String? mrzLine1, mrzLine2, mrzLine3;
    for (var i = lines.length - 1; i >= 0 && i >= lines.length - 5; i--) {
      final line = lines[i];
      if (line.startsWith('IDKHM')) {
        mrzLine1 = line;
        if (i + 1 < lines.length) mrzLine2 = lines[i + 1];
        if (i + 2 < lines.length) mrzLine3 = lines[i + 2];
        break;
      }
    }

    if (mrzLine1 == null || mrzLine2 == null || mrzLine3 == null) {
      return null;
    }

    final idNumber = mrzLine1.substring(5, 14).replaceAll('<', '');

    final dobStr = mrzLine2.substring(0, 6);
    DateTime? dob;
    if (dobStr.length == 6) {
      final year = int.tryParse(dobStr.substring(0, 2)) ?? 0;
      final month = int.tryParse(dobStr.substring(2, 4)) ?? 0;
      final day = int.tryParse(dobStr.substring(4, 6)) ?? 0;
      // Validate: month 01-12, day 01-31
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        final fullYear = year >= 50 ? 1900 + year : 2000 + year;
        dob = DateTime(fullYear, month, day);
      }
    }

    final gender = mrzLine2[7];

    final expiryStr = mrzLine2.substring(8, 14);
    DateTime? expiryDate;
    if (expiryStr.length == 6) {
      final year = int.tryParse(expiryStr.substring(0, 2)) ?? 0;
      final month = int.tryParse(expiryStr.substring(2, 4)) ?? 0;
      final day = int.tryParse(expiryStr.substring(4, 6)) ?? 0;
      // Validate: year ត្រូវ 00-99, month 01-12, day 01-31
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        final fullYear = year >= 50 ? 1900 + year : 2000 + year;
        // ទុកចិត្តតែ year >= 2020 (ID card ទំនើប)
        if (fullYear >= 2020) {
          expiryDate = DateTime(fullYear, month, day);
        }
      }
    }

    final nationality = mrzLine2.substring(15, 18);

    final nameParts = mrzLine3.split('<<');
    final surname = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', '') : '';
    final givenName = nameParts.length > 1 ? nameParts[1].replaceAll('<', '') : '';
    final fullName = '$surname $givenName'.trim();

    // រកថ្ងៃចេញ (សុពលភាព) — Issue date
    DateTime? issueDate;
    for (final line in lines) {
      if (line.contains('សុពលភាព')) {
        final match = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{4})').firstMatch(line);
        if (match != null) {
          final day = int.tryParse(match.group(1)!) ?? 0;
          final month = int.tryParse(match.group(2)!) ?? 0;
          final year = int.tryParse(match.group(3)!) ?? 0;
          if (day > 0 && day <= 31 && month > 0 && month <= 12 && year > 2000) {
            issueDate = DateTime(year, month, day);
          }
        }
        break;
      }
    }

    String? address;
    String? birthPlace;
    
    // វិធីសាស្រ្តទី១: រកតាម section headers
    // រកទីកន្លែងកំណើត (Place of birth)
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('កំណើត')) {
        final birthLines = <String>[];
        // រកបន្ទាត់បន្ទាប់ដែលមានព័ត៌មានទីកន្លែង (រហូតដល់ ៥បន្ទាត់)
        for (var j = i + 1; j < lines.length && j < i + 6; j++) {
          final nextLine = lines[j];
          // ឈប់នៅពេលឃើញ section ផ្សេង ឬ MRZ
          if (nextLine.contains('អាសយដ្ឋាន') || nextLine.startsWith('IDKHM') || 
              nextLine.contains('សុពលភាព') || nextLine.contains('លេខ')) {
            break;
          }
          // បើបន្ទាត់មានអក្សរខ្មែរ និងវែងគ្រប់គ្រាន់
          if (nextLine.length > 3 && RegExp(r'[\u1780-\u17FF]').hasMatch(nextLine)) {
            birthLines.add(nextLine);
          }
        }
        if (birthLines.isNotEmpty) {
          birthPlace = birthLines.join(' ');
        }
        break;
      }
    }
    
    // រកអាសយដ្ឋាន (Address)
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('អាសយដ្ឋាន')) {
        final addressLines = <String>[];
        // បើបន្ទាត់នេះមានព័ត៌មានផង (មិនមែនគ្រាន់តែជា header)
        if (line.length > 12 && line != 'អាសយដ្ឋាន' && RegExp(r'[\u1780-\u17FF]').hasMatch(line)) {
          addressLines.add(line);
        }
        // រកបន្ទាត់បន្ទាប់ (រហូតដល់ ៥បន្ទាត់)
        for (var j = i + 1; j < lines.length && j < i + 6; j++) {
          final nextLine = lines[j];
          // ឈប់នៅពេលឃើញ section ផ្សេង ឬ MRZ
          if (nextLine.startsWith('IDKHM') || nextLine.contains('សុពលភាព') || 
              nextLine.contains('កំណើត')) {
            break;
          }
          // បើបន្ទាត់មានអក្សរខ្មែរ
          if (nextLine.length > 3 && RegExp(r'[\u1780-\u17FF]').hasMatch(nextLine)) {
            addressLines.add(nextLine);
          }
        }
        if (addressLines.isNotEmpty) {
          address = addressLines.join(' ');
        }
        break;
      }
    }
    
    // វិធីសាស្រ្តទី២: Fallback - រកបន្ទាត់ដែលមានពាក្យទីតាំង
    if (address == null || birthPlace == null) {
      final locationLines = <String>[];
      for (final line in lines) {
        // មិនរកបន្ទាត់ដែលជា section headers ឬ MRZ
        if (!line.contains('កំណើត') && !line.contains('អាសយដ្ឋាន') && 
            !line.startsWith('IDKHM') && !line.contains('សុពលភាព')) {
          if (line.contains('ភូមិ') || line.contains('ឃុំ') ||
              line.contains('សង្កាត់') || line.contains('ស្រុក') ||
              line.contains('ខណ្ឌ') || line.contains('ខេត្ត') ||
              line.contains('ក្រុង')) {
            locationLines.add(line);
          }
        }
      }
      
      if (locationLines.isNotEmpty) {
        // ចាត់ទុកបន្ទាត់ទាំងអស់ជាទីកន្លែងកំណើត និងអាសយដ្ឋាន
        final allLocations = locationLines.join(' ');
        if (birthPlace == null) birthPlace = allLocations;
        if (address == null) address = allLocations;
      }
    }
    
    // Final fallback: រកបន្ទាត់វែងដែលមានអក្សរខ្មែរ
    if (address == null || birthPlace == null) {
      for (final line in lines) {
        if (line.length > 15 && RegExp(r'[\u1780-\u17FF]').hasMatch(line) &&
            !line.startsWith('IDKHM') && !line.contains('សុពលភាព')) {
          if (address == null) address = line;
          if (birthPlace == null) birthPlace = line;
          break;
        }
      }
    }
    
    // Debug: បង្ហាញលទ្ធផល
    debugPrint('=== PARSED RESULT ===');
    debugPrint('Address: $address');
    debugPrint('Birth Place: $birthPlace');
    debugPrint('=== END RESULT ===');

    return IdCardData(
      idNumber: idNumber,
      fullName: fullName,
      surname: surname,
      givenName: givenName,
      dob: dob,
      gender: gender,
      expiryDate: expiryDate,
      issueDate: issueDate,
      nationality: nationality,
      address: address,
      birthPlace: birthPlace,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _controller == null) {
      return Scaffold(
        backgroundColor: context.bg,
        appBar: AppBar(
          title: const Text('ស្កេនអត្តសញ្ញាបណ្ណ'),
          backgroundColor: context.bg,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: C.accentRed.withValues(alpha: 0.5)),
              const SizedBox(height: 20),
              Text(_error!, style: TextStyle(color: context.muted, fontSize: 14)),
              const SizedBox(height: 32),
              NeuButton(
                label: 'ព្យាយាមម្តងទៀត',
                icon: Icons.refresh,
                onPressed: _initCamera,
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: context.bg,
        appBar: AppBar(
          title: const Text('ស្កេនអត្តសញ្ញាបណ្ណ'),
          backgroundColor: context.bg,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: C.accent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ស្កេនអត្តសញ្ញាបណ្ណ'),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // បង្ហាញកាមេរ៉ា
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // ផ្ទៃខាងលើ with gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ផ្ទៃខាងក្រោម with gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ក្របខ័ណ្ឌស្កេន
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 320,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: C.accent.withValues(alpha: 0.8),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: C.accent.withValues(alpha: 0.3 * _pulseAnimation.value),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // បន្ទាត់ស្កេន
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 300,
                  height: 2,
                  decoration: BoxDecoration(
                    color: C.accent.withValues(alpha: 0.6),
                    boxShadow: [
                      BoxShadow(
                        color: C.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  transform: Matrix4.translationValues(
                    0,
                    -80 + (160 * _pulseAnimation.value),
                    0,
                  ),
                );
              },
            ),
          ),

          // ព័ត៌មានណែនាំ
          Positioned(
            top: 140,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: C.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ដាក់អត្តសញ្ញាបណ្ណក្នុងក្របខ័ណ្ឌ វានឹងស្កេនដោយស្វ័យប្រវត្តិ',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ស្ថានភាពស្កេន
          if (_processing)
            Positioned(
              bottom: 220,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: C.accent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: C.accent.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'កំពុងស្កេន...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ប៊ូតុងបិទ
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
