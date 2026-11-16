import 'package:flutter/material.dart';
import 'core/i18n/app_strings.dart';
import 'features/audio/procedural_sound_engine.dart';
import 'features/focus/focus_timer_controller.dart';
import 'features/flashcards/fsrs_engine.dart';
import 'features/flashcards/flashcard_manager.dart';
import 'features/studios/studios_catalog.dart';
import 'features/analytics/analytics_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusStudioProApp());
}

class FocusStudioProApp extends StatefulWidget {
  const FocusStudioProApp({super.key});

  @override
  State<FocusStudioProApp> createState() => _FocusStudioProAppState();
}

class _FocusStudioProAppState extends State<FocusStudioProApp> {
  String _langCode = 'ar';
  bool _darkMode = false;

  void _toggleLanguage() {
    setState(() {
      _langCode = (_langCode == 'ar') ? 'en' : 'ar';
    });
  }

  void _toggleTheme() {
    setState(() {
      _darkMode = !_darkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.forLanguage(_langCode);
    final dir = strings.isRtl ? TextDirection.rtl : TextDirection.ltr;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: strings.tr('app_title'),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B5BDB),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4C6EF5),
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: dir,
        child: HomeShellScreen(
          strings: strings,
          darkMode: _darkMode,
          onToggleLanguage: _toggleLanguage,
          onToggleTheme: _toggleTheme,
        ),
      ),
    );
  }
}

