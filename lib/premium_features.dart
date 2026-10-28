// ============================================================================
//  Premium Features — Theme, Language, CSV Export, Support Chat
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'main.dart';

// ============================================================
//  THEME SERVICE
// ============================================================
class ThemeService {
  static const List<Color> availableColors = [
    Color(0xFF5B6EF5),
    Color(0xFFE5484D),
    Color(0xFF16A34A),
    Color(0xFFC05621),
    Color(0xFF8E2DE2),
    Color(0xFF0F9D8A),
    Color(0xFFE11D78),
    Color(0xFFB7791F),
    Color(0xFF1F2937),
    Color(0xFF0B1B5E),
  ];

  static const List<String> colorNames = [
    'Indigo', 'Red', 'Green', 'Orange', 'Purple',
    'Teal', 'Pink', 'Gold', 'Grey', 'Navy',
  ];

  static Color accent = availableColors[0];

  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final c = sp.getInt('premium_accent_v1');
    if (c != null) accent = Color(c);
  }
}

// ============================================================
//  LANGUAGE SERVICE
// ============================================================
class LocaleService {
  static String current = 'km';

  static const Map<String, String> languageNames = {
    'km': 'ខ្មែរ',
    'en': 'English',
    'zh': '中文',
  };

  static const Map<String, String> languageFlags = {
    'km': '🇰🇭',
    'en': '🇬🇧',
    'zh': '🇨🇳',
  };

  static const Map<String, Map<String, String>> translations = {
    'km': {
      'theme_title': 'ពណ៌ផ្ទាំង',
      'theme_desc': 'ជ្រើសរើសពណ៌ដែលអ្នកចូលចិត្ត',
      'language_title': 'ភាសា',
      'language_desc': 'ជ្រើសរើសភាសារបស់អ្នក',
      'csv_title': 'នាំចេញទិន្នន័យ',
      'csv_desc': 'នាំចេញប្រតិបត្តិការជា CSV',
      'chat_title': 'ជំនួយអតិថិជន',
      'chat_desc': 'ជជែកជាមួយយើង',
      'save': 'រក្សាទុក',
      'cancel': 'បោះបង់',
      'export': 'នាំចេញ',
      'copy': 'ចម្លង',
      'copied': 'បានចម្លង!',
      'send': 'ផ្ញើ',
      'type_message': 'វាយសារ...',
      'chat_greeting': 'សួស្តី! ខ្ញុំជាជំនួយការរបស់ធនាគារ។ តើខ្ញុំអាចជួយអ្វី?',
      'chat_reply_1': 'អរគុណសម្រាប់សារ! ខ្ញុំនឹងជួយអ្នក។',
      'chat_reply_card': 'ចំពោះបញ្ហាកាត សូមចូលទៅ "កាត" ហើយជ្រើសកាតរបស់អ្នក។',
      'chat_reply_loan': 'សម្រាប់កម្ចី សូមចូលទៅ "កម្ចី" ហើយបំពេញព័ត៌មាន។',
      'chat_reply_fee': 'គ្មានថ្លៃសេវាសម្រាប់ការផ្ទេរប្រាក់ក្នុងប្រព័ន្ធ។',
      'chat_reply_help': 'ខ្ញុំនឹងភ្ជាប់អ្នកទៅអ្នកជំនួយការ។ សូមរង់ចាំ...',
      'chat_reply_thanks': 'អរគុណ! តើមានអ្វីទៀតដែលខ្ញុំអាចជួយ?',
      'chat_contact': 'ទំនាក់ទំនងផ្ទាល់',
      'chat_email': 'support@loanbanking.com',
      'chat_phone': '023 000 000',
    },
    'en': {
      'theme_title': 'Theme Color',
      'theme_desc': 'Choose your favorite color',
      'language_title': 'Language',
      'language_desc': 'Choose your language',
      'csv_title': 'Export Data',
      'csv_desc': 'Export transactions to CSV',
      'chat_title': 'Support Chat',
      'chat_desc': 'Chat with us',
      'save': 'Save',
      'cancel': 'Cancel',
      'export': 'Export',
      'copy': 'Copy',
      'copied': 'Copied!',
      'send': 'Send',
      'type_message': 'Type a message...',
      'chat_greeting': 'Hello! I\'m your bank assistant. How can I help?',
      'chat_reply_1': 'Thanks for your message! I\'ll help you.',
      'chat_reply_card': 'For card issues, go to "Cards" and select your card.',
      'chat_reply_loan': 'For loans, go to "Loans" and fill in the information.',
      'chat_reply_fee': 'There are no fees for in-app transfers.',
      'chat_reply_help': 'I\'ll connect you to a support agent. Please wait...',
      'chat_reply_thanks': 'You\'re welcome! Anything else?',
      'chat_contact': 'Direct Contact',
      'chat_email': 'support@loanbanking.com',
      'chat_phone': '023 000 000',
    },
    'zh': {
      'theme_title': '主题颜色',
      'theme_desc': '选择您最喜欢的颜色',
      'language_title': '语言',
      'language_desc': '选择您的语言',
      'csv_title': '导出数据',
      'csv_desc': '将交易导出为 CSV',
      'chat_title': '客服聊天',
      'chat_desc': '与我们聊天',
      'save': '保存',
      'cancel': '取消',
      'export': '导出',
      'copy': '复制',
      'copied': '已复制!',
      'send': '发送',
      'type_message': '输入消息...',
      'chat_greeting': '您好! 我是您的银行助手。我能帮什么忙?',
      'chat_reply_1': '谢谢您的留言! 我会帮助您。',
      'chat_reply_card': '关于卡问题，请进入"卡片"并选择您的卡。',
      'chat_reply_loan': '关于贷款，请进入"贷款"并填写信息。',
      'chat_reply_fee': '应用内转账不收取费用。',
      'chat_reply_help': '我会为您连接客服。请稍候...',
      'chat_reply_thanks': '不客气! 还有其他需要吗?',
      'chat_contact': '直接联系',
      'chat_email': 'support@loanbanking.com',
      'chat_phone': '023 000 000',
    },
  };

  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    current = sp.getString('premium_language_v1') ?? 'km';
  }

  static Future<void> setLanguage(String code) async {
    current = code;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('premium_language_v1', code);
  }

  static String t(String key) =>
      translations[current]?[key] ?? translations['en']?[key] ?? key;
}

