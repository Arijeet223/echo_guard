import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../main.dart';
import 'notification_screen.dart';
import 'history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  String _username = '@Veritas_User';
  String _bio = 'Passionate about digital truth and combating misinformation.';
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  List<HistoryItem> _history = [];
  Uint8List? _imageBytes; // In-memory profile photo

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await StorageService.getUsername();
    final bio = await StorageService.getBio();
    final history = await StorageService.getHistory();
    setState(() {
      _username = name;
      _bio = bio;
      _nameCtrl.text = name;
      _bioCtrl.text = bio;
      _history = history;
    });
  }

  Future<void> _saveProfile() async {
    await StorageService.setUsername(_nameCtrl.text.trim());
    await StorageService.setBio(_bioCtrl.text.trim());
    setState(() {
      _username = _nameCtrl.text.trim();
      _bio = _bioCtrl.text.trim();
      _isEditing = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Color _verdictColor(String v) {
    if (v == 'Verified') return const Color(0xFF556B2F);
    if (v == 'Misleading') return Color(0xFFCD853F);
    return Color(0xFF8B0000);
  }

  IconData _verdictIcon(String v) {
    if (v == 'Verified') return Icons.check_circle;
    if (v == 'High Risk') return Icons.warning;
    return Icons.post_add;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
            child: Text(
              _isEditing ? 'Save' : 'Edit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isEditing ? const Color(0xFF556B2F) : const Color(0xFF4A342A),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            // Avatar — tappable in edit mode
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _isEditing ? _pickImage : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFB2967D).withOpacity(0.3), width: 4),
                      gradient: const LinearGradient(colors: [Color(0xFF4A342A), Color(0xFFB2967D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: const Color(0xFF4A342A),
                      backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                      child: _imageBytes == null ? const Icon(Icons.person, size: 48, color: Color(0xFFD7C9B8)) : null,
                    ),
                  ),
                  // Camera overlay in edit mode
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFF4A342A), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD7C9B8), width: 2)),
                      child: const Icon(Icons.photo_camera, size: 16, color: Color(0xFFD7C9B8)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFB2967D), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD7C9B8), width: 2)),
                      child: const Icon(Icons.verified, size: 14, color: Color(0xFFD7C9B8)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Username & Bio
            if (_isEditing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(children: [
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(controller: _bioCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder())),
                ]),
              ),
            ] else ...[
              Text(_username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('ELITE VERIFIER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A342A), letterSpacing: 0.8)),
                Container(margin: const EdgeInsets.symmetric(horizontal: 6), width: 4, height: 4, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                Text('Joined March 2026', style: TextStyle(fontSize: 12, color: Colors.black)),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(_bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black)),
              ),
            ],

            const SizedBox(height: 24),

            // Stats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _statCard('Truth Score', '984', '+12'),
                  const SizedBox(width: 12),
                  _statCard('Verified', '${_history.where((h) => h.verdict == "Verified").length}', '+5'),
                  const SizedBox(width: 12),
                  _statCard('Accuracy', '99.2%', '+0.1%'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent Activity
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen()));
                    },
                    child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Icon(Icons.history_toggle_off, size: 40, color: Colors.black),
                  const SizedBox(height: 8),
                  Text('No recent activity', style: TextStyle(fontSize: 14, color: Colors.black)),
                ]),
              )
            else
              ...(_history.take(3).map((item) => _activityItem(item, theme))),

            const SizedBox(height: 24),

            // Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
                    child: Column(children: [
                      _settingsItem(Icons.language, 'Language', trailing: 'English', theme: theme),
                      Divider(height: 1, color: theme.dividerColor),
                      _settingsItem(Icons.dark_mode, 'Dark Mode', isToggle: true, theme: theme, isDark: isDark),
                      Divider(height: 1, color: theme.dividerColor),
                      _settingsItem(
                        Icons.notifications_active, 
                        'Notifications', 
                        theme: theme, 
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      _settingsItem(Icons.logout, 'Logout', isDestructive: true, theme: theme),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, String delta) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFFD7C9B8).withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black),
        ),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Colors.black)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A342A))),
          const SizedBox(height: 2),
          Text(delta, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
        ]),
      ),
    );
  }

  Widget _activityItem(HistoryItem item, ThemeData theme) {
    final color = _verdictColor(item.verdict);
    final icon = _verdictIcon(item.verdict);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Analyzed: "${item.text}"', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${item.verdict} (Score: ${item.score.toStringAsFixed(0)}/100)', style: TextStyle(fontSize: 11, color: Colors.black)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _settingsItem(IconData icon, String label, {String? trailing, bool isToggle = false, bool isDestructive = false, required ThemeData theme, bool isDark = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Color(0xFF8B0000) : theme.iconTheme.color),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDestructive ? Color(0xFF8B0000) : theme.textTheme.bodyLarge?.color)),
      trailing: trailing != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Text(trailing, style: TextStyle(fontSize: 13, color: Colors.black)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.black),
            ])
          : isToggle
              ? Switch(
                  value: isDark, 
                  onChanged: (_) {
                    VeritasApp.themeProvider.toggle();
                  },
                  activeColor: theme.colorScheme.primary,
                )
              : Icon(Icons.chevron_right, color: Colors.black),
      onTap: onTap ?? (isDestructive ? () async {
        final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text('Logout', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
          content: Text('Are you sure you want to log out?', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Color(0xFF8B0000)))),
          ],
        ));
        if (confirm == true) {
          await StorageService.clearHistory();
          _loadProfile();
        }
      } : null),
    );
  }
}
