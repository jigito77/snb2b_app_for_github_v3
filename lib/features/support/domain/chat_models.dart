/// Сообщение диалога поддержки. Формат совпадает с ответами `/api/chat/*` сайта и админ-панели.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.text,
    required this.at,
    this.readAt,
  });

  final String id;

  /// customer | agent | ai | system
  final String sender;
  final String senderName;
  final String text;
  final DateTime at;
  final DateTime? readAt;

  bool get isMine => sender == 'customer';
  bool get isSystem => sender == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: '${j['id'] ?? ''}',
        sender: '${j['sender'] ?? ''}',
        senderName: '${j['senderName'] ?? ''}',
        text: '${j['text'] ?? ''}',
        at: DateTime.tryParse('${j['at'] ?? ''}')?.toLocal() ?? DateTime.now(),
        readAt: j['readAt'] == null ? null : DateTime.tryParse('${j['readAt']}')?.toLocal(),
      );
}

/// Состояние чата: онлайн ли поддержка и сообщения текущего диалога.
class ChatState {
  const ChatState({
    this.online = false,
    this.conversationId,
    this.status = 'open',
    this.messages = const <ChatMessage>[],
    this.unread = 0,
  });

  final bool online;
  final String? conversationId;
  final String status;
  final List<ChatMessage> messages;

  /// Непрочитанные ответы поддержки.
  final int unread;

  bool get closed => status == 'closed';

  /// Разбор ответа `/api/chat/me` и `/api/chat/messages`: `{online, conversation: {...}|null}`.
  factory ChatState.fromJson(Map<String, dynamic> j) {
    final conv = j['conversation'];
    final msgs = <ChatMessage>[];
    String? id;
    var status = 'open';
    var unread = 0;
    if (conv is Map) {
      id = '${conv['id']}';
      status = '${conv['status'] ?? 'open'}';
      unread = (conv['unread'] as num?)?.toInt() ?? 0;
      final list = conv['messages'];
      if (list is List) {
        for (final m in list) {
          if (m is Map) msgs.add(ChatMessage.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }
    return ChatState(online: j['online'] == true, conversationId: id, status: status, messages: msgs, unread: unread);
  }
}
