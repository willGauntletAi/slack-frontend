import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slack_frontend/providers/auth_provider.dart';
import 'package:slack_frontend/providers/channel_provider.dart';
import 'package:slack_frontend/providers/workspace_provider.dart';

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({super.key, required this.onInviteUser});

  final void Function() onInviteUser;

  @override
  Widget build(BuildContext context) {
    final selectedWorkspace =
        context.watch<WorkspaceProvider>().selectedWorkspace;

    if (selectedWorkspace == null) {
      return Container();
    }

    return DrawerHeader(
      decoration: const BoxDecoration(
        color: Colors.blue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  selectedWorkspace.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selectedWorkspace.role == 'admin')
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  tooltip: 'Invite User',
                  onPressed: onInviteUser,
                )
              else
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  tooltip: 'Leave Workspace',
                  onPressed: () async {
                    // Show confirmation dialog
                    final shouldLeave = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Leave Workspace'),
                        content: Text(
                            'Are you sure you want to leave ${selectedWorkspace.name}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Leave'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLeave == true && context.mounted) {
                      final authProvider = context.read<AuthProvider>();
                      if (authProvider.accessToken != null &&
                          authProvider.currentUser != null) {
                        final workspaceName = selectedWorkspace.name;
                        final success = await context
                            .read<WorkspaceProvider>()
                            .leaveWorkspace(
                              authProvider.accessToken!,
                              selectedWorkspace.id,
                              authProvider.currentUser!.id,
                            );

                        if (context.mounted) {
                          final error = context.read<WorkspaceProvider>().error;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Left $workspaceName'
                                    : error ?? 'Failed to leave workspace',
                              ),
                              backgroundColor: success ? null : Colors.red,
                            ),
                          );

                          if (success) {
                            // Clear the channels since we left the workspace
                            context.read<ChannelProvider>().clearChannels();
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Unable to leave workspace: User not found'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const CircleAvatar(
                child: Text('U'),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'User Name',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
