/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class PeopleScreen extends StatefulWidget {
  @override
  _PeopleScreenState createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late Future<List<Person>> _peopleFuture;

  @override
  void initState() {
    super.initState();
    _refreshPeople();
  }

  void _refreshPeople() {
    setState(() {
      _peopleFuture = Provider.of<ApiService>(context, listen: false).getPeople();
    });
  }

  void _showAddPersonDialog() {
    showDialog(
      context: context,
      builder: (context) => PersonDialog(
        onSave: (person) async {
          try {
            await Provider.of<ApiService>(context, listen: false).createPerson(person);
            _refreshPeople();
            Navigator.of(context).pop();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create person: $e')),
            );
          }
        },
      ),
    );
  }

  void _deletePerson(Person person) async {
    try {
      await Provider.of<ApiService>(context, listen: false).deletePerson(person.id);
      _refreshPeople();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete person: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage People'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshPeople,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddPersonDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Person>>(
        future: _peopleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No people found'));
          }

          final people = snapshot.data!;

          return ListView.builder(
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(person.name[0]),
                  ),
                  title: Text(person.name),
                  subtitle: Text(person.role),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePerson(person),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}

class PersonDialog extends StatefulWidget {
  final Function(Person) onSave;

  const PersonDialog({required this.onSave});

  @override
  _PersonDialogState createState() => _PersonDialogState();
}

class _PersonDialogState extends State<PersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New Person'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Full Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _roleController,
              decoration: InputDecoration(labelText: 'Role'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a role';
                }
                return null;
              },
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
              final person = Person(
                id: '',
                name: _nameController.text,
                role: _roleController.text,
                createdAt: DateTime.now(),
              );
              widget.onSave(person);
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

class PeopleScreen extends StatefulWidget {
  @override
  _PeopleScreenState createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late Future<List<Person>> _peopleFuture;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPeople();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    final future = Provider.of<ApiService>(context, listen: false).getPeople();
    setState(() => _peopleFuture = future);
    await future;
  }

  void _showAddPersonDialog() {
    showDialog(
      context: context,
      builder: (context) => PersonDialog(
        onSave: (person) async {
          try {
            await Provider.of<ApiService>(context, listen: false).createPerson(person);
            _loadPeople();
            Navigator.of(context).pop();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add person: $e')),
            );
          }
        },
      ),
    );
  }

  void _deletePerson(Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Remove ${person.name}?'),
        content: const Text('They will be removed from every session they belong to.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Provider.of<ApiService>(context, listen: false).deletePerson(person.id);
      _loadPeople();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove person: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadPeople),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search people',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Person>>(
              future: _peopleFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: "Couldn't load people",
                    message: '${snapshot.error}',
                    action: OutlinedButton(onPressed: _loadPeople, child: const Text('Try again')),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_outline_rounded,
                    title: 'No one here yet',
                    message: 'Add the first person to start tracking attendance.',
                    action: ElevatedButton.icon(
                      onPressed: _showAddPersonDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add person'),
                    ),
                  );
                }

                final people = snapshot.data!
                    .where((p) =>
                        _query.isEmpty ||
                        p.name.toLowerCase().contains(_query) ||
                        p.role.toLowerCase().contains(_query))
                    .toList();

                if (people.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'Try a different name or role.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadPeople,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.xl),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 4),
                          leading: PersonAvatar(name: person.name),
                          title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(person.role, style: const TextStyle(color: AppColors.inkMuted)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            onPressed: () => _deletePerson(person),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonDialog,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class PersonDialog extends StatefulWidget {
  final Function(Person) onSave;

  const PersonDialog({required this.onSave});

  @override
  _PersonDialogState createState() => _PersonDialogState();
}

class _PersonDialogState extends State<PersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Add person'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value == null || value.isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: _roleController,
              decoration: const InputDecoration(labelText: 'Role'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value == null || value.isEmpty) ? 'Enter a role' : null,
            ),
          ],
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
              final person = Person(
                id: '',
                name: _nameController.text.trim(),
                role: _roleController.text.trim(),
                createdAt: DateTime.now(),
              );
              widget.onSave(person);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}