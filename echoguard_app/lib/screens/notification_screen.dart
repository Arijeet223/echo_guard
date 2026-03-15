import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _hasUnreadNotifications = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_hasUnreadNotifications)
            TextButton(
              onPressed: () => setState(() => _hasUnreadNotifications = false),
              child: Text('Mark all as read', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _notificationItem(
            theme: theme,
            title: 'High Risk Alert',
            body: 'A recent claim you scanned has been flagged as severe misinformation.',
            time: '2 mins ago',
            icon: Icons.warning_amber_rounded,
            color: Color(0xFF8B0000),
            isUnread: _hasUnreadNotifications,
          ),
          _notificationItem(
            theme: theme,
            title: 'Weekly Summary Ready',
            body: 'You scanned 14 articles this week. 8 were verified as truthful.',
            time: '1 day ago',
            icon: Icons.analytics_outlined,
            color: theme.colorScheme.primary,
            isUnread: false,
          ),
          _notificationItem(
            theme: theme,
            title: 'System Update',
            body: 'Veritas AI models have been updated successfully.',
            time: '3 days ago',
            icon: Icons.system_update_alt,
            color: Colors.black,
            isUnread: false,
          ),
        ],
      ),
    );
  }

  Widget _notificationItem({
    required ThemeData theme,
    required String title,
    required String body,
    required String time,
    required IconData icon,
    required Color color,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? color.withOpacity(0.05) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnread ? color.withOpacity(0.3) : theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
                    Text(time, style: TextStyle(fontSize: 10, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
