import 'package:flutter/material.dart';

class ClusterDetailScreen extends StatelessWidget {
  final int clusterId;

  const ClusterDetailScreen({super.key, required this.clusterId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Person')),
      body: Center(child: Text('Cluster $clusterId')),
    );
  }
}
