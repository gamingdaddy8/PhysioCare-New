import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_models.dart';
import '../services/appointment_service.dart';

const _kPrimary = Color(0xFF1FC7B6);
const _kDark    = Color(0xFF0F172A);
const _kSub     = Color(0xFF64748B);
const _kBg      = Color(0xFFF8FAFC);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service  = AppointmentService();
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final list = await _service.fetchNotifications(uid);
      setState(() => _notifications = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await _service.markAllNotificationsRead(uid);
    await _load();
  }

  Future<void> _markRead(String id) async {
    await _service.markNotificationRead(id);
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = NotificationModel(
          id:          _notifications[idx].id,
          userId:      _notifications[idx].userId,
          title:       _notifications[idx].title,
          body:        _notifications[idx].body,
          type:        _notifications[idx].type,
          referenceId: _notifications[idx].referenceId,
          isRead:      true,
          createdAt:   _notifications[idx].createdAt,
        );
      }
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _typeIcon(String type) {
    if (type.contains('confirmed')) return Icons.check_circle;
    if (type.contains('rejected'))  return Icons.cancel;
    if (type.contains('pending'))   return Icons.schedule;
    if (type.contains('cancelled')) return Icons.block;
    return Icons.notifications;
  }

  Color _typeColor(String type) {
    if (type.contains('confirmed')) return const Color(0xFF22C55E);
    if (type.contains('rejected'))  return const Color(0xFFEF4444);
    if (type.contains('pending'))   return const Color(0xFFF59E0B);
    return _kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications',
                style: TextStyle(fontWeight: FontWeight.w900, color: _kDark)),
            if (unread > 0)
              Text('$unread unread',
                  style: const TextStyle(fontSize: 12, color: _kSub)),
          ],
        ),
        iconTheme: const IconThemeData(color: _kDark),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w700)),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _kDark),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 56, color: _kSub),
                  SizedBox(height: 14),
                  Text('No notifications yet.',
                      style: TextStyle(color: _kSub, fontSize: 16)),
                ],
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final color = _typeColor(n.type);

                      return GestureDetector(
                        onTap: () {
                          if (!n.isRead) _markRead(n.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: n.isRead ? Colors.white : color.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: n.isRead ? Colors.black12 : color.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 40, width: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_typeIcon(n.type), color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(n.title,
                                              style: TextStyle(
                                                fontWeight: n.isRead
                                                    ? FontWeight.w700
                                                    : FontWeight.w900,
                                                color: _kDark,
                                                fontSize: 14,
                                              )),
                                        ),
                                        if (!n.isRead)
                                          Container(
                                            height: 8, width: 8,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n.body,
                                        style: const TextStyle(
                                            fontSize: 13, color: _kSub, height: 1.4)),
                                    const SizedBox(height: 6),
                                    Text(_timeAgo(n.createdAt),
                                        style: const TextStyle(
                                            fontSize: 11, color: _kSub)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

/// A small badge widget to show unread count on a bell icon.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _service  = AppointmentService();
  final _supabase = Supabase.instance.client;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final count = await _service.fetchUnreadCount(uid);
    if (mounted) setState(() => _unread = count);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none),
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            _loadCount();
          },
        ),
        if (_unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              height: 16, width: 16,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
      ],
    );
  }
}