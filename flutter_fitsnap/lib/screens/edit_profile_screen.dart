import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';

ImageProvider<Object>? _avatarFromData(String? base64Str, String? url) {
  try {
    if (base64Str != null && base64Str.trim().isNotEmpty) {
      var s = base64Str.trim();
      final commaIndex = s.indexOf(',');
      if (s.startsWith('data:') && commaIndex != -1) {
        s = s.substring(commaIndex + 1);
      }
      final bytes = base64Decode(s);
      return MemoryImage(bytes);
    }
  } catch (_) {}

  if (url != null && url.trim().isNotEmpty && url.trim().startsWith('http')) {
    return NetworkImage(url.trim());
  }

  return null;
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  Uint8List? _avatarBytes;
  bool _isSaving = false;
  bool _initialized = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _pickAvatar() async {
    if (_user == null) return;
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
    });
  }

  Future<void> _saveProfile() async {
    final user = _user;
    if (user == null) return;
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final data = <String, dynamic>{
      'username': username,
      'bio': bio,
    };
    if (_avatarBytes != null) {
      data['avatarBase64'] = base64Encode(_avatarBytes!);
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: const Center(child: Text('Silakan login terlebih dahulu.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Data user tidak ditemukan.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          if (!_initialized) {
            _initialized = true;
            _usernameController.text = data['username']?.toString() ?? '';
            _bioController.text = data['bio']?.toString() ?? '';
          }

          final avatarUrl = data['avatarUrl']?.toString() ?? '';
          final avatarBase64 = data['avatarBase64']?.toString() ?? '';
          final avatarImage = _avatarFromData(_avatarBytes != null ? base64Encode(_avatarBytes!) : avatarBase64, avatarUrl);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 58,
                        backgroundColor: AppColors.secondary.withOpacity(0.24),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(Icons.person, size: 48, color: Colors.white)
                            : null,
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Profil'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
