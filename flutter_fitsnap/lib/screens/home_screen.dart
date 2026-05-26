import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'post_photo_screen.dart';
import 'sign_in_screen.dart';

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
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Post'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: Colors.deepPurpleAccent.withOpacity(0.1),
      ),
    );
  }
}

class _FeedScreen extends StatelessWidget {
  const _FeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Belum ada postingan'));
        }

        final posts = snapshot.data!.docs;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              backgroundColor: Colors.white,
              title: const Text(
                'FitSnap',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = posts[index].data() as Map<String, dynamic>;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                              post['avatarUrl'] ??
                                  'https://via.placeholder.com/150',
                            ),
                            radius: 24,
                          ),
                          title: Text(post['username'] ?? 'Unknown',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(post['createdAt'] != null
                              ? post['createdAt']
                                  .toDate()
                                  .toString()
                              : ''),
                          trailing: const Icon(Icons.more_vert),
                        ),
                        if (post['imageUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              post['imageUrl'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text(post['caption'] ?? '',
                              style: const TextStyle(fontSize: 15)),
                        ),
                      ],
                    ),
                  );
                },
                childCount: posts.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
