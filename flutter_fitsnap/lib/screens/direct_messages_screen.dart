import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme.dart';
import 'user_search_screen.dart';

String _conversationId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort();
  return ids.join('_');
}

Future<String> _getUsername(String userId) async {
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  if (!snapshot.exists) return 'Pengguna';
  return snapshot.data()?['username']?.toString() ?? 'Pengguna';
}

class DirectMessagesScreen extends StatelessWidget {
  const DirectMessagesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Pesan Langsung'),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Silakan login untuk melihat pesan langsung.'),
        ),
      );
    }

    final chatQuery = FirebaseFirestore.instance
        .collection('direct_messages')
        .where('participants', arrayContains: user.uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pesan Langsung'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari Pengguna',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const UserSearchScreen(),
              ));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final chats = snapshot.data?.docs.toList() ?? [];
          chats.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['lastActivity'] as Timestamp?;
            final bTime = bData['lastActivity'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.toDate().compareTo(aTime.toDate());
          });

          if (chats.isEmpty) {
            return const Center(
              child: Text('Belum ada percakapan. Mulai pesan teman Anda.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participants'] ?? []);
              final otherUserId = participants.firstWhere((id) => id != user.uid, orElse: () => '');
              final lastMessage = data['lastMessage']?.toString() ?? 'Tidak ada pesan';

              return FutureBuilder<String>(
                future: _getUsername(otherUserId),
                builder: (context, usernameSnapshot) {
                  final title = usernameSnapshot.data ?? 'Pengguna';
                  return ListTile(
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (otherUserId.isEmpty) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: chat.id,
                          otherUserId: otherUserId,
                          otherUsername: title,
                        ),
                      ));
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUsername;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUsername,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentUserId.isEmpty) return;

    setState(() => _isSending = true);
    final conversationRef = FirebaseFirestore.instance.collection('direct_messages').doc(widget.conversationId);
    final messageRef = conversationRef.collection('messages').doc();
    final notificationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .collection('notifications')
        .doc();

    final fromUsername = await _getUsername(_currentUserId);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(messageRef, {
      'senderId': _currentUserId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(conversationRef, {
      'participants': [
        _currentUserId,
        widget.otherUserId,
      ],
      'lastMessage': text,
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(notificationRef, {
      'type': 'dm',
      'fromUserId': _currentUserId,
      'fromUsername': fromUsername,
      'message': '$fromUsername mengirim pesan langsung',
      'conversationId': widget.conversationId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    try {
      await batch.commit();
      _controller.clear();
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengirim pesan: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildMessageItem(Map<String, dynamic> data) {
    final senderId = data['senderId']?.toString() ?? '';
    final text = data['text']?.toString() ?? '';
    final isMe = senderId == _currentUserId;
    final createdAt = data['createdAt'] as Timestamp?;
    final time = createdAt != null ? createdAt.toDate() : DateTime.now();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationRef = FirebaseFirestore.instance.collection('direct_messages').doc(widget.conversationId);
    final messageQuery = conversationRef.collection('messages').orderBy('createdAt', descending: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.otherUsername),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messageQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Mulai percakapan dengan mengirim pesan.'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final message = docs[index].data() as Map<String, dynamic>;
                    return _buildMessageItem(message);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: InputBorder.none,
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                IconButton(
                  icon: _isSending ? const CircularProgressIndicator(strokeWidth: 2) : const Icon(Icons.send),
                  color: AppColors.primary,
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
