import 'package:flutter/material.dart';

class PhotoDetailScreen extends StatelessWidget {
  final String photoId;

  const PhotoDetailScreen({super.key, required this.photoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo')),
      body: Center(child: Text('Photo $photoId')),
    );
  }
}
