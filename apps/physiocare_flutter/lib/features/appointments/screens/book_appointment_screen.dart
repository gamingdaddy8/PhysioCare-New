import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_models.dart';
import '../services/appointment_service.dart';

// ── Brand colours (matches app-wide palette) ─────────────────────────────────
const _kPrimary  = Color(0xFF1FC7B6);
const _kDark     = Color(0xFF0F172A);
const _kSub      = Color(0xFF64748B);
const _kBg       = Color(0xFFF8FAFC);
const _kCardBg   = Colors.white;

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _service  = AppointmentService();
  final _supabase = Supabase.instance.client;

  // State
  bool   _loadingDates = true;
  bool   _loadingSlots = false;
  bool   _booking      = false;
  String _therapistId  = '';
  String _therapistName = '';

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  Set<String> _availableDates = {};

  List<String> _slots         = [];
  String?      _selectedSlot;
  int          _slotDuration  = 30; // minutes

  final _queryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Fetch assigned therapist
    final profile = await _supabase
        .from('profiles')
        .select('assigned_therapist_id')
        .eq('id', uid)
        .maybeSingle();

    final tid = profile?['assigned_therapist_id']?.toString();
    if (tid == null || tid.isEmpty) {
      setState(() => _loadingDates = false);
      return;
    }
    _therapistId = tid;

    // Fetch therapist name
    final therapist = await _supabase
        .from('profiles')
        .select('full_name')
        .eq('id', tid)
        .maybeSingle();
    _therapistName = therapist?['full_name']?.toString() ?? 'Your Physiotherapist';

    // Fetch slot duration from first availability row
    final avRows = await _service.fetchAvailability(tid);
    if (avRows.isNotEmpty) _slotDuration = avRows.first.slotDurationMinutes;

    await _loadMonth(_focusedMonth);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _loadingDates = true);
    try {
      final dates = await _service.fetchAvailableDatesForMonth(
        therapistId: _therapistId,
        year:        month.year,
        month:       month.month,
      );
      setState(() {
        _availableDates = dates;
        _loadingDates   = false;
      });
    } catch (_) {
      setState(() => _loadingDates = false);
    }
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
      _slots        = [];
      _loadingSlots = true;
    });
    try {
      final slots = await _service.fetchAvailableSlotsForDate(
        therapistId: _therapistId,
        date:        date,
      );
      setState(() {
        _slots        = slots;
        _loadingSlots = false;
      });
    } catch (_) {
      setState(() => _loadingSlots = false);
    }
  }

  Future<void> _book() async {
    final uid  = _supabase.auth.currentUser?.id;
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (uid == null || date == null || slot == null) return;

    setState(() => _booking = true);
    try {
      // Compute end time
      final parts  = slot.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]) + _slotDuration;
      h += m ~/ 60;
      m = m % 60;
      final endTime = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

      await _service.bookAppointment(
        patientId:   uid,
        therapistId: _therapistId,
        date:        date,
        startTime:   slot,
        endTime:     endTime,
        query:       _queryCtrl.text.trim().isEmpty ? null : _queryCtrl.text.trim(),
      );

      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('duplicate')
          ? 'That slot was just booked. Please choose another.'
          : 'Booking failed: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 68,
              width:  68,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: _kPrimary, size: 38),
            ),
            const SizedBox(height: 16),
            const Text('Request Sent! 🎉',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Your appointment request for ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} at ${_fmtSlot(_selectedSlot!)} has been sent.\n\nYou\'ll be notified once your therapist confirms.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kSub, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // dialog
                  Navigator.of(context).pop(); // screen
                },
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtSlot(String slot) {
    final parts = slot.split(':');
    int h = int.parse(parts[0]);
    final m      = parts[1];
    final suffix = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.sizeOf(context).width;
    final isWide = w >= 900;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Book Appointment',
                style: TextStyle(fontWeight: FontWeight.w900, color: _kDark, fontSize: 16)),
            if (_therapistName.isNotEmpty)
              Text('with $_therapistName',
                  style: const TextStyle(fontSize: 12, color: _kSub)),
          ],
        ),
        iconTheme: const IconThemeData(color: _kDark),
      ),
      body: _therapistId.isEmpty
          ? _NoTherapistCard()
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: isWide ? _wideLayout() : _narrowLayout(),
              ),
            ),
    );
  }

  Widget _wideLayout() => Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _calendarCard()),
            const SizedBox(width: 18),
            Expanded(flex: 4, child: _rightPanel()),
          ],
        ),
      );

  Widget _narrowLayout() => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _calendarCard(),
            const SizedBox(height: 16),
            _rightPanel(),
            const SizedBox(height: 32),
          ],
        ),
      );

  Widget _calendarCard() => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Date',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kDark)),
            const SizedBox(height: 14),
            _loadingDates
                ? const Center(child: CircularProgressIndicator())
                : _CustomCalendar(
                    focusedMonth:   _focusedMonth,
                    availableDates: _availableDates,
                    selectedDate:   _selectedDate,
                    onDateSelected: _onDateSelected,
                    onMonthChanged: (m) {
                      _focusedMonth = m;
                      _loadMonth(m);
                    },
                  ),
          ],
        ),
      );

  Widget _rightPanel() => Column(
        children: [
          // Slot picker
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Time Slots',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kDark)),
                const SizedBox(height: 14),
                if (_selectedDate == null)
                  const _Hint('Select a date on the calendar to see available slots.')
                else if (_loadingSlots)
                  const Center(child: CircularProgressIndicator())
                else if (_slots.isEmpty)
                  const _Hint('No slots available for this date.')
                else
                  _SlotGrid(
                    slots:         _slots,
                    selected:      _selectedSlot,
                    onSelected:    (s) => setState(() => _selectedSlot = s),
                    fmtSlot:       _fmtSlot,
                  ),
              ],
            ),
          ),

          if (_selectedSlot != null) ...[
            const SizedBox(height: 14),
            // Optional query
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add a Note (optional)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: _kDark)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _queryCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe your concern or reason for visit...',
                      filled: true,
                      fillColor: _kBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _booking ? null : _book,
                      child: _booking
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Confirm Request — ${_fmtSlot(_selectedSlot!)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
}

