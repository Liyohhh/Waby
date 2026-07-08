class Contact {

  final String id;

  final String name;

  final String phone;

  final String relation;

  final String? telegramChatId;



  Contact({

    required this.id,

    required this.name,

    required this.phone,

    required this.relation,

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

      );

}

