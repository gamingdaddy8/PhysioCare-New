import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_models.dart';
import '../services/appointment_service.dart';
import 'therapist_availability_screen.dart';

const _kPrimary = Color(0xFF1FC7B6);
const _kDark    = Color(0xFF0F172A);
const _kSub     = Color(0xFF64748B);
const _kBg      = Color(0xFFF8FAFC);

class TherapistBookingsScreen extends StatefulWidget {
  const TherapistBookingsScreen({super.key});

  @override
  State<TherapistBookingsScreen> createState() => _TherapistBookingsScreenState();
}

class _TherapistBookingsScreenState extends State<TherapistBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _service  = AppointmentService();
  final _supabase = Supabase.instance.client;

  late final TabController _tabs;
  bool _loading = true;

  List<AppointmentModel> _pending   = [];
  List<AppointmentModel> _confirmed = [];
  List<AppointmentModel> _history   = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;

      final all = await _service.fetchTherapistAppointments(uid);
      setState(() {
        _pending   = all.where((a) => a.status == AppointmentStatus.pending).toList();
        _confirmed = all.where((a) => a.status == AppointmentStatus.confirmed).toList();
        _history   = all.where((a) =>
            a.status == AppointmentStatus.rejected ||
            a.status == AppointmentStatus.cancelled).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DB Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(AppointmentModel apt, bool accept) async {
    String? notes;
    if (!accept) {
      // Ask for rejection reason
      final ctrl = TextEditingController();
      notes = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reason for Rejection',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Optional note to patient...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (notes == null) return; // cancelled
    } else {
      // Confirm accept
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Appointment?',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
              'Accept appointment for ${apt.patientName ?? "patient"} on '
              '${apt.formattedDate} at ${apt.formattedTime}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    try {
      if (accept) {
        await _service.acceptAppointment(apt.id);
      } else {
        await _service.rejectAppointment(apt.id, reason: notes?.isEmpty == true ? null : notes);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Appointment Requests',
            style: TextStyle(fontWeight: FontWeight.w900, color: _kDark)),
        iconTheme: const IconThemeData(color: _kDark),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _kPrimary,
          unselectedLabelColor: _kSub,
          indicatorColor: _kPrimary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: 'Pending${_pending.isNotEmpty ? " (${_pending.length})" : ""}'),
            Tab(text: 'Confirmed'),
            Tab(text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manage Availability',
            icon: const Icon(Icons.schedule, color: _kDark),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TherapistAvailabilityScreen())),
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
          : TabBarView(
              controller: _tabs,
              children: [
                _AppointmentList(
                  appointments: _pending,
                  emptyText:    'No pending requests.\nPatients can book once you set availability.',
                  emptyIcon:    Icons.pending_actions_outlined,
                  itemBuilder:  (apt) => _PendingCard(
                    apt:      apt,
                    onAccept: () => _respond(apt, true),
                    onReject: () => _respond(apt, false),
                  ),
                ),
                _AppointmentList(
                  appointments: _confirmed,
                  emptyText:    'No confirmed appointments.',
                  emptyIcon:    Icons.event_available_outlined,
                  itemBuilder:  (apt) => _SimpleCard(apt: apt),
                ),
                _AppointmentList(
                  appointments: _history,
                  emptyText:    'No history yet.',
                  emptyIcon:    Icons.history,
                  itemBuilder:  (apt) => _SimpleCard(apt: apt, showStatus: true),
                ),
              ],
            ),
    );
  }
}

// ── List wrapper ──────────────────────────────────────────────────────────────

class _AppointmentList extends StatelessWidget {
  final List<AppointmentModel> appointments;
  final String emptyText;
  final IconData emptyIcon;
  final Widget Function(AppointmentModel) itemBuilder;

  const _AppointmentList({
    required this.appointments,
    required this.emptyText,
    required this.emptyIcon,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 48, color: _kSub),
            const SizedBox(height: 14),
            Text(emptyText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kSub, height: 1.5)),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => itemBuilder(appointments[i]),
        ),
      ),
    );
  }
}

// ── Pending Card (with accept / reject buttons) ───────────────────────────────

class _PendingCard extends StatelessWidget {
  final AppointmentModel apt;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingCard({
    required this.apt,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.patientName ?? 'Patient',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15, color: _kDark)),
                    Text('${apt.formattedDate}  •  ${apt.formattedTime}',
                        style: const TextStyle(color: _kSub, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Pending',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B))),
              ),
            ],
          ),

          if (apt.patientQuery != null && apt.patientQuery!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 14, color: _kSub),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(apt.patientQuery!,
                        style: const TextStyle(fontSize: 13, color: _kDark, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onReject,
                  child: const Text('Reject',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onAccept,
                  child: const Text('Accept',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Simple Card (confirmed / history) ─────────────────────────────────────────

class _SimpleCard extends StatelessWidget {
  final AppointmentModel apt;
  final bool showStatus;

  const _SimpleCard({required this.apt, this.showStatus = false});

  Color get _color {
    switch (apt.status) {
      case AppointmentStatus.confirmed: return const Color(0xFF22C55E);
      case AppointmentStatus.rejected:  return const Color(0xFFEF4444);
      case AppointmentStatus.cancelled: return const Color(0xFF94A3B8);
      default: return _kSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              apt.status == AppointmentStatus.confirmed
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              color: _color, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apt.patientName ?? 'Patient',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15, color: _kDark)),
                Text('${apt.formattedDate}  •  ${apt.formattedTime}',
                    style: const TextStyle(color: _kSub, fontSize: 13)),
                if (apt.therapistNotes != null && apt.therapistNotes!.isNotEmpty)
                  Text('Note: ${apt.therapistNotes!}',
                      style: const TextStyle(color: _kSub, fontSize: 12)),
              ],
            ),
          ),
          if (showStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(apt.status.label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: _color)),
            ),
        ],
      ),
    );
  }
}