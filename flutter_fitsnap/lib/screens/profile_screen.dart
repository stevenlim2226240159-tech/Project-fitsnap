import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

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
    final user = _user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Profile',
              style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Silakan login terlebih dahulu.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.deepPurple),
            tooltip: 'Logout',
            onPressed: widget.onLogout ?? () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting || _isCreatingUserDoc) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            if (user != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _createDefaultUserDoc(user);
              });
            }
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final username = data['username']?.toString() ?? 'Unknown';
          final avatarUrl = data['avatarUrl']?.toString() ?? '';
          final avatarBase64 = data['avatarBase64']?.toString() ?? '';
          final postsCount = data['postsCount'] ?? 0;
          final followers = data['followers'] ?? 0;
          final following = data['following'] ?? 0;

          ImageProvider<Object>? avatarImage;
          if (_avatarBytes != null) {
            avatarImage = MemoryImage(_avatarBytes!);
          } else if (avatarBase64.isNotEmpty) {
            try {
              avatarImage = MemoryImage(base64Decode(avatarBase64));
            } catch (_) {
              avatarImage = null;
            }
          } else if (avatarUrl.isNotEmpty) {
            avatarImage = NetworkImage(avatarUrl);
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? const Icon(Icons.person, size: 48, color: Colors.white)
                          : null,
                    ),
                    GestureDetector(
                      onTap: _isSavingAvatar ? null : _pickAvatar,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: _isSavingAvatar
                            ? const Padding(
                                padding: EdgeInsets.all(6.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.edit, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(username,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.deepPurple)),
                const SizedBox(height: 8),
                Text(user.email ?? '', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 24),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text('$postsCount',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.deepPurple)),
                            const Text('Posts'),
                          ],
                        ),
                        Column(
                          children: [
                            Text('$followers',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.deepPurple)),
                            const Text('Followers'),
                          ],
                        ),
                        Column(
                          children: [
                            Text('$following',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.deepPurple)),
                            const Text('Following'),
                          ],
                        ),
                      ],
                    ),
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
                      return Center(child: Text('Error: ${postSnapshot.error}'));
                    }
                    if (postSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Center(child: Text('Belum ada postingan')), 
                      );
                    }

                    // Sort documents client-side to avoid requiring a Firestore composite index
                    final docs = postSnapshot.data!.docs.toList();
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
                    final posts = docs;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index].data() as Map<String, dynamic>;
                          final imageUrl = post['imageUrl']?.toString() ?? '';
                          final imageBase64 = post['imageBase64']?.toString() ?? '';

                          Widget postImage;
                          if (imageUrl.isNotEmpty) {
                            postImage = Image.network(imageUrl, fit: BoxFit.cover);
                          } else if (imageBase64.isNotEmpty) {
                            try {
                              postImage = Image.memory(
                                base64Decode(imageBase64),
                                fit: BoxFit.cover,
                              );
                            } catch (_) {
                              postImage = Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Text('Gambar tidak bisa dimuat'),
                                ),
                              );
                            }
                          } else {
                            postImage = Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Text('Tidak ada gambar'),
                              ),
                            );
                          }

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: postImage,
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
