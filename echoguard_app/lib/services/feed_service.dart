import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/feed_models.dart';
import '../models/analysis_result.dart';
import 'storage_service.dart';

class FeedService {
  // Fetch from Google News World RSS feed
  static const String _newsRssUrl = 'https://news.google.com/rss/search?q=when:12h&hl=en-US&gl=US&ceid=US:en';

  /// Pre-loaded dummy community blogs shown until users create their own
  static List<BlogPost> get _dummyBlogs => [
    BlogPost(
      id: 'dummy_1',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      author: '@FactHunter',
      content: 'NASA confirms that a new Earth-like planet has been discovered just 40 light-years away, with conditions potentially suitable for human habitation.',
      analysis: AnalysisResult(
        credibility: 72,
        fakeProbability: 28,
        manipulation: ManipulationData(level: 'LOW', emotion: 'excitement', intensity: 35, keywords: ['NASA', 'Earth-like', 'habitation']),
        bias: BiasData(leaning: 'NEUTRAL', confidence: 80, propagandaFlag: false),
        sourceReliability: SourceReliability(level: 'HIGH', score: 85, domain: 'nasa.gov'),
        clickbait: ClickbaitData(isClickbait: false, probability: 15),
        balancedViews: ['NASA has confirmed exoplanet discoveries in recent years', 'Habitation claims often overstated in media'],
        aiReasoning: 'NASA regularly discovers exoplanets via the TESS and James Webb missions. While the 40 light-year proximity is plausible, claims of "suitable for human habitation" typically overstate the findings. The core discovery is verified but the framing is slightly sensationalized.',
      ),
      comments: [
        Comment(id: 'c1', author: '@SpaceNerd', text: 'This is incredible if true! JWST has been on fire lately.', timestamp: DateTime.now().subtract(const Duration(hours: 1))),
        Comment(id: 'c2', author: '@Skeptic101', text: 'They say this every year. "Earth-like" is a huge stretch.', timestamp: DateTime.now().subtract(const Duration(minutes: 30))),
      ],
    ),
    BlogPost(
      id: 'dummy_2',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      author: '@CryptoWatch',
      content: 'Bitcoin crashes 40% overnight after major exchange hack drains \$2 billion in user funds.',
      analysis: AnalysisResult(
        credibility: 25,
        fakeProbability: 75,
        manipulation: ManipulationData(level: 'HIGH', emotion: 'fear', intensity: 82, keywords: ['crashes', 'hack', 'drains']),
        bias: BiasData(leaning: 'SENSATIONAL', confidence: 90, propagandaFlag: true),
        sourceReliability: SourceReliability(level: 'LOW', score: 20, domain: 'unknown'),
        clickbait: ClickbaitData(isClickbait: true, probability: 88),
        balancedViews: ['No major exchange has reported a \$2B hack recently', 'Bitcoin volatility is common but 40% overnight is extreme'],
        aiReasoning: 'No credible financial news source has reported a 40% Bitcoin crash or a \$2 billion exchange hack. This appears to be fabricated panic-inducing content designed to manipulate crypto markets or generate clicks.',
      ),
      comments: [
        Comment(id: 'c3', author: '@HODLer', text: 'Checked CoinGecko, BTC is fine. This is fake.', timestamp: DateTime.now().subtract(const Duration(hours: 4))),
      ],
    ),
    BlogPost(
      id: 'dummy_3',
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      author: '@HealthMatters',
      content: 'WHO announces a new global health initiative to provide free mental health support across 120 countries by 2027.',
      analysis: AnalysisResult(
        credibility: 82,
        fakeProbability: 18,
        manipulation: ManipulationData(level: 'LOW', emotion: 'neutral', intensity: 15, keywords: ['WHO', 'mental health', 'global']),
        bias: BiasData(leaning: 'NEUTRAL', confidence: 85, propagandaFlag: false),
        sourceReliability: SourceReliability(level: 'HIGH', score: 90, domain: 'who.int'),
        clickbait: ClickbaitData(isClickbait: false, probability: 10),
        balancedViews: ['WHO has been expanding mental health coverage', 'Implementation across 120 countries may face logistical challenges'],
        aiReasoning: 'The WHO has indeed been ramping up its mental health programs globally. While the specific "120 countries by 2027" figure requires verification through official WHO channels, the general direction of this claim aligns with known WHO policy.',
      ),
      comments: [],
    ),
    BlogPost(
      id: 'dummy_4',
      timestamp: DateTime.now().subtract(const Duration(hours: 12)),
      author: '@TechInsider',
      content: 'Apple is secretly developing a brain-computer interface that will be embedded in the next generation of AirPods, sources say.',
      analysis: AnalysisResult(
        credibility: 32,
        fakeProbability: 68,
        manipulation: ManipulationData(level: 'MEDIUM', emotion: 'excitement', intensity: 60, keywords: ['secretly', 'brain-computer', 'Apple']),
        bias: BiasData(leaning: 'SENSATIONAL', confidence: 75, propagandaFlag: false),
        sourceReliability: SourceReliability(level: 'LOW', score: 30, domain: 'unverified'),
        clickbait: ClickbaitData(isClickbait: true, probability: 78),
        balancedViews: ['Apple has patents on health-monitoring AirPods features', 'Brain-computer interface in consumer AirPods is far-fetched with current tech'],
        aiReasoning: 'While Apple has explored health-monitoring features in AirPods (heart rate, posture), a full brain-computer interface in consumer earbuds is not technically feasible with current neurotechnology. No credible Apple leak channels have reported this. Highly speculative.',
      ),
      comments: [
        Comment(id: 'c4', author: '@AppleFan', text: 'I want to believe this but it sounds way too sci-fi for now.', timestamp: DateTime.now().subtract(const Duration(hours: 10))),
        Comment(id: 'c5', author: '@Neuroscientist', text: 'BCI in earbuds? We are decades away from that level of miniaturization.', timestamp: DateTime.now().subtract(const Duration(hours: 9))),
      ],
    ),
    BlogPost(
      id: 'dummy_5',
      timestamp: DateTime.now().subtract(const Duration(hours: 18)),
      author: '@IndiaToday',
      content: 'Indian government set to launch a universal basic income pilot program covering 50 million citizens, starting next quarter.',
      analysis: AnalysisResult(
        credibility: 45,
        fakeProbability: 55,
        manipulation: ManipulationData(level: 'MEDIUM', emotion: 'excitement', intensity: 45, keywords: ['UBI', 'India', '50 million']),
        bias: BiasData(leaning: 'LEFT', confidence: 60, propagandaFlag: false),
        sourceReliability: SourceReliability(level: 'MEDIUM', score: 50, domain: 'mixed'),
        clickbait: ClickbaitData(isClickbait: false, probability: 30),
        balancedViews: ['India has run targeted cash-transfer pilots before', 'A 50 million scale UBI has not been officially announced'],
        aiReasoning: 'India has conducted various direct benefit transfer programs but a full-scale UBI for 50 million people has not been officially confirmed as of the latest reports. The claim mixes real policy trends with unverified scale and timeline.',
      ),
      comments: [
        Comment(id: 'c6', author: '@PolicyNerd', text: 'India does have DBT but "UBI" is a stretch. Different programs.', timestamp: DateTime.now().subtract(const Duration(hours: 16))),
      ],
    ),
    BlogPost(
      id: 'dummy_6',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      author: '@ClimateAction',
      content: 'Scientists confirm global average temperatures crossed 2°C above pre-industrial levels for the first time this month.',
      analysis: AnalysisResult(
        credibility: 58,
        fakeProbability: 42,
        manipulation: ManipulationData(level: 'MEDIUM', emotion: 'fear', intensity: 55, keywords: ['2°C', 'global warming', 'pre-industrial']),
        bias: BiasData(leaning: 'LEFT', confidence: 65, propagandaFlag: false),
        sourceReliability: SourceReliability(level: 'MEDIUM', score: 60, domain: 'climate sources'),
        clickbait: ClickbaitData(isClickbait: false, probability: 25),
        balancedViews: ['Temporary spikes above 2°C have occurred but sustained average has not', 'Climate data requires distinction between daily spikes and annual averages'],
        aiReasoning: 'While temporary daily or monthly spikes above 2°C have been recorded, the sustained global annual average has not yet permanently crossed the 2°C threshold. This claim conflates a short-term spike with a permanent trend, which is misleading but rooted in real climate concern.',
      ),
      comments: [],
    ),
  ];

  static Future<List<FeedItem>> getUnifiedFeed() async {
    final List<FeedItem> unified = [];

    // 1. Load Local Community Blogs
    await StorageService.loadBlogs();
    final blogs = StorageService.getBlogs();
    unified.addAll(blogs);

    // 2. Add dummy blogs if user hasn't created any yet
    if (blogs.isEmpty) {
      unified.addAll(_dummyBlogs);
    }

    // 3. Fetch Live News
    try {
      final response = await http.get(Uri.parse(_newsRssUrl));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item').take(15);

        for (final item in items) {
          final title = item.findElements('title').firstOrNull?.innerText ?? 'News Update';
          final link = item.findElements('link').firstOrNull?.innerText ?? '';
          final source = item.findElements('source').firstOrNull?.innerText ?? 'Google News';

          unified.add(
            NewsItem(
              id: link,
              timestamp: DateTime.now(),
              title: title,
              source: source,
              url: link,
              description: '',
            ),
          );
        }
      }
    } catch (e) {
      print('Failed to fetch news feed: $e');
    }

    // 4. Sort by timestamp descending
    unified.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return unified;
  }
}
