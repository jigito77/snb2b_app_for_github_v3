import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat_models.dart';

/// Чат поддержки: тот же backend и та же база, что у виджета на сайте и раздела «Чат» в админ-панели.
/// Авторизация — обычный Bearer-токен пользователя (диалог привязан к его аккаунту).
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<ChatState> load() async {
    final j = await _api.get('/api/chat/me');
    return ChatState.fromJson(Map<String, dynamic>.from(j as Map));
  }

  Future<ChatState> send(String text) async {
    final j = await _api.post('/api/chat/messages', body: <String, dynamic>{
      'text': text,
      'lang': L10n.lang,
      'page': <String, dynamic>{'url': '/app', 'title': 'SNP mobile app', 'kind': 'other'},
    });
    return ChatState.fromJson(Map<String, dynamic>.from(j as Map));
  }

  /// Отметить ответы поддержки прочитанными. Ошибки не критичны.
  Future<void> markRead() async {
    try {
      await _api.post('/api/chat/read', body: <String, dynamic>{});
    } catch (_) {
      // не мешаем пользователю: отметка повторится при следующем обновлении
    }
  }
}
