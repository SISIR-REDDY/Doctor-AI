import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/chat_context_builder.dart';
import '../../services/analytics_service.dart';
import '../../services/deepgram_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/voice_recorder_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/audio_visualizer.dart';
import '../../widgets/clinical_md.dart';
import 'chat_history_sheet.dart';

class AiHealthAssistantScreen extends StatefulWidget {
  /// `coverage` — grounded on the user's bills, statements, policies and
  /// cases (the default). `health` — general health information helper.
  final String mode;
  const AiHealthAssistantScreen({super.key, this.mode = 'coverage'});

  @override
  State<AiHealthAssistantScreen> createState() =>
      _AiHealthAssistantScreenState();
}

class _AiHealthAssistantScreenState extends State<AiHealthAssistantScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = FirestoreService();
  String _context = '';
  bool get _coverage => widget.mode != 'health';
  final _deepgram = DeepgramService();
  final _voice = VoiceRecorderService();
  final _uuid = const Uuid();

  ChatSession? _currentSession;
  bool _initializingSession = true;

  final List<AiChatMessage> _messages = [];
  StreamSubscription<List<AiChatMessage>>? _chatSub;
  StreamSubscription<double>? _levelSub;
  bool _typing = false;
  bool _welcomeSeeded = false;
  bool _isRecordingVoice = false;
  bool _isTranscribingVoice = false;
  double _voiceLevel = 0;

  static const _coveragePrompts = [
    'What do I still owe, and why?',
    'Explain my latest insurance statement',
    'Which charges look wrong?',
    'What are my appeal deadlines?',
    'What does my policy cover for this?',
  ];
  static const _healthPrompts = [
    'What could cause a persistent headache?',
    'What do my lab results generally mean?',
    'When should a fever be seen by a doctor?',
    'How do I prepare for a specialist visit?',
  ];
  List<String> get _quickPrompts => _coverage ? _coveragePrompts : _healthPrompts;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() => setState(() {}));
    _levelSub = _voice.levelStream.listen((l) {
      if (mounted) setState(() => _voiceLevel = l);
    });
    Analytics.screen(_coverage ? 'chat_coverage' : 'chat_health');
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  // ── Session lifecycle ────────────────────────────────────────────────────

  Future<void> _initSession() async {
    final provider = context.read<HealthDataProvider>();
    await provider.loadProfile();
    if (!mounted) return;
    final uid = provider.uid;
    if (uid == null) {
      if (mounted) setState(() => _initializingSession = false);
      return;
    }

    final latest = await _db.loadLatestChatSession(uid);
    if (!mounted) return;

    if (latest != null) {
      _currentSession = latest;
    } else {
      final session = ChatSession(id: _uuid.v4(), userId: uid);
      try {
        await _db.saveChatSession(uid, session);
      } catch (e) {
        debugPrint('[Chat] initial saveChatSession failed: $e');
      }
      if (!mounted) return;
      _currentSession = session;
    }

    setState(() => _initializingSession = false);
    _subscribeToSession();
  }

  void _subscribeToSession() {
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null || _currentSession == null) return;
    _chatSub?.cancel();
    _chatSub =
        _db.watchChatMessages(uid, _currentSession!.id).listen(
      (msgs) async {
        if (!mounted) return;
        if (msgs.isEmpty && !_welcomeSeeded) {
          _welcomeSeeded = true;
          await _seedWelcome(uid);
          return;
        }
        setState(() => _messages
          ..clear()
          ..addAll(msgs));
        _scrollToBottom();
      },
      onError: (e) => debugPrint('[Chat] watchChatMessages error: $e'),
    );
  }

  Future<void> _newChat() async {
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null) return;
    final session = ChatSession(id: _uuid.v4(), userId: uid);
    try {
      await _db.saveChatSession(uid, session);
    } catch (e) {
      debugPrint('[Chat] newChat saveChatSession failed: $e');
    }
    if (!mounted) return;
    _chatSub?.cancel();
    setState(() {
      _currentSession = session;
      _messages.clear();
      _welcomeSeeded = false;
    });
    _subscribeToSession();
  }

  void _switchSession(ChatSession session) {
    if (_currentSession?.id == session.id) return;
    _chatSub?.cancel();
    setState(() {
      _currentSession = session;
      _messages.clear();
      _welcomeSeeded = false;
    });
    _subscribeToSession();
  }

  void _openHistory() {
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatHistorySheet(
        uid: uid,
        db: _db,
        currentSession: _currentSession,
        onNewChat: () {
          Navigator.pop(context);
          _newChat();
        },
        onSelect: (session) {
          Navigator.pop(context);
          _switchSession(session);
        },
      ),
    );
  }

  // ── Session metadata updates ─────────────────────────────────────────────

  Future<void> _updateSessionAfterUserMessage(
      String uid, String text) async {
    if (_currentSession == null) return;
    final isFirstMsg = _currentSession!.title == 'New Chat';
    final preview =
        text.length > 80 ? '${text.substring(0, 77)}…' : text;
    final newTitle = isFirstMsg
        ? (text.length > 45 ? '${text.substring(0, 42)}…' : text)
        : null;
    final updated = _currentSession!.copyWith(
      title: newTitle,
      lastMessage: preview,
      updatedAt: DateTime.now(),
      messageCount: _currentSession!.messageCount + 1,
    );
    setState(() => _currentSession = updated);
    try {
      await _db.saveChatSession(uid, updated);
    } catch (e) {
      debugPrint('[Chat] saveChatSession failed: $e');
    }
  }

  // ── Chat ─────────────────────────────────────────────────────────────────

  Future<void> _seedWelcome(String uid) async {
    if (!mounted || _currentSession == null) return;
    final profile = context.read<HealthDataProvider>().profile;
    final name = profile?.firstName.isNotEmpty == true
        ? ', ${profile!.firstName}'
        : '';
    final welcome = AiChatMessage(
      id: _uuid.v4(),
      userId: uid,
      threadId: _currentSession!.id,
      role: 'assistant',
      content: _coverage
          ? 'Hi$name. Ask me anything about your bills, insurance statements, policies or cases — I answer from the documents you have added to Clinix.\n\n_General information, not legal or financial advice. Always check your documents before acting._'
          : 'Hi$name. I can help you understand symptoms, test results and medical terms in plain language.\n\n_I am not a doctor and cannot diagnose. In an emergency, call your local emergency number._',
    );
    try {
      await _db.saveChatMessage(uid, welcome);
    } catch (_) {
      if (mounted) setState(() => _messages.add(welcome));
    }
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _levelSub?.cancel();
    _voice.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (_isTranscribingVoice || _typing) return;
    if (_isRecordingVoice) {
      await _finishVoiceAndSend();
      return;
    }
    try {
      await _voice.start();
      if (mounted) setState(() => _isRecordingVoice = true);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _cancelVoice() async {
    await _voice.cancel();
    if (mounted) setState(() => _isRecordingVoice = false);
  }

  Future<void> _finishVoiceAndSend() async {
    setState(() {
      _isRecordingVoice = false;
      _isTranscribingVoice = true;
    });
    try {
      final path = await _voice.stop();
      if (path == null) throw Exception('Recording failed. Try again.');
      final transcript = await _deepgram.transcribeFile(path);
      if (!mounted) return;
      setState(() => _isTranscribingVoice = false);
      await _send(transcript);
    } catch (e) {
      if (mounted) {
        setState(() => _isTranscribingVoice = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _send([String? quick]) async {
    final text = (quick ?? _msgCtrl.text).trim();
    if (text.isEmpty ||
        _typing ||
        _isTranscribingVoice ||
        _currentSession == null) {
      return;
    }

    final provider = context.read<HealthDataProvider>();
    final uid = provider.uid;
    if (uid == null) {
      AppErrorHandler.showSnackBar(
          context, Exception('Sign in required.'));
      return;
    }

    final userMsg = AiChatMessage(
      id: _uuid.v4(),
      userId: uid,
      threadId: _currentSession!.id,
      role: 'user',
      content: text,
    );

    setState(() {
      if (!_messages.any((m) => m.id == userMsg.id)) {
        _messages.add(userMsg);
      }
      _typing = true;
      _msgCtrl.clear();
    });
    _scrollToBottom();

    await _updateSessionAfterUserMessage(uid, text);

    try {
      await _db.saveChatMessage(uid, userMsg);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    }

    try {
      if (_coverage && _context.isEmpty) {
        _context = await ChatContextBuilder(_db).build(uid);
      }
      final region = regionByCode(provider.profile?.country).code;
      // Conversation window: drop the seeded welcome, keep the last 12 turns,
      // and make sure the latest user text is the final entry.
      final history = _messages
          .where((m) => (m.role == 'user' || m.role == 'assistant') && m.id != userMsg.id)
          .skipWhile((m) => m.role == 'assistant')
          .toList();
      final recent = history.length > 11 ? history.sublist(history.length - 11) : history;
      final response = await AiService.instance.chat(
        mode: _coverage ? 'coverage' : 'health',
        region: region,
        messages: [
          for (final m in recent) {'role': m.role, 'content': m.content},
          {'role': 'user', 'content': text},
        ],
        context: _coverage ? _context : '',
        profileSummary: _coverage ? '' : ChatContextBuilder.profileSummary(provider.profile),
      );

      final botMsg = AiChatMessage(
        id: _uuid.v4(),
        userId: uid,
        threadId: _currentSession!.id,
        role: 'assistant',
        content: ClinicalMd.normalize(response),
      );

      if (mounted) {
        setState(() {
          _typing = false;
          _messages.add(botMsg);
        });
        _scrollToBottom();
        try {
          await _db.saveChatMessage(uid, botMsg);
        } catch (e) {
          if (mounted) AppErrorHandler.showSnackBar(context, e);
        }
      }
    } on AiQuotaException catch (e) {
      Analytics.quotaHit(e.op);
      if (mounted) {
        setState(() => _typing = false);
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Free limit reached'),
            content: Text(e.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('See Pro')),
            ],
          ),
        );
        if (go == true && mounted) {
          Analytics.paywallShown('quota_chat');
          Navigator.pushNamed(context, AppRouter.paywall);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _typing = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final busy = _typing || _isTranscribingVoice;
    final sessionTitle = _currentSession?.title == 'New Chat' ||
            _currentSession == null
        ? null
        : _currentSession!.title;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: GlassBar(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: MediaQuery.paddingOf(context).top,
            bottom: 8,
          ),
          child: Row(
            children: [
              IconButton(
                icon:
                    const Icon(CupertinoIcons.back, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(_coverage ? CupertinoIcons.sparkles : CupertinoIcons.heart_fill,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_coverage ? 'Ask Clinix' : 'Health helper',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      sessionTitle ?? (_coverage ? 'About your bills & coverage' : 'General information only'),
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // New chat button
              IconButton(
                icon: const Icon(CupertinoIcons.text_bubble, size: 22),
                onPressed:
                    _initializingSession ? null : _newChat,
                tooltip: 'New chat',
                color: AppTheme.primaryColor,
              ),
              // History button
              IconButton(
                icon: const Icon(CupertinoIcons.clock, size: 22),
                onPressed:
                    _initializingSession ? null : _openHistory,
                tooltip: 'Chat history',
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
      body: _initializingSession
          ? _buildLoading()
          : Column(
              children: [
                SizedBox(
                    height:
                        MediaQuery.paddingOf(context).top + kToolbarHeight),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding:
                        const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: _messages.length + (busy ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (busy && i == _messages.length) {
                        return _isTranscribingVoice
                            ? const _TranscribingVoiceBanner()
                            : const _TypingIndicator();
                      }
                      return _MessageBubble(msg: _messages[i]);
                    },
                  ),
                ),
                if (_messages.length <= 2 && !_isRecordingVoice)
                  _QuickPrompts(
                      prompts: _quickPrompts, onTap: _send),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: Colors.transparent,
                  child: Text(
                    _coverage
                        ? 'General information from your documents — not legal or financial advice.'
                        : 'General information, not medical advice. In an emergency, call your local emergency number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: AppTheme.textTertiary),
                  ),
                ),
                _ChatInputBar(
                  ctrl: _msgCtrl,
                  busy: busy,
                  isRecording: _isRecordingVoice,
                  voiceLevel: _voiceLevel,
                  onSend: () => _send(),
                  onVoiceToggle: _toggleVoice,
                  onVoiceCancel: _cancelVoice,
                ),
              ],
            ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(CupertinoIcons.waveform,
                color: Colors.white, size: 26),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 22,
            height: 22,
            child: CupertinoActivityIndicator(),
          ),
        ],
      ),
    );
  }
}

// ── Voice transcribing banner ─────────────────────────────────────────────────

class _TranscribingVoiceBanner extends StatelessWidget {
  const _TranscribingVoiceBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlossyPanel(
        enableBlur: true,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        radius: 16,
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CupertinoActivityIndicator(),
            ),
            const SizedBox(width: 12),
            Text('Transcribing your voice…',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ──────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final AiChatMessage msg;
  const _MessageBubble({required this.msg});

  bool get isUser => msg.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.waveform,
                  color: Colors.white, size: 14),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Copied'),
                        duration: Duration(seconds: 1)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.primaryColor
                      : AppTheme.surfaceColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft:
                        Radius.circular(isUser ? 18 : 4),
                    bottomRight:
                        Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: AppTheme.glassBorder, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: AppTheme.isDark ? 0.25 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isUser
                    ? Text(
                        msg.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      )
                    : ClinicalMd(
                        msg.content,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        bulletColor: AppTheme.primaryColor,
                        selectable: true,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.waveform,
                color: Colors.white, size: 14),
          ),
          GlossyPanel(
            enableBlur: true,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            radius: 18,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => _Dot(delay: i * 0.2, animation: _ctrl),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double delay;
  final Animation<double> animation;
  const _Dot({required this.delay, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final v = ((animation.value - delay) % 1.0);
          final opacity = v < 0.5 ? v * 2 : (1 - v) * 2;
          return Opacity(
            opacity: 0.3 + opacity * 0.7,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Quick prompts ───────────────────────────────────────────────────────────────

class _QuickPrompts extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onTap;
  const _QuickPrompts({required this.prompts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: prompts
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label:
                      Text(p, style: const TextStyle(fontSize: 12)),
                  onPressed: () => onTap(p),
                  backgroundColor:
                      AppTheme.surfaceColor.withValues(alpha: 0.9),
                  side: BorderSide(
                      color: AppTheme.primaryColor
                          .withValues(alpha: 0.35)),
                  labelStyle: const TextStyle(
                      color: AppTheme.primaryColor),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Chat input ──────────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool busy;
  final bool isRecording;
  final double voiceLevel;
  final VoidCallback onSend;
  final VoidCallback onVoiceToggle;
  final VoidCallback onVoiceCancel;

  const _ChatInputBar({
    required this.ctrl,
    required this.busy,
    required this.isRecording,
    required this.voiceLevel,
    required this.onSend,
    required this.onVoiceToggle,
    required this.onVoiceCancel,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = ctrl.text.trim().isNotEmpty;
    return GlassBar(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: isRecording ? _recordingUI() : _textUI(hasText),
    );
  }

  Widget _textUI(bool hasText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _roundButton(
          onPressed: busy ? null : onVoiceToggle,
          color: AppTheme.primaryColor,
          icon: CupertinoIcons.mic_fill,
          iconColor: Colors.white,
          tooltip: 'Voice message',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: TextField(
              controller: ctrl,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textTertiary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) {
                if (hasText && !busy) onSend();
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        _roundButton(
          onPressed: busy || !hasText ? null : onSend,
          color: hasText
              ? AppTheme.primaryColor
              : AppTheme.surfaceVariant,
          icon: CupertinoIcons.paperplane_fill,
          iconColor: hasText ? Colors.white : AppTheme.textTertiary,
          tooltip: 'Send',
        ),
      ],
    );
  }

  Widget _recordingUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onVoiceCancel,
              icon: const Icon(CupertinoIcons.xmark,
                  color: AppTheme.dangerColor),
            ),
            Expanded(
              child: AudioSignalBox(
                isActive: true,
                audioLevel: voiceLevel,
                height: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            _roundButton(
              onPressed: onVoiceToggle,
              color: AppTheme.primaryColor,
              icon: CupertinoIcons.stop_fill,
              iconColor: Colors.white,
              size: 52,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Listening… tap stop to send',
          style:
              AppTheme.labelSmall.copyWith(color: AppTheme.primaryColor),
        ),
      ],
    );
  }

  Widget _roundButton({
    required VoidCallback? onPressed,
    required Color color,
    required IconData icon,
    required Color iconColor,
    double size = 44,
    String? tooltip,
  }) {
    final btn = Material(
      color: color,
      shape: const CircleBorder(),
      elevation: onPressed != null ? 3 : 0,
      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip, child: btn);
  }
}
