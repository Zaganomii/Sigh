/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'session_participants_screen.dart'; // Add this import

class SessionsScreen extends StatefulWidget {
  @override
  _SessionsScreenState createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late Future<List<Session>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshSessions();
  }

  void _refreshSessions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _sessionsFuture = Provider.of<ApiService>(context, listen: false).getSessions();
      });
    });
  }

  void _showAddSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => SessionDialog(
        onSave: (session) async {
          try {
            final apiService = Provider.of<ApiService>(context, listen: false);
            await apiService.createSession(session);
            _refreshSessions();
            Navigator.of(context).pop();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create session: $e')),
            );
          }
        },
      ),
    );
  }

  void _deleteSession(Session session) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.deleteSession(session.id);
      _refreshSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete session: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Sessions'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshSessions,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddSessionDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Session>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No sessions found'));
          }

          final sessions = snapshot.data!;
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(session.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.description),
                      SizedBox(height: 4),
                      Text(
                        'Participants: ${session.participantCount}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.people, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SessionParticipantsScreen(session: session),
                            ),
                          );
                        },
                        tooltip: 'Manage Participants',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSession(session),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSessionDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}

class SessionDialog extends StatefulWidget {
  final Function(Session) onSave;

  const SessionDialog({required this.onSave});

  @override
  _SessionDialogState createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New Session'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Session Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a session name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final session = Session(
                id: '',
                name: _nameController.text,
                description: _descriptionController.text,
                isActive: true,
                createdAt: DateTime.now(),
                participantCount: 0,
              );
              widget.onSave(session);
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
} */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'session_participants_screen.dart';

// Helper for formatting weekly schedule display in session cards
class _SessionScheduleUtils {
  static const List<String> dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  static String? formatTime(String? timeStr) {
    if (timeStr == null) return null;
    // timeStr is in HH:mm format
    final parts = timeStr.split(':');
    if (parts.length != 2) return timeStr;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${parts[1].padLeft(2, '0')} $period';
  }
}

class SessionsScreen extends StatefulWidget {
  @override
  _SessionsScreenState createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late Future<List<Session>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final future = Provider.of<ApiService>(context, listen: false).getSessions();
    setState(() => _sessionsFuture = future);
    await future;
  }

  void _showAddSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => SessionDialog(
        onSave: (session) async {
          try {
            final apiService = Provider.of<ApiService>(context, listen: false);
            await apiService.createSession(session);
            _loadSessions();
            Navigator.of(context).pop();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create session: $e')),
            );
          }
        },
      ),
    );
  }

  void _deleteSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Delete ${session.name}?'),
        content: const Text('This removes the session and its attendance records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.deleteSession(session.id);
      _loadSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete session: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadSessions),
        ],
      ),
      body: FutureBuilder<List<Session>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Couldn't load sessions",
              message: '${snapshot.error}',
              action: OutlinedButton(onPressed: _loadSessions, child: const Text('Try again')),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No sessions yet',
              message: 'Create a session to start taking attendance.',
              action: ElevatedButton.icon(
                onPressed: _showAddSessionDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New session'),
              ),
            );
          }

          final sessions = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _loadSessions,
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xl),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SessionParticipantsScreen(session: session),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        session.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.sm),
                                    _StatusChip(active: session.isActive),
                                  ],
                                ),
                                if (session.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    session.description,
                                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: AppSpace.sm),
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_rounded, size: 15, color: AppColors.inkMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${session.participantCount} participant${session.participantCount == 1 ? '' : 's'}',
                                      style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                                // Weekly schedule display
                                if (session.weeklySchedule != null ||
                                   (session.weeklyDay != null && session.weeklyStartTime != null)) ...[
                                  const SizedBox(height: AppSpace.xs),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 14, color: AppColors.accent),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          session.weeklySchedule ??
                                              'Every ${_SessionScheduleUtils.dayNames[session.weeklyDay!]} '
                                              '${_SessionScheduleUtils.formatTime(session.weeklyStartTime)}'
                                              ' ${session.weeklyEndTime != null ? "- ${_SessionScheduleUtils.formatTime(session.weeklyEndTime)}" : ""}',
                                          style: const TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            onPressed: () => _deleteSession(session),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSessionDialog,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? AppColors.successMuted : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        active ? 'Active' : 'Closed',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class SessionDialog extends StatefulWidget {
  final Function(Session) onSave;

  const SessionDialog({required this.onSave});

  @override
  _SessionDialogState createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Weekly schedule fields
  int? _selectedDay;  // 0=Monday ... 6=Sunday
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('New session'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Session name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) => (value == null || value.isEmpty) ? 'Enter a session name' : null,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpace.lg),
              const Text(
                'Weekly Schedule (optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: AppSpace.sm),
              // Day picker
              DropdownButtonFormField<int?>(
                value: _selectedDay,
                decoration: const InputDecoration(labelText: 'Day of week'),
                hint: const Text('Select a day (or none for one-time session)'),
                items: List.generate(7, (index) {
                  return DropdownMenuItem(
                    value: index,
                    child: Text(_dayNames[index]),
                  );
                }),
                onChanged: (value) => setState(() => _selectedDay = value),
              ),
              const SizedBox(height: AppSpace.sm),
              // Start time
              InkWell(
                onTap: _pickStartTime,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Start time'),
                  child: Text(
                    _startTime != null
                        ? _startTime!.format(context)
                        : 'Select start time',
                    style: TextStyle(
                      color: _startTime != null ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              // End time
              InkWell(
                onTap: _pickEndTime,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'End time'),
                  child: Text(
                    _endTime != null
                        ? _endTime!.format(context)
                        : 'Select end time',
                    style: TextStyle(
                      color: _endTime != null ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
              // Preview of schedule
              if (_selectedDay != null && _startTime != null)
                Container(
                  margin: const EdgeInsets.only(top: AppSpace.sm),
                  padding: const EdgeInsets.all(AppSpace.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accentMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.accent),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          'Every ${_dayNames[_selectedDay!]} '
                          '${_startTime!.format(context)}'
                          ' ${(_endTime != null ? '-\u2022- ${_endTime!.format(context)}' : '')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final session = Session(
                id: '',
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
                isActive: true,
                createdAt: DateTime.now(),
                participantCount: 0,
                weeklyDay: _selectedDay,
                weeklyStartTime: _formatTime(_startTime),
                weeklyEndTime: _formatTime(_endTime),
              );
              widget.onSave(session);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}