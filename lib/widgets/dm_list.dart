import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dm_provider.dart';

class DMList extends StatelessWidget {
  final void Function() onCreateDmChannel;
  const DMList({super.key, required this.onCreateDmChannel});

  @override
  Widget build(BuildContext context) {
    final dmProvider = context.watch<DMProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('New DM'),
          onTap: onCreateDmChannel,
        ),
        // TODO: Add list of DM channels
        // For now, just show a placeholder
        const ListTile(
          dense: true,
          title: Text(
            'No conversations yet',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