// ── Custom Calendar ───────────────────────────────────────────────────────────

class _CustomCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final Set<String> availableDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _CustomCalendar({
    required this.focusedMonth,
    required this.availableDates,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    const dow = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // Sunday=0

    final cells = <Widget>[];

    // Header
    for (final d in dow) {
      cells.add(Center(
        child: Text(d,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: _kSub)),
      ));
    }

    // Blank offsets
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    // Days
    final today = DateTime.now();
    for (int d = 1; d <= daysInMonth; d++) {
      final dt        = DateTime(focusedMonth.year, focusedMonth.month, d);
      final key       = _fmt(dt);
      final available = availableDates.contains(key);
      final isToday   = dt.day == today.day && dt.month == today.month && dt.year == today.year;
      final selected  = selectedDate != null && _fmt(selectedDate!) == key;
      final isPast    = dt.isBefore(DateTime(today.year, today.month, today.day));

      cells.add(
        GestureDetector(
          onTap: available && !isPast ? () => onDateSelected(dt) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? _kPrimary
                  : available && !isPast
                  ? _kPrimary.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? Colors.white
                          : isPast || !available
                          ? const Color(0xFFCBD5E1)
                          : _kDark,
                    ),
                  ),
                  if (available && !isPast && !selected)
                    Container(
                      height: 4,
                      width: 4,
                      decoration: const BoxDecoration(
                        color: _kPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Month navigation
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month - 1)),
            ),
            Expanded(
              child: Text(
                '${months[focusedMonth.month]} ${focusedMonth.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _kDark),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 7 / 6,
          child: GridView.count(
            crossAxisCount: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: _kPrimary.withOpacity(0.1), label: 'Available'),
            const SizedBox(width: 16),
            _LegendDot(color: _kPrimary, label: 'Selected'),
            const SizedBox(width: 16),
            _LegendDot(color: const Color(0xFFCBD5E1), label: 'Unavailable'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
      ],
    );
  }
}

// ── Slot Grid ─────────────────────────────────────────────────────────────────

class _SlotGrid extends StatelessWidget {
  final List<String> slots;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String Function(String) fmtSlot;

  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelected,
    required this.fmtSlot,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((s) {
        final isSelected = s == selected;
        return GestureDetector(
          onTap: () => onSelected(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _kPrimary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? _kPrimary : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              fmtSlot(s),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isSelected ? Colors.white : _kDark,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: _kSub, height: 1.5));
  }
}

class _NoTherapistCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 56, color: _kSub),
            SizedBox(height: 14),
            Text('No Therapist Assigned',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kDark)),
            SizedBox(height: 8),
            Text(
              'You need to be assigned to a physiotherapist before you can book appointments.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kSub),
            ),
          ],
        ),
      ),
    );
  }
}