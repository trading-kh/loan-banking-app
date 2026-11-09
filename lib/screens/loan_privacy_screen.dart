// ============================================================================
//  LOAN PRIVACY & SERVICE INFO SCREEN — គោលការណ៍ឯកជនភាព និងសេវាកម្ម
// ============================================================================
import 'package:flutter/material.dart';

import '../main.dart';

class _PrivacySection {
  final IconData icon;
  final Color tint;
  final String title;
  final List<String> body;
  const _PrivacySection(this.icon, this.tint, this.title, this.body);
}

const _sections = [
  _PrivacySection(Icons.account_balance_rounded, C.accent, 'អំពីសេវាកម្មយើង', [
    'Aura Bank ផ្តល់ជូនអតិថិជននូវសេវាកម្មឥណទានរហ័សទាន់ចិត្ត តាមរយៈកម្មវិធីទូរស័ព្ទ ដោយមិនចាំបាច់ធ្វើដំណើរមកកាន់សាខា។',
    'ចំនួនឥណទានរហូតដល់ \$50,000 រយៈពេលពី 3 ដល់ 60 ខែ អត្រាការប្រាក់ 21.6% ក្នុងមួយឆ្នាំ គិតតាមវិធីបង់ស្មើគ្នា (Annuity)។',
  ]),
  _PrivacySection(Icons.folder_open_rounded, C.accentPurple, 'ព័ត៌មានដែលយើងប្រមូល', [
    'ដើម្បីដំណើរការពាក្យស្នើសុំ យើងប្រមូលព័ត៌មានផ្ទាល់ខ្លួនដូចជា៖ ឈ្មោះពេញ លេខអត្តសញ្ញាបណ្ណជាតិ ថ្ងៃខែឆ្នាំកំណើត ភេទ លេខទូរស័ព្ទ និងអាសយដ្ឋានបច្ចុប្បន្ន។',
    'រូបភាពអត្តសញ្ញាបណ្ណដែលអ្នកស្កេន ត្រូវបានប្រើប្រាស់តែក្នុងគោលបំណងផ្ទៀងផ្ទាត់អត្តសញ្ញាណប៉ុណ្ណោះ។',
  ]),
  _PrivacySection(Icons.settings_suggest_rounded, C.accentTeal, 'គោលបំណងនៃការប្រើប្រាស់', [
    'ផ្ទៀងផ្ទាត់អត្តសញ្ញាណ និងវាយតម្លៃសំណើឥណទានរបស់អ្នក។',
    'ដំណើរការការផ្តល់ប្រាក់កម្ចី និងគ្រប់គ្រងការសងប្រាក់វិញ។',
    'ទំនាក់ទំនង និងជូនដំណឹងអំពីស្ថានភាពឥណទានរបស់អ្នក។',
  ]),
  _PrivacySection(Icons.lock_rounded, C.accentGreen, 'ការការពារទិន្នន័យ', [
    'រាល់ទិន្នន័យត្រូវបានអ៊ិនគ្រីប (encrypt) ទាំងពេលបញ្ជូន និងពេលរក្សាទុក។',
    'យើងប្រើប្រាស់ម៉ាស៊ីនមេដែលមានសុវត្ថិភាព និងកំណត់សិទ្ធិចូលប្រើប្រាស់យ៉ាងតឹងរ៉ឹង ដើម្បីការពារព័ត៌មានរបស់អ្នកពីការចូលប្រើដោយគ្មានការអនុញ្ញាត។',
  ]),
  _PrivacySection(Icons.share_rounded, C.accentGold, 'ការចែករំលែកព័ត៌មាន', [
    'យើងមិនលក់ ឬជួញដូរព័ត៌មានផ្ទាល់ខ្លួនរបស់អ្នកទៅភាគីទីបីឡើយ។',
    'ព័ត៌មានអាចត្រូវបានចែករំលែកជាមួយធនាគារជាតិ ឬក្រុមហ៊ុនឥណទានប៊ូរ៉ូ (CBC) តែក្នុងករណីដែលច្បាប់តម្រូវប៉ុណ្ណោះ។',
  ]),
  _PrivacySection(Icons.verified_user_rounded, C.accent, 'សិទ្ធិរបស់អតិថិជន', [
    'អ្នកមានសិទ្ធិស្នើសុំមើល កែតម្រូវ ឬលុបព័ត៌មានផ្ទាល់ខ្លួនរបស់អ្នក។',
    'អ្នកអាចដកការយល់ព្រមចេញវិញបាន ដោយទំនាក់ទំនងមកកាន់ក្រុមការងារយើង។',
  ]),
  _PrivacySection(Icons.description_rounded, C.accentPurple, 'លក្ខខណ្ឌឥណទាន', [
    'អត្រាការប្រាក់ 21.6%/ឆ្នាំ គិតតាមវិធីបង់ស្មើគ្នា។ ការបង់ប្រចាំខែត្រូវបានកំណត់ជាក់លាក់ក្នុងតារាងសងប្រាក់។',
    'ការបង់យឺតអាចនឹងមានការគិតថ្លៃបន្ថែម និងប៉ះពាល់ដល់ពិន្ទុឥណទានរបស់អ្នក។',
    'អ្នកអាចសងប្រាក់មុនកាលកំណត់បាន ដោយអនុវត្តតាមលក្ខខណ្ឌដែលបានកំណត់។',
  ]),
];

