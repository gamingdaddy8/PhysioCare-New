import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_models.dart';
import '../services/appointment_service.dart';

const _kPrimary = Color(0xFF1FC7B6);
const _kDark    = Color(0xFF0F172A);
const _kSub     = Color(0xFF64748B);
const _kBg      = Color(0xFFF8FAFC);
const _kAmber   = Color(0xFFF59E0B);

class TherapistAvailabilityScreen extends StatefulWidget {
  const TherapistAvailabilityScreen({super.key});

  @override
  State<TherapistAvailabilityScreen> createState() =>
      _TherapistAvailabilityScreenState();
}

class _TherapistAvailabilityScreenState
    extends State<TherapistAvailabilityScreen>
    with SingleTickerProviderStateMixin {
  final _service  = AppointmentService();
  final _supabase = Supabase.instance.client;

  late final TabController _tabs;
  bool _loading = true;

  List<AvailabilitySlot> _slots       = [];
  List<BlockedDate>      _blocked     = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      final s = await _service.fetchAvailability(uid);
      final b = await _service.fetchBlockedDates(uid);
      setState(() {
        _slots   = s;
        _blocked = b;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddSlotDialog({AvailabilitySlot? editing}) {
    showDialog(
      context: context,
      builder: (_) => _AddSlotDialog(
        existing: editing,
        onSave: (dow, start, end, duration, id) async {
          Navigator.pop(context);
          await _service.upsertAvailability(
            therapistId:         _supabase.auth.currentUser!.id,
            dayOfWeek:           dow,
            startTime:           start,
            endTime:             end,
            slotDurationMinutes: duration,
            existingId:          id,
          );
          await _load();
        },
      ),
    );
  }

  void _openBlockDateDialog() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    ).then((date) async {
      if (date == null) return;

      // Optional reason
      String? reason;
      if (mounted) {
        final ctrl = TextEditingController();
        reason = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Block Date',
                style: TextStyle(fontWeight: FontWeight.w900)),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                  labelText: 'Reason (optional)', hintText: 'e.g. Holiday'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('Block'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      await _service.addBlockedDate(
        therapistId: _supabase.auth.currentUser!.id,
        date:        date,
        reason:      reason?.isEmpty == true ? null : reason,
      );
      await _load();
    });
  }

  Future<void> _deleteSlot(String id) async {
    await _service.deleteAvailability(id);
    await _load();
  }

  Future<void> _unblockDate(String id) async {
    await _service.removeBlockedDate(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Manage Availability',
            style: TextStyle(fontWeight: FontWeight.w900, color: _kDark)),
        iconTheme: const IconThemeData(color: _kDark),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _kPrimary,
          unselectedLabelColor: _kSub,
          indicatorColor: _kPrimary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'Time Slots'),
            Tab(text: 'Blocked Dates'),
          ],
        ),
        actions: [
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
                _SlotsTab(
                  slots:       _slots,
                  onAdd:       () => _openAddSlotDialog(),
                  onEdit:      (s) => _openAddSlotDialog(editing: s),
                  onDelete:    (id) => _deleteSlot(id),
                ),
                _BlockedTab(
                  blocked:    _blocked,
                  onAdd:      _openBlockDateDialog,
                  onUnblock:  (id) => _unblockDate(id),
                ),
              ],
            ),
    );
  }
}

// ── Slots Tab ─────────────────────────────────────────────────────────────────

class _SlotsTab extends StatelessWidget {
  final List<AvailabilitySlot> slots;
  final VoidCallback onAdd;
  final ValueChanged<AvailabilitySlot> onEdit;
  final ValueChanged<String> onDelete;

