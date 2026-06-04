import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
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
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'Post',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        height: 70,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.secondary.withOpacity(0.16),
      ),
    );
  }
}

class _FeedScreen extends StatelessWidget {
  const _FeedScreen({Key? key}) : super(key: key);

  static const double _imageHeight = 260;

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
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
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
                                    backgroundImage: NetworkImage(
                                      post['avatarUrl'] ??
                                          'https://via.placeholder.com/150',
                                    ),
                                    backgroundColor: AppColors.secondary
                                        .withOpacity(0.24),
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
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            child: Text(
                              post['caption'] ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
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
