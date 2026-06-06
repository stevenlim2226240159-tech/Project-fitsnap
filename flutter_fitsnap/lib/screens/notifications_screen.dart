import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
    if (difference.inDays < 1) return '${difference.inHours} jam lalu';
    return '${difference.inDays} hari lalu';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          title: const Text('Notifikasi'),
        ),
        body: const Center(
          child: Text('Silakan login untuk melihat notifikasi Anda.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Notifikasi'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.notifications_active_outlined, size: 72, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada aktivitas terbaru.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final type = data['type']?.toString() ?? 'default';
              final message = data['message']?.toString() ?? 'Aktivitas baru tersedia';
              final createdAt = data['createdAt'] as Timestamp?;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.secondary.withOpacity(0.16),
                  child: Icon(_iconForType(type), color: AppColors.secondary),
                ),
                title: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_formatTimestamp(createdAt)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _onTapNotification(context, notifications[index]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onTapNotification(BuildContext context, QueryDocumentSnapshot notificationDoc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = notificationDoc.data() as Map<String, dynamic>;
    final type = data['type']?.toString() ?? '';
    final postId = data['postId']?.toString();
    final fromUserId = data['fromUserId']?.toString();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationDoc.id)
        .update({'read': true});

    if ((type == 'like' || type == 'comment') && postId != null && postId.isNotEmpty) {
      final postSnapshot = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
      if (postSnapshot.exists) {
        final post = postSnapshot.data() as Map<String, dynamic>;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: {...post, 'id': postId}),
          ),
        );
      }
      return;
    }

    if (type == 'follow' && fromUserId != null && fromUserId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: fromUserId),
        ),
      );
      return;
    }
  }
}
