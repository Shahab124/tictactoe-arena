import 'package:flutter/material.dart';

import 'moderation.dart';

/// Admin dashboard: open reports, with Suspend or Dismiss (REQ-ADM-01, 03).
/// Only reachable by admins; the database rules refuse everyone else anyway.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.moderation, required this.uid});

  final Moderation moderation;
  final String uid;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<Report>> _reports = widget.moderation.openReports();

  void _reload() {
    final next = widget.moderation.openReports();
    setState(() {
      _reports = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: FutureBuilder<List<Report>>(
        future: _reports,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load reports.'));
          }
          final reports = snap.data;
          if (reports == null) return const Center(child: CircularProgressIndicator());
          if (reports.isEmpty) return const Center(child: Text('No open reports.'));
          return ListView(children: [
            for (final r in reports)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ListTile(
                  title: Text('Reported player: ${r.reported}'),
                  subtitle: Text([
                    'By ${r.reporter}',
                    if (r.room != null) 'room ${r.room}',
                    if (r.reason.isNotEmpty) r.reason,
                  ].join(' · ')),
                  trailing: Wrap(spacing: 4, children: [
                    TextButton(
                      onPressed: () async {
                        await widget.moderation.dismiss(r, widget.uid);
                        _reload();
                      },
                      child: const Text('Dismiss'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await widget.moderation.suspend(r, widget.uid);
                        _reload();
                      },
                      child: const Text('Suspend'),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
