import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../utils/constants.dart';

class ChatService {
  final String? accessToken;

  ChatService({this.accessToken});

  Future<List<Message>> getMessages(int rideId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/messages'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['messages'];
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      throw Exception('Error loading messages: $e');
    }
  }

  Future<Message> sendMessage({
    required int rideId,
    required int receiverId,
    required String content,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ride_id': rideId,
          'receiver_id': receiverId,
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        return Message.fromJson(json.decode(response.body)['message']);
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getChatList() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['chats'];
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load chats');
      }
    } catch (e) {
      throw Exception('Error loading chats: $e');
    }
  }

  Future<void> markAsRead(int messageId) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/messages/$messageId/read'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      throw Exception('Error marking message as read: $e');
    }
  }
}