// ============================================================
//  PREMIUM STATE
// ============================================================
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage(this.text, this.isUser, this.time);
}

class PremiumState extends ChangeNotifier {
  Color accent = ThemeService.accent;
  String language = LocaleService.current;
  List<ChatMessage> chat = [];

  Future<void> bootstrap() async {
    await ThemeService.load();
    await LocaleService.load();
    accent = ThemeService.accent;
    language = LocaleService.current;
    chat = [
      ChatMessage(LocaleService.t('chat_greeting'), false, DateTime.now()),
    ];
    notifyListeners();
  }

  Future<void> setAccent(Color c) async {
    accent = c;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('premium_accent_v1', c.toARGB32());
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    await LocaleService.setLanguage(code);
    language = code;
    chat = [
      ChatMessage(LocaleService.t('chat_greeting'), false, DateTime.now()),
    ];
    notifyListeners();
  }

  String t(String key) => LocaleService.t(key);

  Future<void> sendMessage(String text) async {
    chat.add(ChatMessage(text, true, DateTime.now()));
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    String reply;
    final lower = text.toLowerCase();
    if (lower.contains('card') || lower.contains('កាត')) {
      reply = t('chat_reply_card');
    } else if (lower.contains('loan') || lower.contains('កម្ចី')) {
      reply = t('chat_reply_loan');
    } else if (lower.contains('fee') || lower.contains('ថ្លៃ')) {
      reply = t('chat_reply_fee');
    } else if (lower.contains('help') ||
        lower.contains('agent') ||
        lower.contains('ជំនួយ')) {
      reply = t('chat_reply_help');
    } else if (lower.contains('thank') || lower.contains('អរគុណ')) {
      reply = t('chat_reply_thanks');
    } else if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('សួស្តី')) {
      reply = t('chat_greeting');
    } else {
      reply = t('chat_reply_1');
    }

