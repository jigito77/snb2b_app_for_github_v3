import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/l10n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

/// Онлайн-поддержка: переписка с реальным оператором. Обновление — опрос раз в 3 секунды,
/// пока экран открыт (ответ приходит и в «Уведомления», если приложение закрыто).
class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> with WidgetsBindingObserver {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  ChatState _chat = const ChatState();
  bool _loading = true;
  bool _sending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(authControllerProvider).isAuthenticated) {
      _refresh(initial: true);
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    } else {
      _loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _timer != null) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool initial = false}) async {
    try {
      final next = await ref.read(chatRepositoryProvider).load();
      if (!mounted) return;
      final grew = next.messages.length != _chat.messages.length;
      setState(() {
        _chat = next;
        _loading = false;
        _error = null;
      });
      if (next.unread > 0) unawaited(ref.read(chatRepositoryProvider).markRead());
      if (grew || initial) _toBottom();
    } catch (e) {
      if (!mounted) return;
      if (initial || _chat.messages.isEmpty) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final next = await ref.read(chatRepositoryProvider).send(text);
      if (!mounted) return;
      _input.clear();
      setState(() => _chat = next);
      _toBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Не удалось отправить сообщение. Попробуйте ещё раз.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Онлайн-поддержка'),
            if (auth.isAuthenticated)
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _chat.online ? AppColors.success : AppColors.textHint),
                  ),
                  const SizedBox(width: 6),
                  Text(_chat.online ? 'Поддержка онлайн' : 'Поддержка не в сети', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                ],
              ),
          ],
        ),
      ),
      body: !auth.isAuthenticated
          ? EmptyState(
              icon: Icons.support_agent,
              title: 'Чат с поддержкой',
              message: 'Войдите в аккаунт, чтобы написать в поддержку.',
              actionLabel: 'Войти',
              onAction: () => context.push('/login'),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(error: _error!, onRetry: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _refresh(initial: true);
                    })
                  : _body(),
    );
  }

  Widget _body() {
    final note = _chat.closed
        ? 'Диалог закрыт. Напишите — мы начнём новый.'
        : (!_chat.online ? 'Сейчас мы не в сети. Оставьте сообщение — ответим, как только вернёмся.' : null);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: <Widget>[
              _bubble(
                mine: false,
                child: const Text('Здравствуйте! Чем можем помочь? Напишите VIN, OEM или номер детали — подберём.'),
                accent: true,
              ),
              for (final m in _chat.messages) _messageRow(m),
            ],
          ),
        ),
        if (note != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppColors.accentSoft, border: Border(left: BorderSide(color: AppColors.accent, width: 3))),
            child: Text(note, style: const TextStyle(fontSize: 13)),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: tr('Напишите ваш вопрос'),
                      counterText: '',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  width: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _messageRow(ChatMessage m) {
    if (m.isSystem) {
      final label = m.text == 'closed' ? 'Диалог закрыт' : (m.text == 'reopened' ? 'Диалог возобновлён' : m.text);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      );
    }
    final mine = m.isMine;
    // Текст сообщения — пользовательский: показываем как есть, без перевода интерфейса.
    return _bubble(
      mine: mine,
      child: w.Text(m.text, style: TextStyle(fontSize: 14.5, height: 1.35, color: mine ? Colors.white : AppColors.textPrimary)),
      footer: '${mine ? '' : '${m.senderName.isEmpty ? tr('Поддержка') : m.senderName} · '}${_time(m.at)}${mine ? (m.readAt != null ? '  ✓✓' : '  ✓') : ''}',
    );
  }

  Widget _bubble({required bool mine, required Widget child, String? footer, bool accent = false}) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: mine ? null : Border.all(color: AppColors.border),
                boxShadow: accent ? const <BoxShadow>[] : null,
              ),
              child: child,
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: w.Text(footer, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}
