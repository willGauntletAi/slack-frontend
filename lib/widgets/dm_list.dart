import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dm_provider.dart';
import '../providers/workspace_users_provider.dart';
import '../providers/workspace_provider.dart';

class DMList extends StatelessWidget {
  final void Function() onCreateDmChannel;
  const DMList({super.key, required this.onCreateDmChannel});

  @override
  Widget build(BuildContext context) {
    final dmProvider = context.watch<DMProvider>();
    final authProvider = context.watch<AuthProvider>();
    final workspaceUsersProvider = context.watch<WorkspaceUsersProvider>();
    final workspaceProvider = context.watch<WorkspaceProvider>();
    final currentUser = authProvider.currentUser;
    final currentWorkspaceId = workspaceProvider.selectedWorkspace?.id ?? '';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('New DM'),
          onTap: onCreateDmChannel,
        ),
        if (dmProvider.channels.isEmpty)
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
          )
        else
          ...dmProvider.channels.map((channel) {
            // Get the other user's ID (not the current user)
            final usernames = channel.usernames.where(
              (id) => id != currentUser?.id,
            );

            final isSelected = dmProvider.selectedChannel?.id == channel.id;

            return ListTile(
              selected: isSelected,
              leading: const Icon(Icons.person_outline),
              title: Text(
                usernames.join(', '),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () => dmProvider.selectChannel(channel),
            );
          }),
      ],
    );
  }
}
