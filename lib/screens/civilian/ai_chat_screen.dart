import 'package:flutter/material.dart';

import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/submit_throttle.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with SubmitThrottle {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<({String text, bool user, bool live})> _messages = [
    (
      text:
          'Hello! I provide bounded dengue education. I cannot diagnose or replace a clinician. Ask about symptoms, warning signs, prevention, hydration, testing, or when to seek care.',
      user: false,
      live: false,
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _sending) return;
    final wait = checkSubmitCooldown(cooldown: const Duration(seconds: 3));
    if (wait != null) {
      showMessage(context, 'Please wait ${wait}s before sending another message.', error: true);
      return;
    }
    setState(() {
      _messages.add((text: question, user: true, live: false));
      _sending = true;
      _controller.clear();
    });
    _scrollDown();
    final answer = await AiService.instance.ask(question);
    if (!mounted) return;
    setState(() {
      _messages.add((text: answer.text, user: false, live: answer.live));
      _sending = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SectionHeader(
              title: 'Dengue guidance assistant',
              subtitle:
                  'General health education with emergency escalation—not diagnosis.',
            ),
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Text(
                'Emergency: severe pain, persistent vomiting, bleeding, breathing difficulty, confusion, cold/clammy skin, or little urine → call 911 or seek urgent care.',
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                children: [
                  for (final prompt in const [
                    'What are dengue warning signs?',
                    'How can I prevent breeding sites?',
                    'Which medicines should be avoided?',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        label: Text(prompt),
                        onPressed: () => _send(prompt),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final message = _messages[index];
                  return Align(
                    alignment: message.user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 700),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: message.user
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(message.text),
                          if (!message.user && index != 0) ...[
                            const SizedBox(height: 6),
                            _SourceBadge(live: message.live),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 600,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a dengue-related question…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Honest signal for which path answered: the live AI provider, or the
/// bounded offline fallback (shown when the assistant-guidance function
/// isn't deployed/configured, or the network is unavailable).
class _SourceBadge extends StatelessWidget {
  final bool live;
  const _SourceBadge({required this.live});

  @override
  Widget build(BuildContext context) {
    final color = live ? AppColors.success : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          live ? Icons.bolt_outlined : Icons.wifi_off_outlined,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          live ? 'Live AI' : 'Offline guidance',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
