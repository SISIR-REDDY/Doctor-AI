import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/chatbot_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class AiHealthAssistantScreen extends StatefulWidget {
  const AiHealthAssistantScreen({super.key});

  @override
  State<AiHealthAssistantScreen> createState() =>
      _AiHealthAssistantScreenState();
}

class _AiHealthAssistantScreenState extends State<AiHealthAssistantScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chatbot = ChatbotService();
  final _db = FirestoreService();
  final _uuid = const Uuid();

  late final String _threadId;
  final List<AiChatMessage> _messages = [];
  bool _typing = false;

  static const _quickPrompts = [
    'I have a headache and fever',
    'I feel chest pain',
    'I have a cough for 3 days',
    'I feel dizzy and tired',
    'I have stomach pain',
  ];

  @override
  void initState() {
    super.initState();
    _threadId = _uuid.v4();
    _addWelcome();
  }

  void _addWelcome() {
    final profile = context.read<HealthDataProvider>().profile;
    final name = profile?.firstName.isNotEmpty == true
        ? ', ${profile!.firstName}'
        : '';
    _messages.add(AiChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content:
          'Hello$name! I\'m your Clinix AI health assistant.\n\nDescribe your symptoms or ask a health question and I\'ll do my best to help. I can:\n• Explain possible causes of your symptoms\n• Tell you when to see a doctor\n• Give home remedy suggestions\n• Answer general health questions\n\n_Remember: I\'m an AI assistant, not a doctor. Always consult a healthcare professional for medical advice._',
    ));
  }

  @override
  void dispose() {
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

  Future<void> _send([String? quick]) async {
    final text = (quick ?? _msgCtrl.text).trim();
    if (text.isEmpty || _typing) return;

    final profile = context.read<HealthDataProvider>().profile;
    final uid = context.read<HealthDataProvider>().uid;

    final userMsg = AiChatMessage(
      id: _uuid.v4(),
      userId: uid ?? '',
      threadId: _threadId,
      role: 'user',
      content: text,
    );

    setState(() {
      _messages.add(userMsg);
      _typing = true;
      _msgCtrl.clear();
    });
    _scrollToBottom();

    if (uid != null) {
      _db.saveChatMessage(uid, userMsg);
    }

    try {
      final prompt = _buildPrompt(profile, text);
      final response = await _chatbot.getGeminiResponse(prompt);

      final botMsg = AiChatMessage(
        id: _uuid.v4(),
        userId: uid ?? '',
        threadId: _threadId,
        role: 'assistant',
        content: response,
      );

      if (mounted) {
        setState(() {
          _messages.add(botMsg);
          _typing = false;
        });
        _scrollToBottom();
        if (uid != null) _db.saveChatMessage(uid, botMsg);
      }
    } catch (e) {
      if (mounted) {
        final errMsg = AiChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          content:
              'Sorry, I couldn\'t process your request. Please check your internet connection and try again.\n\nError: ${e.toString()}',
        );
        setState(() {
          _messages.add(errMsg);
          _typing = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _buildPrompt(PatientProfile? profile, String userMessage) {
    final profileContext = profile != null
        ? '''Patient Profile:
- Name: ${profile.fullName}
- Age: ${profile.age > 0 ? '${profile.age} years' : 'Unknown'}
- Gender: ${profile.gender}
- Blood Group: ${profile.bloodGroup}
- Medical Allergies: ${profile.medicalAllergies.isEmpty ? 'None known' : profile.medicalAllergies.join(', ')}
- Food Allergies: ${profile.foodAllergies.isEmpty ? 'None known' : profile.foodAllergies.join(', ')}
- Past Diseases: ${profile.pastDiseases.isEmpty ? 'None' : profile.pastDiseases.join(', ')}
- Chronic Conditions: ${profile.chronicConditions.isEmpty ? 'None' : profile.chronicConditions.join(', ')}
'''
        : 'Patient profile not available.';

    return '''You are a compassionate and knowledgeable AI health assistant for a patient health app called Clinix AI. You help patients understand their symptoms, provide general health guidance, and advise when to seek professional medical care.

$profileContext

Patient's message: $userMessage

Please respond in a clear, friendly, and empathetic way. Structure your response with:
1. A brief acknowledgment of the symptoms
2. Possible causes (mention 2-4 most likely ones)
3. Home care suggestions if appropriate
4. Clear guidance on when to see a doctor (especially any RED FLAG symptoms requiring immediate attention)
5. Any relevant considerations given their medical history or allergies

Important:
- Always recommend seeing a doctor for serious, persistent, or worsening symptoms
- Never diagnose definitively — say "possible" or "this could indicate"
- Highlight any allergy-related risks based on their profile
- Keep response concise but complete (not more than 250 words)
- Use plain language, avoid heavy medical jargon
- End with a reassuring note''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Health Assistant',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Powered by Gemini',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(AppTheme.lg),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_typing && i == _messages.length) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),
          if (_messages.length <= 1)
            _QuickPrompts(prompts: _quickPrompts, onTap: _send),
          _InputBar(
            ctrl: _msgCtrl,
            typing: _typing,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final AiChatMessage msg;
  const _MessageBubble({required this.msg});

  bool get isUser => msg.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient:
                      isUser ? AppTheme.primaryGradient : null,
                  color: isUser ? null : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft:
                        Radius.circular(isUser ? 16 : 4),
                    bottomRight:
                        Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: AppTheme.dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

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
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 16),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                      3,
                      (i) => _Dot(
                          delay: i * 0.2,
                          animation: _ctrl)),
                );
              },
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

// ── Quick Prompts ─────────────────────────────────────────────────────────────

class _QuickPrompts extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onTap;
  const _QuickPrompts({required this.prompts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.md, horizontal: AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(left: 4, bottom: AppTheme.sm),
            child: Text('Quick start:',
                style:
                    AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: prompts
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(p,
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () => onTap(p),
                          backgroundColor: AppTheme.surfaceColor,
                          side: const BorderSide(
                              color: AppTheme.primaryColor),
                          labelStyle:
                              const TextStyle(color: AppTheme.primaryColor),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool typing;
  final VoidCallback onSend;

  const _InputBar({
    required this.ctrl,
    required this.typing,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.lg, vertical: AppTheme.md),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Describe your symptoms...',
                hintStyle: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: AppTheme.sm),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: typing ? null : AppTheme.primaryGradient,
              color: typing ? AppTheme.dividerColor : null,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: typing ? null : onSend,
              icon: typing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.textSecondary))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
