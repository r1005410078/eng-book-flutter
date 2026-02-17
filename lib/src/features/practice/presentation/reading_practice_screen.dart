import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/routes.dart';
import '../application/local_course_provider.dart';
import '../data/local_course_package_loader.dart';
import '../data/mock_data.dart';
import '../domain/sentence_detail.dart';

class ReadingPracticeScreen extends ConsumerStatefulWidget {
  final String sentenceId;
  final String? packageRoot;
  final String? courseTitle;

  const ReadingPracticeScreen({
    super.key,
    required this.sentenceId,
    this.packageRoot,
    this.courseTitle,
  });

  @override
  ConsumerState<ReadingPracticeScreen> createState() =>
      _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends ConsumerState<ReadingPracticeScreen> {
  // Theme constants
  static const Color bgColor = Color(0xFF1a120b); // Dark brown/black
  static const Color accentColor = Color(0xFFFF9F29); // Orange
  static const Color activeCardColor =
      Color(0xFF2C241B); // Slightly lighter brown

  List<SentenceDetail> _sentences = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _loadWarning;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeSentences();
  }

  Future<void> _initializeSentences() async {
    const definedRoot = String.fromEnvironment(
      'COURSE_PACKAGE_DIR',
      defaultValue: '',
    );
    final discoveredRoot = await discoverLatestReadyPackageRoot();
    final providerRoot = ref.read(localCourseContextProvider)?.packageRoot;
    final packageRoot = widget.packageRoot ??
        providerRoot ??
        (definedRoot.isNotEmpty ? definedRoot : discoveredRoot ?? '');
    final courseTitle =
        widget.courseTitle ?? ref.read(localCourseContextProvider)?.courseTitle;

    if (packageRoot.isNotEmpty) {
      ref.read(localCourseContextProvider.notifier).state = LocalCourseContext(
        packageRoot: packageRoot,
        courseTitle: courseTitle,
      );
    }

    final loaded = await ref.read(localCourseSentencesProvider.future);
    var list = loaded.sentences;
    var warning = loaded.warning;

    if (list.isEmpty) {
      list = mockSentences;
      warning ??= '本地课程包未就绪，已回退到默认内容。';
    }

    final index = list.indexWhere((s) => s.id == widget.sentenceId);

    if (!mounted) return;
    setState(() {
      _sentences = list;
      _currentIndex = index != -1 ? index : 0;
      _isLoading = false;
      _loadWarning = warning;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
    });
  }

  void _scrollToCurrent() {
    // Basic approximation play
    if (_currentIndex > 0 && _scrollController.hasClients) {
      // Estimate height ~ 100 per item
      double offset = (_currentIndex - 1) * 100.0;
      if (offset < 0) offset = 0;
      _scrollController.animateTo(offset,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: _buildFloatingControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),

          // Center: Title + Progress (Optional, as big title is in body)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Maybe hide title here to match design more closely, or keep minimal info
              Text(
                "第 ${_currentIndex + 1} / ${_sentences.length} 句",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),

          // Right: Settings Icon
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
            onPressed: () {
              context.push(Routes.playbackSettings);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: accentColor),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding:
          const EdgeInsets.only(bottom: 120), // Space for floating controls
      itemCount: _sentences.length + 1, // +1 for the top tags
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildListHeader();
        }
        final sentenceIndex = index - 1;
        final sentence = _sentences[sentenceIndex];
        final isActive = sentenceIndex == _currentIndex;

        if (isActive) {
          return _buildActiveCard(sentence, sentenceIndex);
        } else {
          return _buildInactiveRow(sentence, sentenceIndex);
        }
      },
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "CHAPTER 1",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "TRANSCRIPT",
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "The Reunion",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Listen to the conversation and practice speaking.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          if (_loadWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _loadWarning!,
                style: TextStyle(
                  color: Colors.amber.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInactiveRow(SentenceDetail sentence, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: Colors.transparent, // Hit test
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Icon & Reps
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  index % 3 == 0 // Mock Logic: some are checked
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withOpacity(0.1),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.check,
                              color: accentColor, size: 14),
                        )
                      : Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "0", // Or empty if it just means not started
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 10),
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    index % 3 == 0 ? "3x" : "0x",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sentence.text,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sentence.translation,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Mini Play Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCard(SentenceDetail sentence, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: activeCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          // Glow effect
          BoxShadow(
            color: accentColor.withOpacity(0.35),
            blurRadius: 25,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Custom Reps + Bookmark
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                // Custom bars
                Row(
                  children: List.generate(
                      4,
                      (i) => Container(
                            width: 10,
                            height: 4,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                                color: i < 2
                                    ? accentColor
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(2)),
                          )),
                ),
                const SizedBox(width: 8),
                const Text(
                  "2/5 REPS",
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Icon(Icons.bookmark, color: accentColor, size: 20),
              ],
            ),
          ),

          // Main Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.5,
                ),
                children: _buildHighlightedText(sentence.text),
              ),
            ),
          ),

          _buildGrammarUsageHints(sentence),

          // Footer: Visualizer + Translation
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        6,
                        (i) => Container(
                              width: 3,
                              height: 8.0 + (i % 3) * 6,
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            )),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    sentence.translation,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildHighlightedText(String text) {
    if (text.contains("all this time")) {
      final parts = text.split("all this time");
      return [
        TextSpan(text: parts[0]),
        const TextSpan(
          text: "all this time",
          style: TextStyle(
            color: accentColor,
            decoration: TextDecoration.underline,
            decorationColor: accentColor,
            decorationStyle: TextDecorationStyle.solid,
            decorationThickness: 2,
          ),
        ),
        if (parts.length > 1) TextSpan(text: parts[1]),
      ];
    }
    return [TextSpan(text: text)];
  }

  Widget _buildGrammarUsageHints(SentenceDetail sentence) {
    if (sentence.grammarNotes.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = sentence.grammarNotes.entries.take(2).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries
            .map(
              (e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Center(
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF2C241B).withOpacity(0.95), // Card color
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Prev
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              onPressed: () {
                if (_currentIndex > 0) setState(() => _currentIndex--);
              },
            ),
            // Replay
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: () {
                // Replay logic
              },
            ),
            // Big Mic Button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white),
            ),
            // Auto Play
            IconButton(
              icon: const Icon(Icons.play_circle_outline, color: Colors.grey),
              onPressed: () {
                // Auto play logic
              },
            ),
            // Next
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.grey),
              onPressed: () {
                if (_currentIndex < _sentences.length - 1)
                  setState(() => _currentIndex++);
              },
            ),
          ],
        ),
      ),
    );
  }
}
