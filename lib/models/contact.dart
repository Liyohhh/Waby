class Contact {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final String? telegramChatId;
  final String linkCode;

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.linkCode,
    this.telegramChatId,
  });

  bool get isLinked =>
      telegramChatId != null && telegramChatId!.trim().isNotEmpty;

  factory Contact.fromMap(String id, Map<dynamic, dynamic> map) => Contact(
        id: id,
        name: (map['name'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
        relation: (map['relation'] ?? '') as String,
        telegramChatId: map['telegram_chat_id'] as String?,
        linkCode: (map['link_code'] ?? '') as String,
      );
}
