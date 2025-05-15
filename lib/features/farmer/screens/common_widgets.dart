import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget buildActivityDisplayItem({
  required IconData icon,
  required Color iconBgColor,
  required Color iconColor,
  required String title,
  required String subtitle,
  required String amountOrStatus,
}) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    elevation: 1.0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: iconBgColor,
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      trailing: Text(
        amountOrStatus,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF4A2E2B)),
      ),
    ),
  );
}