class LoanPrivacyScreen extends StatelessWidget {
  const LoanPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('គោលការណ៍ឯកជនភាព'),
        backgroundColor: context.bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildHero(context),
          const SizedBox(height: 16),
          NeuBox(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: C.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ឯកសារនេះពន្យល់អំពីរបៀបដែល Aura Bank ប្រមូល ប្រើប្រាស់ និងការពារព័ត៌មានរបស់អ្នក ព្រមទាំងលក្ខខណ្ឌនៃសេវាកម្មឥណទាន។ សូមអានឱ្យបានយល់ច្បាស់ មុននឹងយល់ព្រម។',
                    style: TextStyle(
                        color: context.muted, fontSize: 13, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _sections.length; i++) ...[
            _buildSection(context, _sections[i], i + 1),
            const SizedBox(height: 12),
          ],
          _buildContact(context),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: context.bg,
          border: Border(top: BorderSide(color: context.border)),
        ),
        child: NeuButton(
          label: 'យល់ព្រម និងបិទ',
          icon: Icons.check_circle_rounded,
          accent: C.accentGreen,
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A5A87), Color(0xFF044466), Color(0xFF033553)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: C.brandStart.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -26,
            child: Icon(Icons.shield_rounded,
                size: 150, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.privacy_tip_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'គោលការណ៍ឯកជនភាព\nនិងសេវាកម្ម',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: C.accentGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: C.accentGreen.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Aura Bank · ឥណទាន',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ធ្វើបច្ចុប្បន្នភាព ២០២៦',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, _PrivacySection s, int index) {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    s.tint.withValues(alpha: 0.22),
                    s.tint.withValues(alpha: 0.10),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: s.tint.withValues(alpha: 0.35)),
                ),
                child: Icon(s.icon, color: s.tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$index. ${s.title}',
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < s.body.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 10),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: s.tint, shape: BoxShape.circle),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.body[i],
                    style: TextStyle(
                        color: context.muted, fontSize: 13, height: 1.65),
                  ),
                ),
              ],
            ),
            if (i < s.body.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildContact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          C.accent.withValues(alpha: 0.16),
          C.accentPurple.withValues(alpha: 0.10),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded,
                  color: C.accent, size: 22),
              const SizedBox(width: 10),
              Text('ទំនាក់ទំនងយើង',
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'បើមានសំណួរ ឬត្រូវការជំនួយអំពីសេវាកម្ម និងព័ត៌មានផ្ទាល់ខ្លួន សូមទំនាក់ទំនងមកកាន់ក្រុមការងារ Aura Bank៖',
            style: TextStyle(color: context.muted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 14),
          _contactRow(context, Icons.phone_rounded, 'ខ្សែទូរស័ព្ទបម្រើអតិថិជន',
              '023 888 999'),
          const SizedBox(height: 10),
          _contactRow(context, Icons.email_rounded, 'អ៊ីមែល',
              'support@aurabank.com.kh'),
          const SizedBox(height: 10),
          _contactRow(context, Icons.location_on_rounded, 'ការិយាល័យកណ្ដាល',
              'រាជធានីភ្នំពេញ កម្ពុជា'),
        ],
      ),
    );
  }

  Widget _contactRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: C.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: context.muted, fontSize: 11.5)),
              Text(value,
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}