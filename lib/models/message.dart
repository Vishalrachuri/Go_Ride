class Message {
  final int id;
  final int rideId;
  final int senderId;
  final int receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? sender;
  final Map<String, dynamic>? receiver;

  Message({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.sender,
    this.receiver,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      rideId: json['ride_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      sender: json['sender'],
      receiver: json['receiver'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'sender': sender,
      'receiver': receiver,
    };
  }
}