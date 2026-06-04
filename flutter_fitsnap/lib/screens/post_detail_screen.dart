import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sign_in_screen.dart';

import '../theme.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;

  ImageProvider<Object>? _imageFromData(String? url, String? base64) {
    try {
      if (base64 != null && base64.trim().isNotEmpty) {
        var s = base64.trim();
        final commaIndex = s.indexOf(',');
        if (s.startsWith('data:') && commaIndex != -1) s = s.substring(commaIndex + 1);
        final bytes = base64Decode(s);
        return MemoryImage(bytes);
      }
    } catch (_) {}

    if (url != null && url.trim().isNotEmpty && url.startsWith('http')) {
      return NetworkImage(url);
    }
    return null;
  }

  Future<void> _toggleLike(String postId, bool isLiked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _requireAuth();
      return;
    }

    final likeRef = FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes').doc(user.uid);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    final batch = FirebaseFirestore.instance.batch();
    if (isLiked) {
      batch.delete(likeRef);
      batch.update(postRef, {'likesCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {'userId': user.uid, 'createdAt': FieldValue.serverTimestamp()});
      batch.update(postRef, {'likesCount': FieldValue.increment(1)});
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _postComment(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _requireAuth();
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPostingComment = true);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final commentsRef = postRef.collection('comments');
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username']?.toString() ?? user.email ?? 'Unknown';
      await commentsRef.add({
        'userId': user.uid,
        'username': username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({'commentsCount': FieldValue.increment(1)});
      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Komentar terkirim')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengirim komentar: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  void _requireAuth() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perlu Login'),
        content: const Text('Silakan login untuk menggunakan fitur like dan komentar.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen()));
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final postId = post['id']?.toString();
    final image = _imageFromData(post['imageUrl'] as String?, post['imageBase64'] as String?);
    final username = post['username']?.toString() ?? '';
    final caption = post['caption']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Show full-screen interactive image
                if (image == null) return;
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: EdgeInsets.zero,
                    child: InteractiveViewer(
                      child: Image(image: image),
                    ),
                  ),
                );
              },
              child: Container(
                color: Colors.black,
                child: Center(
                  child: image != null
                      ? Image(
                          image: image,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: Icon(Icons.photo, size: 64, color: Colors.grey)),
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Column(
              children: [
                Builder(builder: (context) {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                            child: const Text('Login untuk Like & Komentar'),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      if (postId != null)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
                          builder: (context, snap) {
                            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                            final likes = data['likesCount'] ?? 0;
                            return Row(
                              children: [
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes').doc(currentUser.uid).snapshots(),
                                  builder: (context, likeSnap) {
                                    final isLiked = likeSnap.hasData && likeSnap.data!.exists;
                                    return IconButton(
                                      onPressed: () => _toggleLike(postId, isLiked),
                                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.black87),
                                    );
                                  },
                                ),
                                Text(likes.toString()),
                              ],
                            );
                          },
                        ),
                      const SizedBox(width: 12),
                      if (postId != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').orderBy('createdAt', descending: true).snapshots(),
                          builder: (context, cSnap) {
                            final count = cSnap.data?.docs.length ?? 0;
                            return Row(
                              children: [
                                Icon(Icons.mode_comment_outlined, color: Colors.black54),
                                const SizedBox(width: 6),
                                Text(count.toString()),
                              ],
                            );
                          },
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 8),
                if (caption.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(caption, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                const SizedBox(height: 8),
                if (FirebaseAuth.instance.currentUser == null)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                          child: const Text('Login untuk berkomentar'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Tulis komentar...',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: postId == null || _isPostingComment ? null : () => _postComment(postId),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                if (postId != null)
                  SizedBox(
                    height: 140,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) return const SizedBox();
                        final docs = snap.data?.docs ?? [];
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final c = docs[i].data() as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              title: Text(c['username'] ?? 'Anon', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(c['text'] ?? ''),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
