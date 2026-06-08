import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import '../theme.dart';
import 'profile_screen.dart';
import 'post_photo_screen.dart';
import 'sign_in_screen.dart';
import 'direct_messages_screen.dart';
import 'user_search_screen.dart';

ImageProvider<Object>? _avatarFromData({String? base64Str, String? url}) {
  if (base64Str != null && base64Str.isNotEmpty) {
    try {
      return MemoryImage(base64Decode(base64Str));
    } catch (_) {
      // fallback to URL if base64 is invalid
    }
  }
  if (url != null && url.isNotEmpty) {
    return NetworkImage(url);
  }
  return null;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
    const _FeedScreen(),
    const PostPhotoScreen(),
    const NotificationsScreen(),
    ProfileScreen(onLogout: _handleLogout),
  ];

  void _handleLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Stream<QuerySnapshot<Map<String, dynamic>>> unreadNotificationsStream = user != null
        ? FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .snapshots()
        : const Stream.empty().cast<QuerySnapshot<Map<String, dynamic>>>();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: unreadNotificationsStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        return Scaffold(
          body: _screens[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              const NavigationDestination(
                icon: Icon(Icons.add_box_outlined),
                label: 'Post',
              ),
              NavigationDestination(
                icon: _buildNotificationIcon(unreadCount),
                label: 'Notifikasi',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Profil',
              ),
            ],
            height: 70,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.secondary.withOpacity(0.16),
          ),
        );
      },
    );
  }

  Widget _buildNotificationIcon(int unreadCount) {
    if (unreadCount <= 0) {
      return const Icon(Icons.notifications_none);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none),
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Center(
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedScreen extends StatefulWidget {
  const _FeedScreen({Key? key}) : super(key: key);

  @override
  State<_FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<_FeedScreen> {
  static const double _imageHeight = 260;

  Future<String> _currentUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Seseorang';
    final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userSnapshot.data()?['username']?.toString() ?? user.email?.split('@').first ?? 'Seseorang';
  }

  Future<void> _addNotification({
    required String targetUserId,
    required String type,
    required String fromUserId,
    required String fromUsername,
    String? postId,
  }) async {
    if (targetUserId.isEmpty || targetUserId == fromUserId) return;
    final notificationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .collection('notifications');

    final message = type == 'follow'
        ? '$fromUsername mulai mengikuti Anda'
        : type == 'like'
            ? '$fromUsername menyukai postingan Anda'
            : '$fromUsername mengomentari postingan Anda';

    await notificationRef.add({
      'type': type,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'postId': postId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> _toggleLike(
    String postId,
    bool isLiked,
    String targetUserId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen()));
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
      if (!isLiked) {
        final fromUsername = await _currentUsername();
        await _addNotification(
          targetUserId: targetUserId,
          type: 'like',
          fromUserId: user.uid,
          fromUsername: fromUsername,
          postId: postId,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.background, Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada postingan',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.mode_comment_outlined, color: AppColors.primary),
                    tooltip: 'Pesan Langsung',
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const DirectMessagesScreen(),
                      ));
                    },
                  ),
                ],
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FitSnap',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Temukan inspirasi kebugaran setiap hari',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const UserSearchScreen(),
                      ));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: AppColors.textSecondary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Cari username...',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Profile carousel removed per user request.
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    final postId = posts[index].id;
                    final imageUrl = post['imageUrl']?.toString() ?? '';
                    final imageBase64 = post['imageBase64']?.toString() ?? '';

                    Widget imageWidget;
                    if (imageUrl.isNotEmpty) {
                      imageWidget = Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.border,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 72,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      );
                    } else if (imageBase64.isNotEmpty) {
                      try {
                        imageWidget = Image.memory(
                          base64Decode(imageBase64),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      } catch (_) {
                        imageWidget = Container(
                          color: AppColors.border,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 72,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }
                    } else {
                      imageWidget = Container(
                        color: AppColors.border,
                        child: const Center(
                          child: Icon(
                            Icons.photo,
                            size: 72,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }

                    final authorAvatarBase64 = post['avatarBase64']?.toString() ?? '';
                    final authorAvatarUrl = post['avatarUrl']?.toString() ?? '';
                    final authorAvatarImage = _avatarFromData(
                      base64Str: authorAvatarBase64,
                      url: authorAvatarUrl,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 18),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: InkWell(
                              onTap: () {
                                final authorId =
                                    post['userId']?.toString() ?? '';
                                if (authorId.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserProfileScreen(userId: authorId),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: authorAvatarImage,
                                    backgroundColor: AppColors.secondary.withOpacity(0.24),
                                    child: authorAvatarImage == null
                                        ? const Icon(Icons.person, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post['username'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          post['createdAt'] != null
                                              ? post['createdAt']
                                                    .toDate()
                                                    .toString()
                                              : '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.more_vert,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(0),
                              topRight: Radius.circular(0),
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            child: SizedBox(
                              height: _imageHeight,
                              width: double.infinity,
                              child: imageWidget,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              post['caption'] ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            child: Row(
                              children: [
                                if (postId != null)
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes').doc(FirebaseAuth.instance.currentUser?.uid ?? '').snapshots(),
                                    builder: (context, likeSnap) {
                                      final isLiked = likeSnap.hasData && likeSnap.data!.exists;
                                      final likes = post['likesCount'] ?? 0;
                                      return Row(
                                        children: [
                                          IconButton(
                                            onPressed: () => _toggleLike(
                                              postId,
                                              isLiked,
                                              post['userId']?.toString() ?? '',
                                            ),
                                            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.black87),
                                          ),
                                          Text(likes.toString()),
                                        ],
                                      );
                                    },
                                  ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () {
                                    if (postId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => PostDetailScreen(post: {...post, 'id': postId})),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(Icons.mode_comment_outlined, color: Colors.black54),
                                      const SizedBox(width: 6),
                                      Text((post['commentsCount'] ?? 0).toString()),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    if (postId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => PostDetailScreen(post: {...post, 'id': postId})),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new, color: Colors.black45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: posts.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
