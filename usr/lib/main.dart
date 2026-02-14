import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const PlacementApp());
}

class PlacementApp extends StatelessWidget {
  const PlacementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Placement Readiness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/results': (context) => const ResultsScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

class AnalysisResult {
  final String id;
  final DateTime createdAt;
  final String company;
  final String role;
  final String jdText;
  final Map<String, List<String>> extractedSkills;
  final List<String> checklist;
  final List<String> plan;
  final List<String> questions;
  final double baseScore;
  Map<String, String> skillConfidence; // "know" or "practice"

  AnalysisResult({
    required this.id,
    required this.createdAt,
    required this.company,
    required this.role,
    required this.jdText,
    required this.extractedSkills,
    required this.checklist,
    required this.plan,
    required this.questions,
    required this.baseScore,
    required this.skillConfidence,
  });

  double get currentScore {
    double score = baseScore;
    int knownCount = 0;
    int practiceCount = 0;

    skillConfidence.forEach((skill, status) {
      if (status == 'know') knownCount++;
      if (status == 'practice') practiceCount++;
    });

    score += (knownCount * 2);
    score -= (practiceCount * 2);

    return score.clamp(0.0, 100.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'company': company,
        'role': role,
        'jdText': jdText,
        'extractedSkills': extractedSkills,
        'checklist': checklist,
        'plan': plan,
        'questions': questions,
        'baseScore': baseScore,
        'skillConfidence': skillConfidence,
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
      company: json['company'],
      role: json['role'],
      jdText: json['jdText'],
      extractedSkills: (json['extractedSkills'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
      checklist: List<String>.from(json['checklist']),
      plan: List<String>.from(json['plan']),
      questions: List<String>.from(json['questions']),
      baseScore: (json['baseScore'] as num).toDouble(),
      skillConfidence: Map<String, String>.from(json['skillConfidence'] ?? {}),
    );
  }
}

// -----------------------------------------------------------------------------
// SERVICES
// -----------------------------------------------------------------------------

class AnalysisService {
  static const _categories = {
    'Core CS': ['DSA', 'OOP', 'DBMS', 'OS', 'Networks'],
    'Languages': ['Java', 'Python', 'JavaScript', 'TypeScript', 'C', 'C++', 'C#', 'Go'],
    'Web': ['React', 'Next.js', 'Node.js', 'Express', 'REST', 'GraphQL'],
    'Data': ['SQL', 'MongoDB', 'PostgreSQL', 'MySQL', 'Redis'],
    'Cloud/DevOps': ['AWS', 'Azure', 'GCP', 'Docker', 'Kubernetes', 'CI/CD', 'Linux'],
    'Testing': ['Selenium', 'Cypress', 'Playwright', 'JUnit', 'PyTest'],
  };

  static AnalysisResult analyze(String company, String role, String jdText) {
    final extractedSkills = <String, List<String>>{};
    final allDetectedSkills = <String>[];
    int detectedCategories = 0;

    // 1. Extract Skills
    _categories.forEach((category, keywords) {
      final found = keywords.where((k) => jdText.toLowerCase().contains(k.toLowerCase())).toList();
      if (found.isNotEmpty) {
        extractedSkills[category] = found;
        allDetectedSkills.addAll(found);
        detectedCategories++;
      }
    });

    if (extractedSkills.isEmpty) {
      extractedSkills['General'] = ['General fresher stack'];
    }

    // 2. Generate Checklist
    final checklist = [
      'Round 1: Aptitude / Basics - Focus on quantitative aptitude and logical reasoning.',
      'Round 2: DSA + Core CS - Prepare for coding problems and core CS concepts.',
      'Round 3: Tech Interview - Deep dive into projects and technical stack.',
      'Round 4: Managerial / HR - Behavioral questions and culture fit.',
      'Review resume and ensure all listed projects are well-understood.',
      'Practice explaining your thought process clearly during coding.',
    ];

    // 3. Generate Plan
    final plan = [
      'Day 1-2: Basics + Core CS (OS, DBMS, Networks)',
      'Day 3-4: DSA + Coding Practice (Arrays, Strings, Trees)',
      'Day 5: Project Review + Resume Alignment',
      'Day 6: Mock Interview Questions (Behavioral + Technical)',
      'Day 7: Final Revision + Weak Areas Focus',
    ];
    if (allDetectedSkills.any((s) => ['React', 'Next.js', 'Vue'].contains(s))) {
      plan[2] += ' (Focus on Frontend Lifecycle)';
    }

    // 4. Generate Questions
    final questions = <String>[];
    if (allDetectedSkills.any((s) => s.toLowerCase().contains('sql'))) {
      questions.add('Explain indexing and when it helps in SQL.');
    }
    if (allDetectedSkills.any((s) => ['React', 'Next.js'].contains(s))) {
      questions.add('Explain state management options in React.');
    }
    if (allDetectedSkills.any((s) => ['Java', 'C++', 'OOP'].contains(s))) {
      questions.add('Explain the four pillars of OOP with examples.');
    }
    if (allDetectedSkills.any((s) => ['Python'].contains(s))) {
      questions.add('Explain the difference between list and tuple in Python.');
    }
    if (questions.length < 10) {
      questions.add('Tell me about a challenging project you worked on.');
      questions.add('How do you handle tight deadlines?');
      questions.add('Explain a time you had a conflict with a team member.');
      questions.add('What are your strengths and weaknesses?');
      questions.add('Where do you see yourself in 5 years?');
      while (questions.length < 10) {
        questions.add('General technical question #${questions.length + 1}');
      }
    }

    // 5. Calculate Score
    double score = 35.0;
    score += (detectedCategories * 5).clamp(0, 30);
    if (company.isNotEmpty) score += 10;
    if (role.isNotEmpty) score += 10;
    if (jdText.length > 800) score += 10;
    score = score.clamp(0.0, 100.0);

    // Initialize confidence map
    final skillConfidence = <String, String>{};
    for (var skill in allDetectedSkills) {
      skillConfidence[skill] = 'practice'; // Default
    }

    return AnalysisResult(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      company: company,
      role: role,
      jdText: jdText,
      extractedSkills: extractedSkills,
      checklist: checklist,
      plan: plan,
      questions: questions.take(10).toList(),
      baseScore: score,
      skillConfidence: skillConfidence,
    );
  }
}

class StorageService {
  static const _key = 'analysis_history';

  static Future<void> save(AnalysisResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadAll();
    
    // Update existing or add new
    final index = history.indexWhere((item) => item.id == result.id);
    if (index != -1) {
      history[index] = result;
    } else {
      history.insert(0, result);
    }

    final jsonList = history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<AnalysisResult>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList.map((e) => AnalysisResult.fromJson(jsonDecode(e))).toList();
  }

  static Future<AnalysisResult?> getById(String id) async {
    final all = await loadAll();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }
}

// -----------------------------------------------------------------------------
// SCREENS
// -----------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _jdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _analyze() async {
    if (_jdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a Job Description')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 1));

    final result = AnalysisService.analyze(
      _companyController.text,
      _roleController.text,
      _jdController.text,
    );

    await StorageService.save(result);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushNamed(context, '/results', arguments: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement Readiness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Analyze Job Description',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a JD to get a personalized preparation plan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: 'Company Name (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roleController,
              decoration: InputDecoration(
                labelText: 'Role (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _jdController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'Paste Job Description Here *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'ANALYZE NOW',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late AnalysisResult _result;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is AnalysisResult) {
        _result = args;
      }
      _initialized = true;
    }
  }

  void _toggleSkill(String skill) {
    setState(() {
      final currentStatus = _result.skillConfidence[skill] ?? 'practice';
      _result.skillConfidence[skill] = currentStatus == 'practice' ? 'know' : 'practice';
    });
    StorageService.save(_result);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  String _generateFullReport() {
    final buffer = StringBuffer();
    buffer.writeln('PLACEMENT READINESS REPORT');
    buffer.writeln('Generated: ${DateFormat.yMMMd().format(_result.createdAt)}');
    buffer.writeln('Company: ${_result.company}');
    buffer.writeln('Role: ${_result.role}');
    buffer.writeln('Readiness Score: ${_result.currentScore.toStringAsFixed(1)}/100');
    buffer.writeln('\n----------------------------------------\n');
    
    buffer.writeln('SKILLS ANALYSIS:');
    _result.extractedSkills.forEach((category, skills) {
      buffer.writeln('$category: ${skills.join(", ")}');
    });
    buffer.writeln('\n----------------------------------------\n');

    buffer.writeln('7-DAY PREPARATION PLAN:');
    for (var item in _result.plan) {
      buffer.writeln('- $item');
    }
    buffer.writeln('\n----------------------------------------\n');

    buffer.writeln('ROUND CHECKLIST:');
    for (var item in _result.checklist) {
      buffer.writeln('- $item');
    }
    buffer.writeln('\n----------------------------------------\n');

    buffer.writeln('INTERVIEW QUESTIONS:');
    for (var i = 0; i < _result.questions.length; i++) {
      buffer.writeln('${i + 1}. ${_result.questions[i]}');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final currentScore = _result.currentScore;
    final weakSkills = _result.skillConfidence.entries
        .where((e) => e.value == 'practice')
        .map((e) => e.key)
        .take(3)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy Full Report',
            onPressed: () => _copyToClipboard(_generateFullReport(), 'Full Report'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Readiness Score',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: currentScore,
                                color: currentScore > 70
                                    ? Colors.green
                                    : currentScore > 40
                                        ? Colors.orange
                                        : Colors.red,
                                radius: 20,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: 100 - currentScore,
                                color: Colors.grey[200],
                                radius: 20,
                                showTitle: false,
                              ),
                            ],
                            startDegreeOffset: 270,
                            sectionsSpace: 0,
                            centerSpaceRadius: 50,
                          ),
                        ),
                        Center(
                          child: Text(
                            '${currentScore.toInt()}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentScore > 70
                        ? 'Excellent! Keep polishing.'
                        : currentScore > 40
                            ? 'Good start. Focus on weak areas.'
                            : 'Needs significant preparation.',
                    style: TextStyle(
                      color: currentScore > 70
                          ? Colors.green
                          : currentScore > 40
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Skills Section
            _buildSectionHeader('Key Skills Extracted', null),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _result.extractedSkills.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value.map((skill) {
                            final isKnown = _result.skillConfidence[skill] == 'know';
                            return FilterChip(
                              label: Text(skill),
                              selected: isKnown,
                              onSelected: (_) => _toggleSkill(skill),
                              selectedColor: Colors.green[100],
                              checkmarkColor: Colors.green,
                              labelStyle: TextStyle(
                                color: isKnown ? Colors.green[900] : Colors.black87,
                              ),
                              backgroundColor: Colors.grey[100],
                              side: BorderSide.none,
                              tooltip: isKnown ? 'Mark as Need Practice' : 'Mark as Known',
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Action Next Box
            if (weakSkills.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF), // Light Indigo
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        const Text(
                          'Recommended Next Action',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Focus on these weak areas: ${weakSkills.join(", ")}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Scroll to plan or just show message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Starting Day 1 Plan...')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Day 1 Plan Now'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // 7-Day Plan
            _buildSectionHeader('7-Day Plan', () => _copyToClipboard(_result.plan.join('\n'), 'Plan')),
            _buildListCard(_result.plan),
            const SizedBox(height: 24),

            // Checklist
            _buildSectionHeader('Round Checklist', () => _copyToClipboard(_result.checklist.join('\n'), 'Checklist')),
            _buildListCard(_result.checklist),
            const SizedBox(height: 24),

            // Questions
            _buildSectionHeader('Interview Questions', () => _copyToClipboard(_result.questions.join('\n'), 'Questions')),
            _buildListCard(_result.questions, isNumbered: true),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onCopy) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (onCopy != null)
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildListCard(List<String> items, {bool isNumbered = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNumbered ? '${index + 1}. ' : '• ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AnalysisResult> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.loadAll();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No history yet',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          item.company.isNotEmpty ? item.company : 'Unknown Company',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.role.isNotEmpty ? item.role : 'General Role'),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMd().add_jm().format(item.createdAt),
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.currentScore > 70
                                ? Colors.green[50]
                                : item.currentScore > 40
                                    ? Colors.orange[50]
                                    : Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${item.currentScore.toInt()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.currentScore > 70
                                  ? Colors.green
                                  : item.currentScore > 40
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/results',
                            arguments: item,
                          );
                          _loadHistory(); // Reload to reflect any changes made in Results
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
