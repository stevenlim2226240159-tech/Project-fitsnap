import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onLogout;
  const ProfileScreen({Key? key, this.onLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
            onPressed: onLogout ?? () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final username = data['username'] ?? 'Unknown';
          final avatarUrl = data['avatarUrl'] ??
              'https://via.placeholder.com/150'; // default avatar
          final postsCount = data['postsCount'] ?? 0;
          final followers = data['followers'] ?? 0;
          final following = data['following'] ?? 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.deepPurple.shade100,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                ),
                const SizedBox(height: 16),
                Text(username,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.deepPurple)),
                const SizedBox(height: 8),
                Text(user?.email ?? '',
                    style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 24),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                      .where('userId', isEqualTo: user?.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (!postSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final posts = postSnapshot.data!.docs;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index].data() as Map<String, dynamic>;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(post['imageUrl'],
                                fit: BoxFit.cover),
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
