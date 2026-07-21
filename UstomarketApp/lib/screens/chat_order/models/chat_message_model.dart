import 'invoice_models.dart';
import 'pick_models.dart';

enum ChatRole { user, system }

enum ChatMessageType { text, invoice, pick, loading }

class ChatMessageModel {
  final String id;
  final ChatRole role;
  final ChatMessageType type;
  final String? text;
  final InvoiceDraft? invoice;
  final PickPayload? pick;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.type,
    this.text,
    this.invoice,
    this.pick,
  });

  factory ChatMessageModel.userText(String text, {String? id}) {
    return ChatMessageModel(
      id: id ?? 'u_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.user,
      type: ChatMessageType.text,
      text: text,
    );
  }

  factory ChatMessageModel.loading({String? id}) {
    return ChatMessageModel(
      id: id ?? 'load_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.system,
      type: ChatMessageType.loading,
    );
  }

  factory ChatMessageModel.systemText(String text, {String? id}) {
    return ChatMessageModel(
      id: id ?? 's_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.system,
      type: ChatMessageType.text,
      text: text,
    );
  }

  factory ChatMessageModel.systemInvoice(InvoiceDraft invoice, {String? id}) {
    return ChatMessageModel(
      id: id ?? 'inv_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.system,
      type: ChatMessageType.invoice,
      invoice: invoice,
    );
  }

  factory ChatMessageModel.systemPick(PickPayload pick, {String? id}) {
    return ChatMessageModel(
      id: id ?? 'pick_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.system,
      type: ChatMessageType.pick,
      pick: pick,
    );
  }
}