  const _SlotsTab({
    required this.slots,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Group by day
    final Map<int, List<AvailabilitySlot>> byDay = {};
    for (final s in slots) {
      byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }

    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _PrimaryButton(label: '+ Add Time Window', onTap: onAdd),
            const SizedBox(height: 18),

            if (slots.isEmpty)
              _EmptyCard(
                icon: Icons.schedule_outlined,
                text: 'No availability set yet.\nAdd time windows so patients can book appointments.',
              )
            else
              ...List.generate(7, (dow) {
                final daySlots = byDay[dow] ?? [];
                if (daySlots.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        days[dow],
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900, color: _kDark),
                      ),
                    ),
                    ...daySlots.map((s) => _SlotRow(
                          slot:     s,
                          onEdit:   () => onEdit(s),
                          onDelete: () => onDelete(s.id),
                        )),
                    const SizedBox(height: 8),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final AvailabilitySlot slot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SlotRow({required this.slot, required this.onEdit, required this.onDelete});

  String _fmt(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return t;
    int h = int.parse(parts[0]);
    final m      = parts[1];
    final suffix = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            height: 40, width: 40,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time, color: _kPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmt(slot.startTime)} → ${_fmt(slot.endTime)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _kDark),
                ),
                Text(
                  '${slot.slotDurationMinutes} min slots  •  ${slot.timeSlots.length} slots/day',
                  style: const TextStyle(fontSize: 12, color: _kSub),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18, color: _kSub),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Blocked Dates Tab ─────────────────────────────────────────────────────────

class _BlockedTab extends StatelessWidget {
  final List<BlockedDate> blocked;
  final VoidCallback onAdd;
  final ValueChanged<String> onUnblock;

  const _BlockedTab({
    required this.blocked,
    required this.onAdd,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _PrimaryButton(
              label: '+ Block a Date',
              onTap: onAdd,
              color: _kAmber,
            ),
            const SizedBox(height: 18),

            if (blocked.isEmpty)
              _EmptyCard(
                icon: Icons.event_available_outlined,
                text: 'No blocked dates.\nBlock dates for holidays or leaves.',
              )
            else
              ...blocked.map((b) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40, width: 40,
                          decoration: BoxDecoration(
                            color: _kAmber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_busy, color: _kAmber, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${b.blockedDate.day}/${b.blockedDate.month}/${b.blockedDate.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, color: _kDark),
                              ),
                              if (b.reason != null && b.reason!.isNotEmpty)
                                Text(b.reason!,
                                    style: const TextStyle(fontSize: 12, color: _kSub)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => onUnblock(b.id),
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Unblock'),
                          style: TextButton.styleFrom(foregroundColor: _kAmber),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ── Add Slot Dialog ───────────────────────────────────────────────────────────

class _AddSlotDialog extends StatefulWidget {
  final AvailabilitySlot? existing;
  final void Function(int dow, String start, String end, int duration, String? id) onSave;

  const _AddSlotDialog({this.existing, required this.onSave});

  @override
  State<_AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends State<_AddSlotDialog> {
  int _dow         = 1; // Monday
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 13, minute: 0);
  int _duration    = 30;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _dow = e.dayOfWeek;
      final sp = e.startTime.split(':');
      final ep = e.endTime.split(':');
      _start = TimeOfDay(hour: int.parse(sp[0]), minute: int.parse(sp[1]));
      _end   = TimeOfDay(hour: int.parse(ep[0]), minute: int.parse(ep[1]));
      _duration = e.slotDurationMinutes;
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) _start = picked;
      else          _end   = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday',
                  'Thursday', 'Friday', 'Saturday'];

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Time Window' : 'Edit Time Window',
          style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Day of Week',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _dow,
              items: List.generate(7, (i) => DropdownMenuItem(
                value: i,
                child: Text(days[i]),
              )),
              onChanged: (v) => setState(() => _dow = v!),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(child: _TimePicker(
                  label: 'Start Time',
                  time: _start,
                  onTap: () => _pickTime(isStart: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: _TimePicker(
                  label: 'End Time',
                  time: _end,
                  onTap: () => _pickTime(isStart: false),
                )),
              ],
            ),
            const SizedBox(height: 14),

            const Text('Slot Duration (minutes)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _duration,
              items: [15, 20, 30, 45, 60].map((d) => DropdownMenuItem(
                value: d,
                child: Text('$d minutes'),
              )).toList(),
              onChanged: (v) => setState(() => _duration = v!),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, foregroundColor: Colors.white),
          onPressed: () => widget.onSave(
            _dow,
            _fmtTime(_start),
            _fmtTime(_end),
            _duration,
            widget.existing?.id,
          ),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePicker({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final h      = time.hour;
    final m      = time.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hr     = h > 12 ? h - 12 : (h == 0 ? 12 : h);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: _kSub),
                const SizedBox(width: 8),
                Text('$hr:$m $suffix',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.color = _kPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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