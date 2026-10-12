import 'package:flutter/material.dart';

import '../services/energy_ai_service.dart';
import '../theme/app_colors.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final EnergyAiService _aiService = EnergyAiService.instance;

  bool _aiReady = false;
  bool _isLoading = false;
  String? _statusMessage;

  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'message':
          '👋 Hi! I\'m your Smart Energy Assistant.\nAsk about your bill, energy saving tips, or best times to use appliances. ⚡',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAi();
  }

  Future<void> _initializeAi() async {
    setState(() {
      _aiReady = false;
      _statusMessage = 'Connecting to AI...';
    });

    await _aiService.initialize();

    if (!mounted) return;

    setState(() {
      _aiReady = _aiService.isReady;
      _statusMessage = _aiService.isReady
          ? 'Connected (${_aiService.activeModel})'
          : _aiService.initError ??
              'Start START_CHATBOT.bat on your PC and use the same Wi-Fi.';
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (!_aiReady) {
      setState(() {
        _messages.add({
          'role': 'ai',
          'message':
              'AI is still connecting. Please wait a moment and try again.',
        });
      });
      _scrollToBottom();
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'message': text});
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final answer = await _aiService.sendMessage(text);

      if (!mounted) return;

      setState(() {
        _messages.add({'role': 'ai', 'message': answer});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('AI request error: $e');
      debugPrint('AI stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'ai',
          'message': _aiService.friendlyError(e),
        });
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.primary, 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Energy AI'),
          ],
        ),
        actions: [
          if (!_aiReady)
            IconButton(
              tooltip: 'Retry AI connection',
              onPressed: _initializeAi,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _aiReady
                  ? AppColors.tint(AppColors.primary, 0.12)
                  : AppColors.tint(Colors.orange, 0.12),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _aiReady ? AppColors.primary : Colors.orange.shade200,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }

                final message = _messages[index];
                final isUser = message['role'] == 'user';
                return _buildMessage(message['message'] ?? '', isUser);
              },
            ),
          ),
          _buildSuggestionButtons(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border(0.06)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            SizedBox(width: 10),
            Text(
              'Analyzing your energy data...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: Border.all(color: AppColors.border(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUser) ...[
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionButtons() {
    final suggestions = [
      ('Analyze my usage', Icons.insights_outlined),
      ('How can I save energy?', Icons.eco_outlined),
      ('Estimate my bill', Icons.receipt_outlined),
      ('Is my voltage normal?', Icons.electric_bolt_outlined),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, icon) = suggestions[index];
          return ActionChip(
            avatar: Icon(icon, size: 16, color: AppColors.primary),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.border(0.08)),
            label: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            onPressed: _isLoading
                ? null
                : () {
                    _messageController.text = label;
                    _sendMessage();
                  },
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.navBar,
          border: Border(top: BorderSide(color: AppColors.border(0.06))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_isLoading,
                style: const TextStyle(color: Colors.white),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ask about your energy usage...',
                  prefixIcon: const Icon(Icons.chat_outlined, color: AppColors.textMuted, size: 20),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.textMuted : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
