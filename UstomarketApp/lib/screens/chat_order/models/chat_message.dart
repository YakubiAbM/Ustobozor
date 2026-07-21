/// UI chat message (text history only — pick/invoice driven by provider state).
enum ChatRole { user, system }

enum ChatMessageType { text, loading }

class ChatMessage {
  final String id;
  final ChatRole role;
  final ChatMessageType type;
  final String? text;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.type,
    this.text,
  });

  factory ChatMessage.userText(String text, {String? id}) {
    return ChatMessage(
      id: id ?? 'u_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.user,
      type: ChatMessageType.text,
      text: text,
    );
  }

  factory ChatMessage.loading({String? id}) {
    return ChatMessage(
      id: id ?? 'load_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.system,
      type: ChatMessageType.loading,
    );
  }

  factory ChatMessage.systemText(String text, {String? id}) {
    return ChatMessage(
      id: id ?? 's_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.system,
      type: ChatMessageType.text,
      text: text,
    );
  }
}
