import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme.dart';
import 'sign_in_screen.dart';
import 'profile_screen.dart';

class FollowingScreen extends StatefulWidget {
  final String userId;
  const FollowingScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  bool _processingId = false;

  Future<void> _followUser(String targetId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == targetId) return;
    setState(() => _processingId = true);

    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetId);
    final followRef = currentUserRef.collection('following').doc(targetId);
    final followerRef = targetUserRef.collection('followers').doc(currentUser.uid);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(followRef, {'followedAt': FieldValue.serverTimestamp()});
    batch.set(followerRef, {'followedAt': FieldValue.serverTimestamp()});
    batch.update(currentUserRef, {'following': FieldValue.increment(1)});
    batch.update(targetUserRef, {'followers': FieldValue.increment(1)});

    try {
      await batch.commit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal follow: $e')));
    } finally {
      if (mounted) setState(() => _processingId = false);
    }
  }

  Future<void> _unfollowUser(String targetId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == targetId) return;
    setState(() => _processingId = true);

    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetId);
    final followRef = currentUserRef.collection('following').doc(targetId);
    final followerRef = targetUserRef.collection('followers').doc(currentUser.uid);

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(followRef);
    batch.delete(followerRef);
    batch.update(currentUserRef, {'following': FieldValue.increment(-1)});
    batch.update(targetUserRef, {'followers': FieldValue.increment(-1)});

    try {
      await batch.commit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal unfollow: $e')));
    } finally {
      if (mounted) setState(() => _processingId = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('following')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('Belum ada following'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final followingId = docs[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(followingId).get(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) return const ListTile(title: Text('Memuat...'));
                  final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final username = userData['username']?.toString() ?? 'Unknown';
                  final avatarBase64 = userData['avatarBase64']?.toString() ?? '';
                  final avatarUrl = userData['avatarUrl']?.toString() ?? '';

                  ImageProvider<Object>? avatarImage;
                  try {
                    if (avatarBase64.isNotEmpty) {
                      avatarImage = MemoryImage(base64Decode(avatarBase64));
                    } else if (avatarUrl.isNotEmpty) {
                      avatarImage = NetworkImage(avatarUrl);
                    }
                  } catch (_) {
                    avatarImage = null;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.border,
                      backgroundImage: avatarImage,
                      child: avatarImage == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(username),
                    trailing: Builder(builder: (context) {
                      if (currentUser == null) {
                        return ElevatedButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                          child: const Text('Login'),
                        );
                      }
                      if (currentUser.uid == followingId) {
                        return const Text('You');
                      }

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .collection('following')
                            .doc(followingId)
                            .snapshots(),
                        builder: (context, followSnap) {
                          final isFollowing = followSnap.hasData && followSnap.data!.exists;
                          if (isFollowing) {
                            return ElevatedButton(
                              onPressed: _processingId
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Unfollow'),
                                          content: const Text('Yakin ingin berhenti mengikuti pengguna ini?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
                                            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Unfollow')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _unfollowUser(followingId);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.primary),
                              child: const Text('Friend'),
                            );
                          }

                          return ElevatedButton(
                            onPressed: _processingId ? null : () => _followUser(followingId),
                            child: const Text('Follow'),
                          );
                        },
                      );
                    }),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(userId: followingId)));
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
