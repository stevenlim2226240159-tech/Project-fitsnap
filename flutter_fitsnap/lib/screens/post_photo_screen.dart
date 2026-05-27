import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostPhotoScreen extends StatefulWidget {
  const PostPhotoScreen({Key? key}) : super(key: key);

  @override
  State<PostPhotoScreen> createState() => _PostPhotoScreenState();
}

class _PostPhotoScreenState extends State<PostPhotoScreen> {
  XFile? _pickedFile;
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
          _pickedFile = pickedFile;
          _imageBytes = bytes;
          _base64Image = base64Encode(bytes); // simpan base64
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _uploadPost() async {
    if (_base64Image == null || _captionController.text.isEmpty) return;
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final username = userDoc.data()?['username']?.toString() ?? user.email ?? 'Unknown';

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'username': username,
        'caption': _captionController.text,
        'imageBase64': _base64Image, // simpan base64 string
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Post berhasil ditambahkan')));
      setState(() {
        _pickedFile = null;
        _imageBytes = null;
        _base64Image = null;
        _captionController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload gagal: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewWidget = _imageBytes != null
        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
        : const Center(child: Icon(Icons.add_a_photo,
            size: 64, color: Colors.deepPurple));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Photo'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: previewWidget,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _uploadPost,
                      child: const Text('Post',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
