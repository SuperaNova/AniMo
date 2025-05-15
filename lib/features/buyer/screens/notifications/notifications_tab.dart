import 'package:flutter/material.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'No new notifications',
            style: TextStyle(fontSize: 22, color: Colors.grey),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'This is where you will see updates about your requests, matches, and other important alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}