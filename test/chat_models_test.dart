import 'package:flutter_test/flutter_test.dart';
import 'package:snb2b_app/features/support/domain/chat_models.dart';

void main() {
  test('ChatState разбирает ответ /api/chat/me', () {
    final s = ChatState.fromJson(<String, dynamic>{
      'online': true,
      'conversation': <String, dynamic>{
        'id': 'c1',
        'status': 'open',
        'unread': 2,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'm1', 'sender': 'customer', 'senderName': 'A', 'text': 'Hello', 'at': '2026-10-22T10:00:00.000Z', 'readAt': null},
          <String, dynamic>{'id': 'm2', 'sender': 'agent', 'senderName': 'admin', 'text': 'Hi', 'at': '2026-10-22T10:01:00.000Z', 'readAt': null},
        ],
      },
    });
    expect(s.online, true);
    expect(s.conversationId, 'c1');
    expect(s.unread, 2);
    expect(s.messages.length, 2);
    expect(s.messages.first.isMine, true);
    expect(s.messages.last.isMine, false);
  });

  test('ChatState без диалога', () {
    final s = ChatState.fromJson(<String, dynamic>{'online': false, 'conversation': null});
    expect(s.conversationId, null);
    expect(s.messages, isEmpty);
    expect(s.closed, false);
  });
}
