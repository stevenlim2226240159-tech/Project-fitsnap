import 'package:flutter/material.dart';
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
    _FeedScreen(),
    PostPhotoScreen(),
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
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text('FitSnap', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.deepPurple),
              onPressed: () {
                showSearch(context: context, delegate: _UserSearchDelegate());
              },
            ),
          ],
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AssetImage('assets/avatar.png'),
                        radius: 24,
                      ),
                      title: Text('Username', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('2 hours ago'),
                      trailing: Icon(Icons.more_vert),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/post_sample.jpg', fit: BoxFit.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.favorite_border, color: Colors.redAccent),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(Icons.comment_outlined, color: Colors.deepPurple),
                            onPressed: () {},
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.bookmark_border, color: Colors.deepPurple),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Liked by user123 and 20 others', style: TextStyle(color: Colors.grey[700])),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text('This is a sample caption.', style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              );
            },
            childCount: 10,
          ),
        ),
      ],
    );
  }
}

class _UserSearchDelegate extends SearchDelegate<String> {
  final List<String> usernames = [
    'john', 'jane', 'alex', 'steve', 'maria', 'fituser', 'snapper', 'workoutguy', 'runner', 'yogaqueen'
  ];

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = usernames.where((u) => u.contains(query.toLowerCase())).toList();
    return ListView(
      children: results.map((u) => ListTile(title: Text(u))).toList(),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = usernames.where((u) => u.contains(query.toLowerCase())).toList();
    return ListView(
      children: suggestions.map((u) => ListTile(title: Text(u))).toList(),
    );
  }
}
