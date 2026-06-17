import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'post_detail_screen.dart';
import 'direct_messages_screen.dart';

String _conversationId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort();
  return ids.join('_');
}

ImageProvider<Object>? _imageProviderFromAvatarStrings({
  String? base64Str,
  String? url,
}) {
  try {
    if (base64Str != null && base64Str.trim().isNotEmpty) {
      var s = base64Str.trim();
      // handle data URI like "data:image/png;base64,..."
      final commaIndex = s.indexOf(',');
      if (s.startsWith('data:') && commaIndex != -1) {
        s = s.substring(commaIndex + 1);
      }
      final bytes = base64Decode(s);
      return MemoryImage(bytes);
    }
  } catch (_) {
    // fallthrough to try URL
  }

  if (url != null && url.trim().isNotEmpty) {
    final u = url.trim();
    if (u.startsWith('http')) {
      return NetworkImage(u);
    }
  }

  return null;
}

Widget statItem(String label, String count) {
  return Column(
    children: [
      Text(
        count,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.black54)),
    ],
  );
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const ProfileScreen({Key? key, this.onLogout}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _avatarBytes;
  bool _isSavingAvatar = false;
  bool _isCreatingUserDoc = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _createDefaultUserDoc(User user) async {
    if (_isCreatingUserDoc) return;
    setState(() => _isCreatingUserDoc = true);

    final defaultName = user.email?.split('@').first ?? 'Unknown';
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'username': defaultName,
      'email': user.email ?? '',
      'postsCount': 0,
      'followers': 0,
      'following': 0,
    }, SetOptions(merge: true));

    if (mounted) {
      setState(() => _isCreatingUserDoc = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_user == null) return;

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _isSavingAvatar = true;
      });

      final base64Avatar = base64Encode(bytes);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update({'avatarBase64': base64Avatar});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui foto profil: $e')),
      );
    } finally {
      setState(() => _isSavingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _user;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text(
            'Profile',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: Text('Silakan login terlebih dahulu.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
      ),
      
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isCreatingUserDoc) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _createDefaultUserDoc(user);
            });
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final username = data['username']?.toString() ?? 'Unknown';
          final bio = data['bio']?.toString() ?? '';
          final avatarUrl = data['avatarUrl']?.toString() ?? '';
          final avatarBase64 = data['avatarBase64']?.toString() ?? '';
          final followers = data['followers'] ?? 0;
          final following = data['following'] ?? 0;

          ImageProvider<Object>? avatarImage = _imageProviderFromAvatarStrings(
            base64Str: _avatarBytes != null ? base64Encode(_avatarBytes!) : avatarBase64,
            url: avatarUrl,
          );

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 24,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: widget.onLogout ?? () {},
                          tooltip: 'Logout',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 58,
                            backgroundColor: AppColors.secondary.withOpacity(
                              0.24,
                            ),
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ));
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        username,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: const Text('Pesan Langsung'),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const DirectMessagesScreen(),
                      ));
                    },
                  ),
                ),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.hasError) {
                      return Center(
                        child: Text('Error: ${postSnapshot.error}'),
                      );
                    }
                    if (postSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = postSnapshot.data?.docs.toList() ?? [];
                    final actualPostsCount = docs.length;

                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final ta = aData['createdAt'];
                      final tb = bData['createdAt'];
                      if (ta == null && tb == null) return 0;
                      if (ta == null) return 1;
                      if (tb == null) return -1;
                      try {
                        return tb.toDate().compareTo(ta.toDate());
                      } catch (_) {
                        return 0;
                      }
                    });

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  statItem(
                                    'Posts',
                                    actualPostsCount.toString(),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => FollowersScreen(userId: user.uid),
                                      ));
                                    },
                                    child: statItem(
                                      'Followers',
                                      followers.toString(),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => FollowingScreen(userId: user.uid),
                                      ));
                                    },
                                    child: statItem(
                                      'Following',
                                      following.toString(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Postingan Saya',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (docs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.0),
                            child: Center(child: Text('Belum ada postingan')),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final post =
                                    docs[index].data() as Map<String, dynamic>;
                                final imageUrl =
                                    post['imageUrl']?.toString() ?? '';
                                final imageBase64 =
                                    post['imageBase64']?.toString() ?? '';

                                Widget postImage;
                                if (imageUrl.isNotEmpty) {
                                  postImage = Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                  );
                                } else if (imageBase64.isNotEmpty) {
                                  try {
                                    postImage = Image.memory(
                                      base64Decode(imageBase64),
                                      fit: BoxFit.cover,
                                    );
                                  } catch (_) {
                                    postImage = Container(
                                      color: AppColors.border,
                                      child: const Center(
                                        child: Text('Gambar tidak bisa dimuat'),
                                      ),
                                    );
                                  }
                                } else {
                                  postImage = Container(
                                    color: AppColors.border,
                                    child: const Center(
                                      child: Text('Tidak ada gambar'),
                                    ),
                                  );
                                }

                                return GestureDetector(
                                  onTap: () {
                                    final p = Map<String, dynamic>.from(post);
                                    p['id'] = docs[index].id;
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => PostDetailScreen(post: p),
                                    ));
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: postImage,
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isProcessingFollow = false;

  Future<String> _currentUsername() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'Seseorang';
    final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    return userSnapshot.data()?['username']?.toString() ?? currentUser.email?.split('@').first ?? 'Seseorang';
  }

  Future<void> _toggleFollow(bool isFollowing) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == widget.userId) return;

    setState(() => _isProcessingFollow = true);

    final currentUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid);
    final targetUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
    final followRef = currentUserRef.collection('following').doc(widget.userId);
    final followerRef = targetUserRef
        .collection('followers')
        .doc(currentUser.uid);

    final batch = FirebaseFirestore.instance.batch();

    if (isFollowing) {
      batch.delete(followRef);
      batch.delete(followerRef);
      batch.update(currentUserRef, {'following': FieldValue.increment(-1)});
      batch.update(targetUserRef, {'followers': FieldValue.increment(-1)});
    } else {
      batch.set(followRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.set(followerRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.update(currentUserRef, {'following': FieldValue.increment(1)});
      batch.update(targetUserRef, {'followers': FieldValue.increment(1)});
    }

    try {
      await batch.commit();
      if (!isFollowing) {
        final fromUsername = await _currentUsername();
        if (widget.userId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('notifications')
              .add({
            'type': 'follow',
            'fromUserId': currentUser.uid,
            'fromUsername': fromUsername,
            'message': '$fromUsername mulai mengikuti Anda',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal ${isFollowing ? 'unfollow' : 'follow'} user: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSelf = currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: isSelf
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.message, color: AppColors.primary),
                  tooltip: 'Kirim Pesan',
                  onPressed: () async {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) return;
                    final chatId = _conversationId(currentUser.uid, widget.userId);
                    final otherSnapshot = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
                    final otherUsername = otherSnapshot.exists
                        ? (otherSnapshot.data()?['username']?.toString() ?? 'Pengguna')
                        : 'Pengguna';
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: chatId,
                        otherUserId: widget.userId,
                        otherUsername: otherUsername,
                      ),
                    ));
                  },
                ),
              ],
      ),
      
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User tidak ditemukan'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final username = data['username']?.toString() ?? 'Unknown';
          final bio = data['bio']?.toString() ?? '';
          final email = data['email']?.toString() ?? '';
          final followers = data['followers'] ?? 0;
          final following = data['following'] ?? 0;
          final avatarUrl = data['avatarUrl']?.toString() ?? '';
          final avatarBase64 = data['avatarBase64']?.toString() ?? '';

          ImageProvider<Object>? avatarImage = _imageProviderFromAvatarStrings(
            base64Str: avatarBase64,
            url: avatarUrl,
          );

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 58,
                  backgroundColor: AppColors.secondary.withOpacity(0.24),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, size: 48, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  username,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('userId', isEqualTo: widget.userId)
                        .snapshots(),
                    builder: (context, postsSnapshot) {
                      final postsCount = postsSnapshot.data?.docs.length ?? 0;
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  statItem('Posts', postsCount.toString()),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => FollowersScreen(userId: widget.userId),
                                  ));
                                },
                                child: statItem('Followers', followers.toString()),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => FollowingScreen(userId: widget.userId),
                                  ));
                                },
                                child: statItem('Following', following.toString()),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                if (!isSelf)
                  StreamBuilder<DocumentSnapshot>(
                    stream: currentUser == null
                        ? Stream<DocumentSnapshot>.empty()
                        : FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser.uid)
                              .collection('following')
                              .doc(widget.userId)
                              .snapshots(),
                    builder: (context, followSnapshot) {
                      final isFollowing =
                          followSnapshot.hasData && followSnapshot.data!.exists;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing
                                            ? AppColors.surface
                                            : AppColors.primary,
                                        foregroundColor: isFollowing
                                            ? AppColors.primary
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        minimumSize: const Size(double.infinity, 48),
                                      ),
                                      onPressed: _isProcessingFollow
                                          ? null
                                          : () => _toggleFollow(isFollowing),
                                      child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        minimumSize: const Size(double.infinity, 48),
                                      ),
                                      onPressed: currentUser == null
                                          ? null
                                          : () {
                                              final chatId = _conversationId(currentUser.uid, widget.userId);
                                              Navigator.of(context).push(MaterialPageRoute(
                                                builder: (_) => ChatScreen(
                                                  conversationId: chatId,
                                                  otherUserId: widget.userId,
                                                  otherUsername: username,
                                                ),
                                              ));
                                            },
                                      child: const Text('Kirim Pesan'),
                                    ),
                                  ],
                                ),
                              );
                    },
                  ),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: widget.userId)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.hasError) {
                      return Center(child: Text('Error: ${postSnapshot.error}'));
                    }
                    if (postSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = postSnapshot.data?.docs.toList() ?? [];

                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final ta = aData['createdAt'];
                      final tb = bData['createdAt'];
                      if (ta == null && tb == null) return 0;
                      if (ta == null) return 1;
                      if (tb == null) return -1;
                      try {
                        return tb.toDate().compareTo(ta.toDate());
                      } catch (_) {
                        return 0;
                      }
                    });

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Postingan',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (docs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.0),
                            child: Center(child: Text('Belum ada postingan')),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final post = docs[index].data() as Map<String, dynamic>;
                                final imageUrl = post['imageUrl']?.toString() ?? '';
                                final imageBase64 = post['imageBase64']?.toString() ?? '';

                                Widget postImage;
                                if (imageUrl.isNotEmpty) {
                                  postImage = Image.network(imageUrl, fit: BoxFit.cover);
                                } else if (imageBase64.isNotEmpty) {
                                  try {
                                    postImage = Image.memory(base64Decode(imageBase64), fit: BoxFit.cover);
                                  } catch (_) {
                                    postImage = Container(
                                      color: AppColors.border,
                                      child: const Center(child: Text('Gambar tidak bisa dimuat')),
                                    );
                                  }
                                } else {
                                  postImage = Container(
                                    color: AppColors.border,
                                    child: const Center(child: Text('Tidak ada gambar')),
                                  );
                                }

                                return GestureDetector(
                                  onTap: () {
                                    final p = Map<String, dynamic>.from(post);
                                    p['id'] = docs[index].id;
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: p)));
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: postImage,
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
