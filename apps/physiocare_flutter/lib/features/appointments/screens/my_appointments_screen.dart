import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_models.dart';
import '../services/appointment_service.dart';
import 'book_appointment_screen.dart';

const _kPrimary = Color(0xFF1FC7B6);
const _kDark    = Color(0xFF0F172A);
const _kSub     = Color(0xFF64748B);
const _kBg      = Color(0xFFF8FAFC);

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final _service  = AppointmentService();
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  List<AppointmentModel> _appointments = [];

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
      final list = await _service.fetchPatientAppointments(uid);
      setState(() => _appointments = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(AppointmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Appointment?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
            'Cancel your appointment on ${apt.formattedDate} at ${apt.formattedTime}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel Appointment')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.cancelAppointment(
        apt.id,
        cancelledBy: 'patient',
        reason: 'Cancelled by patient',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _appointments
        .where((a) => a.status == AppointmentStatus.pending ||
                      a.status == AppointmentStatus.confirmed)
        .toList();
    final past = _appointments
        .where((a) => a.status == AppointmentStatus.rejected ||
                      a.status == AppointmentStatus.cancelled ||
                      (a.status == AppointmentStatus.confirmed &&
                       a.appointmentDate.isBefore(DateTime.now())))
        .toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('My Appointments',
            style: TextStyle(fontWeight: FontWeight.w900, color: _kDark)),
        iconTheme: const IconThemeData(color: _kDark),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _kDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Book', style: TextStyle(fontWeight: FontWeight.w900)),
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BookAppointmentScreen()));
          _load();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      // Upcoming
                      const _SectionHeader('Upcoming & Pending'),
                      const SizedBox(height: 10),
                      if (upcoming.isEmpty)
                        _EmptyCard(
                          icon: Icons.calendar_today_outlined,
                          text: 'No upcoming appointments.\nTap "Book" to schedule one.',
                        )
                      else
                        ...upcoming.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AppointmentCard(
                                apt: a,
                                showCancel: a.status == AppointmentStatus.pending,
                                onCancel: () => _cancel(a),
                              ),
                            )),

                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const _SectionHeader('History'),
                        const SizedBox(height: 10),
                        ...past.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AppointmentCard(apt: a, showCancel: false),
                            )),
                      ],

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900, color: _kDark));
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel apt;
  final bool showCancel;
  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.apt,
    required this.showCancel,
    this.onCancel,
  });

  Color _statusColor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.pending:   return const Color(0xFFF59E0B);
      case AppointmentStatus.confirmed: return const Color(0xFF22C55E);
      case AppointmentStatus.rejected:  return const Color(0xFFEF4444);
      case AppointmentStatus.cancelled: return const Color(0xFF94A3B8);
    }
  }

  IconData _statusIcon(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.pending:   return Icons.schedule;
      case AppointmentStatus.confirmed: return Icons.check_circle;
      case AppointmentStatus.rejected:  return Icons.cancel;
      case AppointmentStatus.cancelled: return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(apt.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width:  44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(apt.status), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.therapistName ?? 'Therapist',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: _kDark)),
                    Text('${apt.formattedDate}  •  ${apt.formattedTime}',
                        style: const TextStyle(color: _kSub, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  apt.status.label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color),
                ),
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
                  const Icon(Icons.chat_bubble_outline,
                      size: 14, color: _kSub),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(apt.patientQuery!,
                        style: const TextStyle(fontSize: 13, color: _kDark)),
                  ),
                ],
              ),
            ),
          ],

          if (apt.therapistNotes != null && apt.therapistNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_information_outlined,
                      size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Therapist: ${apt.therapistNotes!}',
                        style: const TextStyle(fontSize: 13, color: _kDark)),
                  ),
                ],
              ),
            ),
          ],

          if (showCancel) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              label: const Text('Cancel Request',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: _kSub),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kSub, height: 1.5)),
        ],
      ),
    );
  }
}