class HomeShellScreen extends StatefulWidget {
  final AppStrings strings;
  final bool darkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  const HomeShellScreen({
    super.key,
    required this.strings,
    required this.darkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedIndex = 0;
  final FocusTimerController _timerController = FocusTimerController();
  final ProceduralSoundEngine _soundEngine = ProceduralSoundEngine();
  final Fsrs45Engine _fsrsEngine = const Fsrs45Engine();

  String _searchQuery = '';
  bool _showQuestionOnly = true;
  int _activeCardIndex = 0;

  final List<Map<String, String>> _sampleCards = [
    {
      'word': 'sich erinnern an + Akk',
      'translation': 'يتذكر (فعل انعكاسي يأخذ حالة النصب)',
      'example': 'Ich erinnere mich gut an diesen Tag.',
      'notes': 'A2 German Reflexive Verb',
    },
    {
      'word': 'الْعِلْمُ نُورٌ',
      'translation': 'Knowledge is light / Wissen ist Licht',
      'example': 'طَلَبُ الْعِلْمِ فَرِيضَةٌ',
      'notes': 'Supports Arabic diacritic-insensitive search',
    },
  ];

  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Complete German A2 Reflexive Verbs Deck', 'done': false},
    {'title': 'Deep Work 50m Architecture Session', 'done': true},
  ];

  final List<Map<String, String>> _notes = [
    {
      'title': 'Feynman Technique Summary',
      'body': '1. Study concept  2. Teach simply  3. Identify gaps  4. Refine.',
    },
  ];

  void _openStudiosSheet() {
    final isAr = widget.strings.languageCode == 'ar';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: StudiosCatalog.all10Studios.length,
              itemBuilder: (_, idx) {
                final st = StudiosCatalog.all10Studios[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${idx + 1}')),
                    title: Text(
                      isAr ? st.titleAr : st.titleEn,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(isAr ? st.subtitleAr : st.subtitleEn),
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    // SafeArea is combined with MainActivity WindowInsetsCompat.Type.systemBars()
    // and studios menu lives cleanly in the top AppBar (zero floating pill overlap).
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.tr('app_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              s.tr('subtitle'),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          FilledButton.tonalIcon(
            key: const Key('studios_header_btn'),
            onPressed: _openStudiosSheet,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(s.tr('studios_menu')),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const Key('lang_toggle_btn'),
            tooltip: 'Language',
            onPressed: widget.onToggleLanguage,
            icon: Text(
              s.languageCode.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            key: const Key('theme_toggle_btn'),
            tooltip: 'Theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.darkMode ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildFocusTab(s),
            _buildFlashcardsTab(s),
            _buildSoundsTab(s),
            _buildTasksAndNotesTab(s),
            _buildAnalyticsTab(s),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.timer_outlined),
              selectedIcon: const Icon(Icons.timer),
              label: s.tr('tab_focus'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.style_outlined),
              selectedIcon: const Icon(Icons.style),
              label: s.tr('tab_flashcards'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.graphic_eq_outlined),
              selectedIcon: const Icon(Icons.graphic_eq),
              label: s.tr('tab_sounds'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.check_circle_outline),
              selectedIcon: const Icon(Icons.check_circle),
              label: s.tr('tab_tasks'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: s.tr('tab_analytics'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusTab(AppStrings s) {
    final st = _timerController.state;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('10:00'),
                      selected: st.workSeconds == 600,
                      onSelected: (_) => setState(() {
                        _timerController.configureCustom(
                          sets: 4,
                          workSeconds: 600,
                          restSeconds: 120,
                        );
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('25:00'),
                      selected: st.workSeconds == 1500,
                      onSelected: (_) => setState(() {
                        _timerController.configureCustom(
                          sets: 4,
                          workSeconds: 1500,
                          restSeconds: 300,
                        );
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('50:00'),
                      selected: st.workSeconds == 3000,
                      onSelected: (_) => setState(() {
                        _timerController.configureCustom(
                          sets: 2,
                          workSeconds: 3000,
                          restSeconds: 600,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  st.formattedWesternClock,
                  key: const Key('focus_clock_text'),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${s.tr('sets_label')}: ${st.currentSet} / ${st.totalSets}'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const Key('start_pause_focus_btn'),
                      onPressed: () => setState(() {
                        if (st.isRunning) {
                          _timerController.pause();
                        } else {
                          _timerController.start();
                        }
                      }),
                      icon: Icon(st.isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(st.isRunning ? s.tr('pause_focus') : s.tr('start_focus')),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(_timerController.reset),
                      icon: const Icon(Icons.refresh),
                      label: Text(s.tr('reset_focus')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlashcardsTab(AppStrings s) {
    final filtered = _sampleCards.where((c) {
      return FlashcardTextUtils.matchesArabicInsensitive(
        '${c['word']} ${c['translation']} ${c['example']}',
        _searchQuery,
      );
    }).toList();

    final currentCard = filtered.isNotEmpty
        ? filtered[_activeCardIndex % filtered.length]
        : _sampleCards.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TextField(
          key: const Key('flashcards_search_input'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: s.tr('search_cards_hint'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() {
            _searchQuery = v;
            _activeCardIndex = 0;
          }),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: InkWell(
            onTap: () => setState(() => _showQuestionOnly = !_showQuestionOnly),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.tr('fsrs_review_title'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentCard['word'] ?? '',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  if (!_showQuestionOnly) ...[
                    const Divider(height: 28),
                    Text(
                      currentCard['translation'] ?? '',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentCard['example'] ?? '',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentCard['notes'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final item in [
              (FsrsRating.again, s.tr('rating_again')),
              (FsrsRating.hard, s.tr('rating_hard')),
              (FsrsRating.good, s.tr('rating_good')),
              (FsrsRating.easy, s.tr('rating_easy')),
            ])
              FilledButton.tonal(
                onPressed: () {
                  _fsrsEngine.review(
                    current: FsrsCardState.initial(DateTime.now().toUtc()),
                    rating: item.$1,
                    reviewedAtUtc: DateTime.now().toUtc(),
                  );
                  setState(() {
                    _activeCardIndex = (_activeCardIndex + 1) % _sampleCards.length;
                    _showQuestionOnly = true;
                  });
                },
                child: Text(item.$2),
              ),
          ],
        ),
      ],
    );
  }

  /// Sounds Tab: Nature Sounds are placed at the VERY TOP for immediate access without scrolling;
  /// 3D Spatial Audio & Bio-Frequencies is collapsed by default below them.
  Widget _buildSoundsTab(AppStrings s) {
    final isAr = s.languageCode == 'ar';
    final naturePresets = AmbientSoundPreset.values
        .where((p) => p.category != 'spatial')
        .toList();
    final spatialPresets = AmbientSoundPreset.values
        .where((p) => p.category == 'spatial')
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Chip(
                avatar: const Icon(Icons.verified_user, size: 16),
                label: Text(s.tr('zero_hiss_badge')),
              ),
            ),
            if (_soundEngine.isPlaying)
              FilledButton.icon(
                key: const Key('stop_all_sounds_btn'),
                onPressed: () => setState(_soundEngine.stopAll),
                icon: const Icon(Icons.stop),
                label: Text(s.tr('stop_all_audio')),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          s.tr('nature_sounds_top'),
          key: const Key('nature_sounds_header'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final preset in naturePresets)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.spa_outlined),
              title: Text(isAr ? preset.titleAr : preset.titleEn),
              subtitle: Slider(
                value: _soundEngine.activeMixVolumes[preset] ?? 0.0,
                onChanged: (v) => setState(() {
                  _soundEngine.setPresetVolume(preset, v);
                }),
              ),
              trailing: Text(
                '${((_soundEngine.activeMixVolumes[preset] ?? 0.0) * 100).round()}%',
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            key: const Key('spatial_audio_expansion'),
            initiallyExpanded: false,
            leading: const Icon(Icons.spatial_audio_off),
            title: Text(
              s.tr('spatial_audio_collapsible'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              for (final sp in spatialPresets)
                ListTile(
                  title: Text(isAr ? sp.titleAr : sp.titleEn),
                  subtitle: Slider(
                    value: _soundEngine.activeMixVolumes[sp] ?? 0.0,
                    onChanged: (v) => setState(() {
                      _soundEngine.setPresetVolume(sp, v);
                    }),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksAndNotesTab(AppStrings s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          s.tr('tab_tasks'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _tasks.length; i++)
          Card(
            child: CheckboxListTile(
              value: _tasks[i]['done'] as bool,
              title: Text(_tasks[i]['title'] as String),
              onChanged: (v) => setState(() => _tasks[i]['done'] = v ?? false),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          s.tr('notes_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final note in _notes)
          Card(
            child: ListTile(
              title: Text(
                note['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(note['body'] ?? ''),
            ),
          ),
      ],
    );
  }

  Widget _buildAnalyticsTab(AppStrings s) {
    final summary = AnalyticsEngine.computeSummary(
      cardStates: [FsrsCardState.initial(DateTime.now().toUtc())],
      focusSessionDurationsSeconds: const [1500, 3000],
      referenceNowUtc: DateTime.now().toUtc(),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          s.tr('analytics_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${summary.recordedFocusMinutes}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const Text('Minutes'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${summary.averageRetentionPercent}%',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const Text('FSRS Retention'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(s.tr('forecast_30d')),
            subtitle: Text('Due Today: ${summary.next30DaysWorkload.first} cards'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.enhanced_encryption),
            title: Text(s.tr('encrypted_backup')),
            subtitle: Text(s.tr('export_csv')),
          ),
        ),
      ],
    );
  }
}
