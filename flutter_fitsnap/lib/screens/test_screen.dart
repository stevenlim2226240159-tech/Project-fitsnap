import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTestScreen extends StatelessWidget {
  const FirestoreTestScreen({Key? key}) : super(key: key);

  Future<void> _addDummyPost() async {
    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'username': 'tester',
        'caption': 'Coba insert langsung dari test screen',
        'imageUrl': 'https://via.placeholder.com/300',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Dummy post berhasil ditambahkan ke Firestore');
    } catch (e) {
      print('Error insert Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _addDummyPost,
          child: const Text(
            'Add Dummy Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
