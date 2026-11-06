// ============================================================================
//  DEVICE FEATURES SCREEN — សាកល្បងមុខងារ ទីតាំង ទូរស័ព្ទ SMS
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart';
import '../device_services.dart';

class DeviceFeaturesScreen extends StatefulWidget {
  const DeviceFeaturesScreen({super.key});

  @override
  State<DeviceFeaturesScreen> createState() => _DeviceFeaturesScreenState();
}

class _DeviceFeaturesScreenState extends State<DeviceFeaturesScreen> {
  // Location
  String? _currentAddress;
  double? _latitude;
  double? _longitude;
  bool _loadingLocation = false;

  // Phone
  final _phoneController = TextEditingController(text: '+855123456789');
  bool _calling = false;

  // SMS
  final _smsPhoneController = TextEditingController(text: '+855123456789');
  final _smsMessageController = TextEditingController(text: 'សួស្តី! នេះជាសារសាកល្បងពី Aura Bank');

  @override
  void dispose() {
    _phoneController.dispose();
    _smsPhoneController.dispose();
    _smsMessageController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 📍 LOCATION METHODS
  // ==========================================================================

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingLocation = true);

    try {
      final position = await DeviceServices.getCurrentLocation();
      
      if (position != null) {
        final address = await DeviceServices.getAddressFromLocation(position);
        
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _currentAddress = address;
          _loadingLocation = false;
        });

        if (mounted) {
          toast(context, 'បានទទួលទីតាំងជោគជ័យ!');
        }
      } else {
        setState(() => _loadingLocation = false);
        if (mounted) {
          toast(context, 'មិនអាចទទួលបានទីតាំង', error: true);
        }
      }
    } catch (e) {
      setState(() => _loadingLocation = false);
      if (mounted) {
        toast(context, 'កំហុស: $e', error: true);
      }
    }
  }

  // ==========================================================================
  // 📞 PHONE METHODS
  // ==========================================================================

  Future<void> _makeCall() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      toast(context, 'សូមបញ្ចូលលេខទូរស័ព្ទ', error: true);
      return;
    }

    setState(() => _calling = true);

    try {
      final success = await DeviceServices.makePhoneCall(phone);
      
      setState(() => _calling = false);
      
      if (mounted) {
        if (success) {
          toast(context, 'កំពុងហៅ $phone...');
        } else {
          toast(context, 'មិនអាចហៅបាន', error: true);
        }
      }
    } catch (e) {
      setState(() => _calling = false);
      if (mounted) {
        toast(context, 'កំហុស: $e', error: true);
      }
    }
  }

  Future<void> _callCustomerService() async {
    setState(() => _calling = true);
    
    final success = await DeviceServices.callCustomerService();
    
    setState(() => _calling = false);
    
    if (mounted) {
      if (success) {
        toast(context, 'កំពុងហៅ Customer Service...');
      } else {
        toast(context, 'មិនអាចហៅបាន', error: true);
      }
    }
  }

  // ==========================================================================
  // 💬 SMS METHODS
  // ==========================================================================

  Future<void> _sendSms() async {
    final phone = _smsPhoneController.text.trim();
    final message = _smsMessageController.text.trim();
    
    if (phone.isEmpty || message.isEmpty) {
      toast(context, 'សូមបំពេញលេខទូរស័ព្ទ និងសារ', error: true);
      return;
    }

    final success = await DeviceServices.sendSms(phone, message);
    
    if (mounted) {
      if (success) {
        toast(context, 'បានបើកកម្មវិធី SMS');
      } else {
        toast(context, 'មិនអាចផ្ញើ SMS បាន', error: true);
      }
    }
  }

  // ==========================================================================
  // BUILD UI
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDark,
      appBar: AppBar(
        title: const Text('មុខងារឧបករណ៍'),
        backgroundColor: C.bgDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 📍 LOCATION SECTION
          _buildSection(
            icon: Icons.location_on,
            title: 'ទីតាំង (Location)',
            color: const Color(0xFF667EEA),
            children: [
              NeuButton(
                label: _loadingLocation ? 'កំពុងទទួលទីតាំង...' : 'ទទួលទីតាំងបច្ចុប្បន្ន',
                icon: Icons.my_location,
                onPressed: _loadingLocation ? null : _getCurrentLocation,
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ទីតាំង:',
                        style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_latitude!.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 13, color: context.ink),
                      ),
                      Text(
                        'Lng: ${_longitude!.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 13, color: context.ink),
                      ),
                      if (_currentAddress != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'អាសយដ្ឋាន:',
                          style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAddress!,
                          style: TextStyle(fontSize: 13, color: context.ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // 📞 PHONE SECTION
          _buildSection(
            icon: Icons.phone,
            title: 'ទូរស័ព្ទ (Phone)',
            color: const Color(0xFF764BA2),
            children: [
              NeuField(
                controller: _phoneController,
                label: 'លេខទូរស័ព្ទ',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              NeuButton(
                label: _calling ? 'កំពុងហៅ...' : 'ហៅទូរស័ព្ទ',
                icon: Icons.call,
                onPressed: _calling ? null : _makeCall,
              ),
              const SizedBox(height: 8),
              NeuButton(
                label: 'ហៅ Customer Service',
                icon: Icons.support_agent,
                onPressed: _calling ? null : _callCustomerService,
                accent: const Color(0xFF764BA2),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 💬 SMS SECTION
          _buildSection(
            icon: Icons.sms,
            title: 'សារ (SMS)',
            color: const Color(0xFF00B4D8),
            children: [
              NeuField(
                controller: _smsPhoneController,
                label: 'លេខទូរស័ព្ទទទួល',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.black.withValues(alpha: 0.18)
                      : context.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: TextField(
                  controller: _smsMessageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    label: const Text('សារ'),
                    icon: const Icon(Icons.message_outlined),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              NeuButton(
                label: 'ផ្ញើ SMS',
                icon: Icons.send,
                onPressed: _sendSms,
                accent: const Color(0xFF00B4D8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