    chat.add(ChatMessage(reply, false, DateTime.now()));
    notifyListeners();
  }
}

final PremiumState premium = PremiumState();

// ============================================================
//  THEME CUSTOMIZATION SCREEN
// ============================================================
class ThemeCustomizationScreen extends StatelessWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: premium,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(premium.t('theme_title'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(premium.t('theme_desc'),
                  style: TextStyle(fontSize: 14, color: context.muted)),
              const SizedBox(height: 24),

              // Preview card
              NeuBox(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PREVIEW',
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.muted, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Text('\$18,400.00',
                        style: TextStyle(fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: premium.accent)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: premium.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up,
                                  color: premium.accent, size: 14),
                              const SizedBox(width: 4),
                              Text('+2.4%',
                                  style: TextStyle(
                                      color: premium.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: premium.accent,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Button',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Choose Color',
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: context.ink)),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  for (var i = 0;
                      i < ThemeService.availableColors.length;
                      i++)
                    GestureDetector(
                      onTap: () => premium.setAccent(
                          ThemeService.availableColors[i]),
                      child: Column(children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: ThemeService.availableColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: premium.accent ==
                                      ThemeService.availableColors[i]
                                  ? context.ink
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: ThemeService.availableColors[i]
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: premium.accent ==
                                  ThemeService.availableColors[i]
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 28)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(ThemeService.colorNames[i],
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.ink)),
                      ]),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              NeuBox(
                inset: true,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.info_outline, color: premium.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ពណ៌នេះនឹងអនុវត្តលើ Premium Features។ '
                      'សម្រាប់ full app ត្រូវកែ main.dart',
                      style: TextStyle(fontSize: 12,
                          color: context.muted, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
}

// ============================================================
//  LANGUAGE SCREEN
// ============================================================
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: premium,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(premium.t('language_title'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(premium.t('language_desc'),
                  style: TextStyle(fontSize: 14, color: context.muted)),
              const SizedBox(height: 24),
              for (final code in LocaleService.languageNames.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NeuBox(
                    padding: const EdgeInsets.all(16),
                    onTap: () => premium.setLanguage(code),
                    child: Row(children: [
                      Text(LocaleService.languageFlags[code]!,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(LocaleService.languageNames[code]!,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.ink)),
                            Text(code == 'km'
                                    ? 'Khmer'
                                    : code == 'en'
                                        ? 'English'
                                        : 'Chinese',
                                style: TextStyle(
                                    fontSize: 12, color: context.muted)),
                          ],
                        ),
                      ),
                      if (premium.language == code)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: premium.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 18),
                        ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      );
}

// ============================================================
//  CSV EXPORT
// ============================================================
class ExportDataScreen extends StatelessWidget {
  const ExportDataScreen({super.key});

  String _buildCsv() {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final buf = StringBuffer();
    buf.writeln('Date,Title,Category,Amount,Type');
    for (final t in bank.txs) {
      final amount = '${t.isExpense ? "-" : "+"}${t.amount.toStringAsFixed(2)}';
      final type = t.isExpense ? 'Expense' : 'Income';
      final title = t.title.replaceAll(',', ' ');
      buf.writeln('${dateFmt.format(t.time)},$title,${t.category},$amount,$type');
    }
    return buf.toString();
  }

  Future<void> _showCsv(BuildContext context) async {
    final csv = _buildCsv();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('CSV Data',
            style: TextStyle(color: ctx.ink, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ctx.shadowDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(
                        fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('${bank.txs.length} rows',
                  style: TextStyle(fontSize: 11, color: ctx.muted)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(premium.t('cancel'),
                  style: TextStyle(color: ctx.muted))),
          TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csv));
                Navigator.pop(ctx);
                toast(context, premium.t('copied'));
              },
              child: Text(premium.t('copy'),
                  style: TextStyle(color: premium.accent,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: premium,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(premium.t('csv_title'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NeuBox(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: premium.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: Icon(Icons.file_download,
                        color: premium.accent, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(premium.t('csv_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13,
                          color: context.muted, height: 1.4)),
                  const SizedBox(height: 16),
                  Text('${bank.txs.length} ${premium.language == "km" ? "ប្រតិបត្តិការ" : premium.language == "zh" ? "交易" : "transactions"}',
                      style: TextStyle(fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.ink)),
                ]),
              ),
              const SizedBox(height: 20),
              NeuButton(
                  label: premium.t('export'),
                  icon: Icons.download,
                  onPressed: () => _showCsv(context)),
              const SizedBox(height: 12),
              Text(
                premium.language == 'km'
                    ? 'ចម្លងទិន្នន័យ CSV ដើម្បីបើកក្នុង Excel/Google Sheets'
                    : premium.language == 'zh'
                        ? '复制CSV数据以在Excel/Google Sheets中打开'
                        : 'Copy CSV data to open in Excel/Google Sheets',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: context.muted),
              ),
            ],
          ),
        ),
      );
}

// ============================================================
//  SUPPORT CHAT
// ============================================================
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});
  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    premium.sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: premium,
        builder: (_, __) => Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: premium.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Icon(Icons.support_agent,
                    color: premium.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(premium.t('chat_title'),
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.ink)),
                  Row(children: [
                    Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: C.accentGreen,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Online',
                        style: TextStyle(fontSize: 10,
                            color: context.muted)),
                  ]),
                ],
              ),
            ]),
            actions: [
              IconButton(
                  icon: const Icon(Icons.email_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: premium.t('chat_email')));
                    toast(context, premium.t('copied'));
                  }),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: premium.chat.length,
                itemBuilder: (_, i) {
                  final m = premium.chat[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: m.isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!m.isUser) ...[
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: premium.accent,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.support_agent,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: m.isUser ? premium.accent : context.bg,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(
                                    m.isUser ? 16 : 4),
                                bottomRight: Radius.circular(
                                    m.isUser ? 4 : 16),
                              ),
                              boxShadow: m.isUser
                                  ? null
                                  : [
                                      BoxShadow(
                                          color: context.shadowLight,
                                          offset: const Offset(-2, -2),
                                          blurRadius: 6),
                                      BoxShadow(
                                          color: context.shadowDark,
                                          offset: const Offset(2, 2),
                                          blurRadius: 6),
                                    ],
                            ),
                            child: Text(m.text,
                                style: TextStyle(
                                    color: m.isUser
                                        ? Colors.white
                                        : context.ink,
                                    fontSize: 13.5,
                                    height: 1.4)),
                          ),
                        ),
                        if (m.isUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: context.bg,
                                shape: BoxShape.circle),
                            child: Icon(Icons.person,
                                color: premium.accent, size: 18),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: context.bg, boxShadow: [
                BoxShadow(
                    color: context.shadowLight,
                    offset: const Offset(0, -2),
                    blurRadius: 8),
                BoxShadow(
                    color: context.shadowDark,
                    offset: const Offset(0, -1),
                    blurRadius: 4),
              ]),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Expanded(
                    child: NeuField(
                      controller: _ctrl,
                      label: premium.t('type_message'),
                      icon: Icons.chat_bubble_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                          color: premium.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      );
}

// ============================================================
//  PREMIUM PROFILE MENU
// ============================================================
class PremiumProfileMenu extends StatelessWidget {
  const PremiumProfileMenu({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: premium,
        builder: (_, __) => Column(children: [
          ListTile(
            leading: Icon(Icons.palette_outlined, color: premium.accent),
            title: const Text('Theme Color'),
            trailing: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                  color: premium.accent, shape: BoxShape.circle),
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ThemeCustomizationScreen())),
          ),
          ListTile(
            leading: Icon(Icons.language, color: premium.accent),
            title: const Text('Language'),
            trailing: Text(
              LocaleService.languageFlags[premium.language] ?? '',
              style: const TextStyle(fontSize: 20),
            ),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LanguageScreen())),
          ),
          ListTile(
            leading: Icon(Icons.download_outlined, color: premium.accent),
            title: const Text('Export Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportDataScreen())),
          ),
          ListTile(
            leading: Icon(Icons.support_agent, color: premium.accent),
            title: const Text('Support Chat'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportChatScreen())),
          ),
        ]),
      );
}