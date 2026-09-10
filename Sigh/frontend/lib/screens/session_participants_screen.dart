/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class SessionParticipantsScreen extends StatefulWidget {
  final Session session;

  const SessionParticipantsScreen({Key? key, required this.session}) : super(key: key);

  @override
  _SessionParticipantsScreenState createState() => _SessionParticipantsScreenState();
}

class _SessionParticipantsScreenState extends State<SessionParticipantsScreen> {
  late Future<List<SessionPerson>> _participantsFuture;
  late Future<List<Person>> _availablePeopleFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _participantsFuture = Provider.of<ApiService>(context, listen: false)
          .getSessionParticipants(widget.session.id);
      _availablePeopleFuture = Provider.of<ApiService>(context, listen: false)
          .getPeople();
    });
  }

  void _addPersonToSession(Person person) async {
    try {
      await Provider.of<ApiService>(context, listen: false)
          .addPersonToSession(widget.session.id, person.id);
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${person.name} to session')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add person: $e')),
      );
    }
  }

  void _removePersonFromSession(SessionPerson sessionPerson) async {
    try {
      await Provider.of<ApiService>(context, listen: false)
          .removePersonFromSession(widget.session.id, sessionPerson.person);
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${sessionPerson.personName} from session')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove person: $e')),
      );
    }
  }

  void _showAddPeopleDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPeopleDialog(
        session: widget.session,
        onPersonAdded: _addPersonToSession,
        availablePeopleFuture: _availablePeopleFuture,
        currentParticipantsFuture: _participantsFuture,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Participants - ${widget.session.name}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: _showAddPeopleDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<SessionPerson>>(
        future: _participantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No participants in this session'),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddPeopleDialog,
                    icon: Icon(Icons.person_add),
                    label: Text('Add People'),
                  ),
                ],
              ),
            );
          }

          final participants = snapshot.data!;

          return ListView.builder(
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final participant = participants[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: participant.isPresent 
                    ? Colors.green.withOpacity(0.1)
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(participant.personName[0]),
                    backgroundColor: participant.isPresent ? Colors.green : Colors.grey,
                  ),
                  title: Text(participant.personName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role: ${participant.personName}'), // Note: You might want to store role in SessionPerson
                      if (participant.lastSeen != null)
                        Text(
                          'Last seen: ${participant.lastSeen!.toString().split('.')[0]}',
                          style: TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(
                          participant.isPresent ? 'Present' : 'Absent',
                          style: TextStyle(
                            color: participant.isPresent ? Colors.white : Colors.black,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: participant.isPresent ? Colors.green : Colors.grey[300],
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removePersonFromSession(participant),
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
        onPressed: _showAddPeopleDialog,
        child: Icon(Icons.person_add),
      ),
    );
  }
}

class AddPeopleDialog extends StatefulWidget {
  final Session session;
  final Function(Person) onPersonAdded;
  final Future<List<Person>> availablePeopleFuture;
  final Future<List<SessionPerson>> currentParticipantsFuture;

  const AddPeopleDialog({
    Key? key,
    required this.session,
    required this.onPersonAdded,
    required this.availablePeopleFuture,
    required this.currentParticipantsFuture,
  }) : super(key: key);

  @override
  _AddPeopleDialogState createState() => _AddPeopleDialogState();
}

class _AddPeopleDialogState extends State<AddPeopleDialog> {
  late List<Person> _availablePeople = [];
  late List<SessionPerson> _currentParticipants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

void _loadData() async {
  try {
    final results = await Future.wait([
      widget.availablePeopleFuture,
      widget.currentParticipantsFuture,
    ]);
    
    setState(() {
      _availablePeople = results[0] as List<Person>; // Explicit cast
      _currentParticipants = results[1] as List<SessionPerson>; // Explicit cast
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading data: $e')),
    );
  }
}

  List<Person> get _peopleNotInSession {
    final currentPersonIds = _currentParticipants.map((p) => p.person).toSet();
    return _availablePeople.where((person) => !currentPersonIds.contains(person.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add People to ${widget.session.name}'),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _peopleNotInSession.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('All people are already in this session'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _peopleNotInSession.length,
                    itemBuilder: (context, index) {
                      final person = _peopleNotInSession[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(person.name[0]),
                          ),
                          title: Text(person.name),
                          subtitle: Text(person.role),
                          trailing: IconButton(
                            icon: Icon(Icons.add, color: Colors.green),
                            onPressed: () {
                              widget.onPersonAdded(person);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
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

class SessionParticipantsScreen extends StatefulWidget {
  final Session session;

  const SessionParticipantsScreen({Key? key, required this.session}) : super(key: key);

  @override
  _SessionParticipantsScreenState createState() => _SessionParticipantsScreenState();
}

class _SessionParticipantsScreenState extends State<SessionParticipantsScreen> {
  late Future<List<SessionPerson>> _participantsFuture;
  late Future<List<Person>> _availablePeopleFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final participants = api.getSessionParticipants(widget.session.id);
    final people = api.getPeople();
    setState(() {
      _participantsFuture = participants;
      _availablePeopleFuture = people;
    });
    await Future.wait([participants, people]);
  }

  void _addPersonToSession(Person person) async {
    try {
      await Provider.of<ApiService>(context, listen: false)
          .addPersonToSession(widget.session.id, person.id);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${person.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add person: $e')),
      );
    }
  }

  void _removePersonFromSession(SessionPerson sessionPerson) async {
    try {
      await Provider.of<ApiService>(context, listen: false)
          .removePersonFromSession(widget.session.id, sessionPerson.person);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${sessionPerson.personName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove person: $e')),
      );
    }
  }

  void _showAddPeopleDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPeopleDialog(
        session: widget.session,
        onPersonAdded: _addPersonToSession,
        availablePeopleFuture: _availablePeopleFuture,
        currentParticipantsFuture: _participantsFuture,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: _showAddPeopleDialog),
        ],
      ),
      body: FutureBuilder<List<SessionPerson>>(
        future: _participantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Couldn't load participants",
              message: '${snapshot.error}',
              action: OutlinedButton(onPressed: _loadData, child: const Text('Try again')),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No participants yet',
              message: 'Add people from your roster to this session.',
              action: ElevatedButton.icon(
                onPressed: _showAddPeopleDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add people'),
              ),
            );
          }

          final participants = snapshot.data!;
          final presentCount = participants.where((p) => p.isPresent).length;

          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xl),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Checked in', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                            const SizedBox(height: 2),
                            Text(
                              '$presentCount of ${participants.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: participants.isEmpty ? 0 : presentCount / participants.length,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                ...participants.map(
                  (participant) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 4),
                        leading: PersonAvatar(name: participant.personName, active: participant.isPresent),
                        title: Text(participant.personName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          participant.lastSeen != null
                              ? 'Last seen ${_formatTime(participant.lastSeen!)}'
                              : 'Not seen yet',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: participant.isPresent ? AppColors.successMuted : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              child: Text(
                                participant.isPresent ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: participant.isPresent ? AppColors.success : AppColors.inkMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.danger, size: 20),
                              onPressed: () => _removePersonFromSession(participant),
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
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPeopleDialog,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class AddPeopleDialog extends StatefulWidget {
  final Session session;
  final Function(Person) onPersonAdded;
  final Future<List<Person>> availablePeopleFuture;
  final Future<List<SessionPerson>> currentParticipantsFuture;

  const AddPeopleDialog({
    Key? key,
    required this.session,
    required this.onPersonAdded,
    required this.availablePeopleFuture,
    required this.currentParticipantsFuture,
  }) : super(key: key);

  @override
  _AddPeopleDialogState createState() => _AddPeopleDialogState();
}

class _AddPeopleDialogState extends State<AddPeopleDialog> {
  List<Person> _availablePeople = [];
  List<SessionPerson> _currentParticipants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final results = await Future.wait([
        widget.availablePeopleFuture,
        widget.currentParticipantsFuture,
      ]);
      if (!mounted) return;
      setState(() {
        _availablePeople = results[0] as List<Person>;
        _currentParticipants = results[1] as List<SessionPerson>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading people: $e')),
      );
    }
  }

  List<Person> get _peopleNotInSession {
    final currentPersonIds = _currentParticipants.map((p) => p.person).toSet();
    return _availablePeople.where((person) => !currentPersonIds.contains(person.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text('Add to ${widget.session.name}', overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _peopleNotInSession.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Everyone is in',
                    message: 'All the people in your roster already belong to this session.',
                  )
                : ListView.separated(
                    itemCount: _peopleNotInSession.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpace.xs),
                    itemBuilder: (context, index) {
                      final person = _peopleNotInSession[index];
                      return Card(
                        child: ListTile(
                          leading: PersonAvatar(name: person.name, size: 36),
                          title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(person.role),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_rounded, color: AppColors.success),
                            onPressed: () {
                              widget.onPersonAdded(person);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}