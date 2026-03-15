import 'language_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
//  AppStrings — All user-visible text in English & Hindi
// ═══════════════════════════════════════════════════════════════════════
//
//  Usage:  S.get('home')  →  'HOME' or 'होम'
//  Add new keys at the bottom of _strings as needed.
// ═══════════════════════════════════════════════════════════════════════

class S {
  static String get(String key) {
    final lang = LanguageProvider.instance.language;
    return _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    // ── Bottom Navigation ──
    'home':          {'en': 'HOME',          'hi': 'होम'},
    'mira':          {'en': 'MIRA',          'hi': 'मीरा'},
    'scan':          {'en': 'SCAN',          'hi': 'स्कैन'},
    'history':       {'en': 'HISTORY',       'hi': 'इतिहास'},
    'profile':       {'en': 'PROFILE',       'hi': 'प्रोफ़ाइल'},

    // ── Home Screen ──
    'app_title':     {'en': 'Veritas',       'hi': 'वेरिटास'},
    'paste_text':    {'en': 'Paste text or URL to fact-check...', 'hi': 'तथ्य-जांच के लिए टेक्स्ट या लिंक पेस्ट करें...'},
    'analyze':       {'en': 'Analyze',       'hi': 'विश्लेषण'},
    'scan_photo':    {'en': 'Scan Photo',    'hi': 'फ़ोटो स्कैन'},
    'community':     {'en': 'Community Feed','hi': 'समुदाय फ़ीड'},
    'trending':      {'en': 'Trending',      'hi': 'ट्रेंडिंग'},
    'latest':        {'en': 'Latest',        'hi': 'नवीनतम'},
    'no_text_error': {'en': 'Please paste some text or a link to analyze.', 'hi': 'कृपया विश्लेषण के लिए कोई टेक्स्ट या लिंक पेस्ट करें।'},
    'extracting':    {'en': 'Extracting text from image...', 'hi': 'छवि से टेक्स्ट निकाला जा रहा है...'},
    'image_fail':    {'en': 'Image analysis failed', 'hi': 'छवि विश्लेषण विफल'},

    // ── Chatbot / Mira ──
    'mira_greeting': {'en': 'Hello! I am Mira, your Veritas AI assistant. Ask me to fact-check any claim, news, or rumor!',
                      'hi': 'नमस्ते! मैं मीरा हूँ, आपकी वेरिटास AI सहायक। मुझसे किसी भी दावे, समाचार या अफवाह की तथ्य-जांच करवाएं!'},
    'mira_hello':    {'en': 'Hello! How can I help you today?', 'hi': 'नमस्ते! आज मैं आपकी कैसे मदद कर सकती हूँ?'},
    'mira_analyzing':{'en': 'Mira is analyzing...', 'hi': 'मीरा विश्लेषण कर रही है...'},
    'msg_mira':      {'en': 'Message Mira...', 'hi': 'मीरा को संदेश भेजें...'},
    'mira_error':    {'en': 'Oops, I hit a snag trying to analyze that', 'hi': 'उफ़, विश्लेषण में कुछ गड़बड़ हो गई'},
    'credibility':   {'en': 'Credibility Score', 'hi': 'विश्वसनीयता स्कोर'},
    'verdict':       {'en': 'Verdict', 'hi': 'निर्णय'},
    'latest_news':   {'en': 'Here is the latest popular news for you', 'hi': 'यहां आपके लिए ताज़ा लोकप्रिय समाचार हैं'},

    // ── Scan Screen ──
    'guardian_overlay':  {'en': 'Guardian Overlay',   'hi': 'गार्डियन ओवरले'},
    'guardian_active':   {'en': 'Guardian Bubble is ACTIVE — floating over your screen', 'hi': 'गार्डियन बबल सक्रिय है — आपकी स्क्रीन पर तैर रहा है'},
    'system_wide_fc':    {'en': 'System-Wide Fact Checking', 'hi': 'सिस्टम-वाइड तथ्य जांच'},
    'system_wide_desc':  {'en': 'A floating bubble appears over any app. Tap it to instantly scan and fact-check on-screen content.',
                          'hi': 'किसी भी ऐप पर एक फ़्लोटिंग बबल दिखाई देता है। स्क्रीन सामग्री को स्कैन और तथ्य-जांच करने के लिए इसे टैप करें।'},
    'required_perms':    {'en': 'Required Permissions', 'hi': 'आवश्यक अनुमतियां'},
    'floating_bubble':   {'en': 'Floating Bubble',    'hi': 'फ़्लोटिंग बबल'},
    'floating_bubble_desc': {'en': 'Allows Veritas to draw a hovering button over other apps.',
                             'hi': 'वेरिटास को अन्य ऐप्स पर एक होवरिंग बटन बनाने की अनुमति देता है।'},
    'screen_reader':     {'en': 'Screen Reader (Accessibility)', 'hi': 'स्क्रीन रीडर (एक्सेसिबिलिटी)'},
    'screen_reader_desc':{'en': 'Settings → Accessibility → Installed services → Enable Veritas.',
                          'hi': 'सेटिंग्स → एक्सेसिबिलिटी → इंस्टॉल की गई सेवाएं → वेरिटास चालू करें।'},
    'screen_reader_snack':{'en': '📱 Go to Settings → Accessibility → Installed Apps → Veritas → Turn ON',
                           'hi': '📱 सेटिंग्स → एक्सेसिबिलिटी → इंस्टॉल किए गए ऐप्स → वेरिटास → चालू करें'},
    'launch_guardian':   {'en': 'Launch Guardian Bubble', 'hi': 'गार्डियन बबल लॉन्च करें'},
    'stop_guardian':     {'en': 'Stop Guardian Bubble',   'hi': 'गार्डियन बबल बंद करें'},
    'how_to_access':     {'en': 'How to enable Accessibility', 'hi': 'एक्सेसिबिलिटी कैसे चालू करें'},
    'access_steps':      {'en': '1. Open your phone Settings\n2. Tap Accessibility\n3. Tap Installed apps / Downloaded apps\n4. Find Veritas and toggle it ON\n5. Come back here and tap Launch',
                          'hi': '1. अपने फ़ोन की सेटिंग्स खोलें\n2. एक्सेसिबिलिटी पर टैप करें\n3. इंस्टॉल किए गए ऐप्स पर टैप करें\n4. वेरिटास ढूंढें और चालू करें\n5. यहां वापस आएं और लॉन्च दबाएं'},
    'android_exclusive': {'en': 'Android Exclusive Feature', 'hi': 'केवल Android के लिए'},
    'android_exclusive_desc': {'en': 'The System-Wide Guardian Bubble requires native Android permissions (Draw Over Other Apps & Accessibility). Please install the APK on your Android device.',
                               'hi': 'सिस्टम-वाइड गार्डियन बबल के लिए Android अनुमतियां (अन्य ऐप्स पर ड्रा और एक्सेसिबिलिटी) आवश्यक हैं। कृपया APK को अपने Android डिवाइस पर इंस्टॉल करें।'},
    'scan_title':    {'en': 'Real-time Scan', 'hi': 'रियल-टाइम स्कैन'},
    'scan_desc':     {'en': 'Tap the button below to start the floating scanner that monitors your screen.',
                      'hi': 'फ़्लोटिंग स्कैनर शुरू करने के लिए नीचे बटन दबाएं।'},
    'start_scan':    {'en': 'Start Scanning', 'hi': 'स्कैनिंग शुरू करें'},
    'stop_scan':     {'en': 'Stop Scanning',  'hi': 'स्कैनिंग बंद करें'},
    'scanning':      {'en': 'Scanning...',    'hi': 'स्कैन हो रहा है...'},

    // ── History Screen ──
    'search_history':{'en': 'Search history...',   'hi': 'इतिहास खोजें...'},
    'no_history':    {'en': 'No history yet',        'hi': 'अभी कोई इतिहास नहीं'},
    'clear_all':     {'en': 'Clear All',             'hi': 'सब साफ करें'},

    // ── Profile Screen ──
    'recent_activity':{'en': 'Recent Activity',    'hi': 'हालिया गतिविधि'},
    'view_all':      {'en': 'View All',            'hi': 'सब देखें'},
    'preferences':   {'en': 'Preferences',         'hi': 'प्राथमिकताएं'},
    'language':      {'en': 'Language',            'hi': 'भाषा'},
    'dark_mode':     {'en': 'Dark Mode',           'hi': 'डार्क मोड'},
    'notifications': {'en': 'Notifications',       'hi': 'सूचनाएं'},
    'logout':        {'en': 'Logout',              'hi': 'लॉगआउट'},
    'joined':        {'en': 'Joined March 2026',   'hi': 'मार्च 2026 से जुड़े'},
    'elite_verifier':{'en': 'ELITE VERIFIER',      'hi': 'एलीट वेरिफायर'},
    'truth_score':   {'en': 'Truth Score',         'hi': 'सत्य स्कोर'},
    'verified':      {'en': 'Verified',            'hi': 'सत्यापित'},
    'accuracy':      {'en': 'Accuracy',            'hi': 'सटीकता'},
    'no_recent':     {'en': 'No recent activity',  'hi': 'कोई हालिया गतिविधि नहीं'},
    'hindi':         {'en': 'हिंदी',               'hi': 'हिंदी'},

    // ── Analysis Screen ──
    'analyzing':     {'en': 'Veritas is analyzing...', 'hi': 'वेरिटास विश्लेषण कर रहा है...'},
    'likely_true':   {'en': 'Likely True',         'hi': 'संभवतः सत्य'},
    'uncertain':     {'en': 'Uncertain',           'hi': 'अनिश्चित'},
    'likely_false':  {'en': 'Likely False',        'hi': 'संभवतः झूठ'},
    'ai_reasoning':  {'en': 'AI Reasoning',        'hi': 'AI तर्क'},
    'sources':       {'en': 'Balanced Sources',    'hi': 'संतुलित स्रोत'},
    'share':         {'en': 'Share',               'hi': 'साझा करें'},

    // ── Blog ──
    'add_comment':   {'en': 'Add a comment...',    'hi': 'टिप्पणी लिखें...'},
    'comments':      {'en': 'Comments',            'hi': 'टिप्पणियां'},
    'create_post':   {'en': 'Create Post',         'hi': 'पोस्ट बनाएं'},
  };
}
