import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme.dart';

class PostPhotoScreen extends StatefulWidget {
  const PostPhotoScreen({Key? key}) : super(key: key);

  @override
  State<PostPhotoScreen> createState() => _PostPhotoScreenState();
}

class _PostPhotoScreenState extends State<PostPhotoScreen> {
  Uint8List? _imageBytes;
  String? _base64Image;
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
    }
  }

  Future<void> _uploadPost() async {
    if (_base64Image == null || _captionController.text.isEmpty) return;
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User belum login');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final username =
          userDoc.data()?['username']?.toString() ?? user.email ?? 'Unknown';
        final avatarBase64 =
          userDoc.data()?['avatarBase64']?.toString() ?? '';
        final avatarUrl = userDoc.data()?['avatarUrl']?.toString() ?? '';

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'username': username,
        'avatarBase64': avatarBase64,
        'avatarUrl': avatarUrl,
        'caption': _captionController.text,
        'imageBase64': _base64Image,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'postsCount': FieldValue.increment(1)},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post berhasil ditambahkan')),
      );
      setState(() {
        _imageBytes = null;
        _base64Image = null;
        _captionController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload gagal: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewWidget = _imageBytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add_a_photo, size: 64, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'Ketuk untuk pilih foto',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Post Photo'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bagikan Momen Terbaikmu',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih foto, tambahkan caption singkat, dan biarkan komunitas terinspirasi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: previewWidget,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                labelText: 'Caption',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _uploadPost,
                      child: const Text(
                        'Upload',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
