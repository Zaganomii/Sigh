/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'sessions_screen.dart';
import 'people_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = Provider.of<ApiService>(context, listen: false).getDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshStats,
          ),
        ],
      ),
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No data available'));
          }

          final stats = snapshot.data!;

          return Column(
            children: [
              // Stats Grid - Fixed height
              Container(
                height: 220, // Fixed height to prevent overflow
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(), // Disable scrolling
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _StatCard(
                        title: 'Total Sessions',
                        value: stats.totalSessions.toString(),
                        icon: Icons.event,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        title: 'Total People',
                        value: stats.totalPeople.toString(),
                        icon: Icons.people,
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'Active Sessions',
                        value: stats.activeSessions.toString(),
                        icon: Icons.check_circle,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: "Today's Attendance",
                        value: stats.todayAttendance.toString(),
                        icon: Icons.fact_check,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
              // Divider
              Divider(height: 1),
              // Quick Actions - Expanded to take remaining space
              Expanded(
                child: ListView(
                  children: [
                    _ActionCard(
                      icon: Icons.event,
                      iconColor: Colors.blue,
                      title: 'Manage Sessions',
                      subtitle: 'Create, edit, and delete sessions',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SessionsScreen()),
                        );
                      },
                    ),
                    _ActionCard(
                      icon: Icons.people,
                      iconColor: Colors.green,
                      title: 'Manage People',
                      subtitle: 'Add, edit, and remove people',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PeopleScreen()),
                        );
                      },
                    ),
                    _ActionCard(
                      icon: Icons.history,
                      iconColor: Colors.orange,
                      title: 'Attendance Logs',
                      subtitle: 'View attendance history',
                      onTap: () {
                        // Navigate to attendance logs screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Attendance Logs - Coming Soon')),
                        );
                      },
                    ),
                    _ActionCard(
                      icon: Icons.analytics,
                      iconColor: Colors.purple,
                      title: 'Reports',
                      subtitle: 'Generate attendance reports',
                      onTap: () {
                        // Navigate to reports screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reports - Coming Soon')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color), // Slightly smaller icon
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20, // Slightly smaller font
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12, // Smaller font for title
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
} */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'sessions_screen.dart';
import 'people_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final future = Provider.of<ApiService>(context, listen: false).getDashboardStats();
    setState(() => _statsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Something went wrong',
              message: '${snapshot.error}',
              action: OutlinedButton(onPressed: _loadStats, child: const Text('Try again')),
            );
          } else if (!snapshot.hasData) {
            return const EmptyState(
              icon: Icons.query_stats_rounded,
              title: 'No data yet',
              message: 'Stats will show up once you have sessions and people.',
            );
          }

          final stats = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _loadStats,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xl),
              children: [
                _OverviewHeader(
                  activeSessions: stats.activeSessions,
                  todayAttendance: stats.todayAttendance,
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Sessions',
                        value: stats.totalSessions.toString(),
                        icon: Icons.event_note_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _StatTile(
                        label: 'People',
                        value: stats.totalPeople.toString(),
                        icon: Icons.groups_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Active now',
                        value: stats.activeSessions.toString(),
                        icon: Icons.bolt_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _StatTile(
                        label: "Today's check-ins",
                        value: stats.todayAttendance.toString(),
                        icon: Icons.fact_check_rounded,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                const _SectionLabel('Quick actions'),
                const SizedBox(height: AppSpace.sm),
                _ActionCard(
                  icon: Icons.event_note_rounded,
                  color: AppColors.primary,
                  title: 'Sessions',
                  subtitle: 'Create, edit and close out sessions',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SessionsScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.groups_rounded,
                  color: AppColors.accent,
                  title: 'People',
                  subtitle: 'Add or remove people from your roster',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PeopleScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.history_rounded,
                  color: AppColors.success,
                  title: 'Attendance logs',
                  subtitle: 'Browse past check-ins',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance logs — coming soon')),
                  ),
                ),
                _ActionCard(
                  icon: Icons.insights_rounded,
                  color: AppColors.danger,
                  title: 'Reports',
                  subtitle: 'Export attendance summaries',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reports — coming soon')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  final int activeSessions;
  final int todayAttendance;

  const _OverviewHeader({required this.activeSessions, required this.todayAttendance});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
          const SizedBox(height: 4),
          Text(
            activeSessions > 0
                ? '$activeSessions session${activeSessions == 1 ? '' : 's'} running right now'
                : 'No sessions running right now',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$todayAttendance checked in today',
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: AppSpace.md),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}