import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value.trim();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildSearchStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('username')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cari Username'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                hintText: 'Cari username...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildSearchStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allUsers = snapshot.data?.docs ?? [];
                final filteredUsers = _query.isEmpty
                    ? allUsers
                    : allUsers.where((doc) {
                        final username = doc.data()['username']?.toString().toLowerCase() ?? '';
                        return username.contains(_query.toLowerCase());
                      }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text('Tidak ditemukan pengguna dengan username tersebut.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final data = filteredUsers[index].data();
                    final userId = filteredUsers[index].id;
                      final username = data['username']?.toString() ?? 'Pengguna';
                      final email = data['email']?.toString() ?? '';
                      final avatarUrl = data['avatarUrl']?.toString() ?? '';
                      final avatarBase64 = data['avatarBase64']?.toString() ?? '';

                      ImageProvider<Object>? avatarImage;
                      if (avatarBase64.isNotEmpty) {
                        try {
                          avatarImage = MemoryImage(base64Decode(avatarBase64));
                        } catch (_) {
                          avatarImage = null;
                        }
                      }
                      if (avatarImage == null && avatarUrl.isNotEmpty) {
                        avatarImage = NetworkImage(avatarUrl);
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondary.withOpacity(0.2),
                          backgroundImage: avatarImage,
                          child: avatarImage == null ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: email.isNotEmpty ? Text(email) : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: userId),
                          ));
                        },
                      );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
