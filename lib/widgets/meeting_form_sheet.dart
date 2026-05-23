import 'package:flutter/material.dart';
import '../models/meeting_model.dart';
import '../services/meeting_service.dart';

class MeetingFormSheet extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final bool isHR; // HR gets employee selector; employee picks from users

  const MeetingFormSheet({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.isHR,
  });

  @override
  State<MeetingFormSheet> createState() => _MeetingFormSheetState();
}

class _MeetingFormSheetState extends State<MeetingFormSheet> {
  final _service = MeetingService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  String _duration = '30m';
  MeetingType _type = MeetingType.general;
  MeetingFormat _format = MeetingFormat.inPerson;

  List<UserModel> _allEmployees = [];
  List<UserModel> _selectedAttendees = [];
  bool _allEmployeesSelected = false;
  bool _loadingEmployees = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      // Load ALL users (employees + HR), not just employees
      final users = await _service.getAllUsers();
      setState(() {
        _allEmployees = users
            .where((u) => u.id != widget.currentUserId)
            .toList();
        _loadingEmployees = false;
      });
    } catch (e) {
      // Show error instead of infinite spinner
      setState(() => _loadingEmployees = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allEmployeesSelected && _selectedAttendees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one attendee'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final attendees = _allEmployeesSelected
        ? _allEmployees
        : _selectedAttendees;

    final meeting = MeetingModel(
      id: '',
      title: _titleCtrl.text.trim(),
      dateTime: dt,
      duration: _duration,
      type: _type,
      format: _format,
      location: _locationCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      status: widget.isHR ? MeetingStatus.approved : MeetingStatus.pending,
      organizerId: widget.currentUserId,
      organizerName: widget.currentUserName,
      attendeeIds: attendees.map((e) => e.id).toList(),
      attendeeNames: attendees.map((e) => e.name).toList(),
      isAllEmployees: _allEmployeesSelected,
      createdAt: DateTime.now(),
    );

    try {
      if (widget.isHR) {
        await _service.hrArrangeMeeting(meeting: meeting, employees: attendees);
      } else {
        final hrUsers = await _service.getAllHRUsers();
        await _service.employeeRequestMeeting(
          meeting: meeting,
          hrUsers: hrUsers,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isHR
                  ? '✅ Meeting scheduled!'
                  : '📨 Request submitted for approval!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isHR ? 'Schedule Meeting' : 'Request a Meeting',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      widget.isHR
                          ? 'Auto-approved, attendees notified'
                          : 'Requires HR approval',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Meeting Title *'),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: _inputDecoration('e.g., Weekly Team Standup'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Date & Time
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Date *'),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Time *'),
                              GestureDetector(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 16,
                                        color: Color(0xFF7C3AED),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedTime.format(context),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Duration & Type
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Duration'),
                              _buildDropdown<String>(
                                value: _duration,
                                items: [
                                  '15m',
                                  '30m',
                                  '45m',
                                  '1h',
                                  '1.5h',
                                  '2h',
                                  '3h',
                                ],
                                labels: [
                                  '15 min',
                                  '30 min',
                                  '45 min',
                                  '1 hour',
                                  '1.5 hours',
                                  '2 hours',
                                  '3 hours',
                                ],
                                onChanged: (v) =>
                                    setState(() => _duration = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Type'),
                              _buildDropdown<MeetingType>(
                                value: _type,
                                items: MeetingType.values,
                                labels: [
                                  'General',
                                  'Review',
                                  'Training',
                                  '1-on-1',
                                  'Event',
                                ],
                                onChanged: (v) => setState(() => _type = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Format
                    _buildLabel('Meeting Format'),
                    Row(
                      children: [
                        _buildFormatChip(
                          MeetingFormat.inPerson,
                          Icons.business_rounded,
                          'In-Person',
                        ),
                        const SizedBox(width: 10),
                        _buildFormatChip(
                          MeetingFormat.virtual,
                          Icons.videocam_rounded,
                          'Virtual',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Attendees
                    _buildLabel(
                      widget.isHR ? 'Select Attendees *' : 'Meeting With *',
                    ),
                    if (_loadingEmployees)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      if (widget.isHR)
                        CheckboxListTile(
                          value: _allEmployeesSelected,
                          onChanged: (v) => setState(() {
                            _allEmployeesSelected = v!;
                            if (v) _selectedAttendees = [];
                          }),
                          title: const Text(
                            'All Employees',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_allEmployees.length} employees',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: const Color(0xFF3B82F6),
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      if (!_allEmployeesSelected)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: _allEmployees.map((employee) {
                              final selected = _selectedAttendees.any(
                                (e) => e.id == employee.id,
                              );
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (selected) {
                                      _selectedAttendees.removeWhere(
                                        (e) => e.id == employee.id,
                                      );
                                    } else {
                                      _selectedAttendees.add(employee);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.15),
                                        child: Text(
                                          employee.name.isNotEmpty
                                              ? employee.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Color(0xFF3B82F6),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              employee.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              employee.department,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFF3B82F6)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF3B82F6)
                                                : Colors.grey.shade300,
                                            width: 2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),

                    // Location
                    _buildLabel('Location / Meeting Link'),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: _inputDecoration(
                        _format == MeetingFormat.virtual
                            ? 'e.g., https://zoom.us/j/...'
                            : 'e.g., Conference Room A',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildLabel('Agenda / Description'),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Meeting agenda and objectives...',
                      ),
                    ),

                    // Info banner for employees
                    if (!widget.isHR) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_rounded,
                              color: Color(0xFF3B82F6),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your request will be reviewed by HR/Management. You\'ll get a notification once a decision is made.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Bottom button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isHR
                                  ? Icons.calendar_month_rounded
                                  : Icons.send_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isHR
                                  ? 'Schedule Meeting'
                                  : 'Submit Request',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required List<String> labels,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: onChanged,
      decoration: _inputDecoration(''),
      items: items.asMap().entries.map((e) {
        return DropdownMenuItem<T>(
          value: e.value,
          child: Text(labels[e.key], style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }

  Widget _buildFormatChip(MeetingFormat format, IconData icon, String label) {
    final selected = _format == format;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _format = format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3B82F6) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF3B82F6) : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
