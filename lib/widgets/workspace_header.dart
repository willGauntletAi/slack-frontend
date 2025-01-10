import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slack_frontend/providers/workspace_provider.dart';
import 'package:slack_frontend/providers/auth_provider.dart';

class WorkspaceHeader extends StatelessWidget {
  final VoidCallback onInviteUser;
  final VoidCallback onSearch;

  const WorkspaceHeader({
    super.key,
    required this.onInviteUser,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final selectedWorkspace =
        context.watch<WorkspaceProvider>().selectedWorkspace;
    final currentUser = context.watch<AuthProvider>().currentUser;

    if (selectedWorkspace == null) {
      return const SizedBox(height: 56);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Workspace name and actions row
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedWorkspace.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                color: Colors.white,
                onPressed: onSearch,
                tooltip: 'Search messages',
              ),
              IconButton(
                icon: const Icon(Icons.person_add),
                color: Colors.white,
                onPressed: onInviteUser,
                tooltip: 'Invite user',
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 1),
          // User profile section
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  // User avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    child: Text(
                      currentUser.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Username
                  Expanded(
                    child: Text(
                      currentUser.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Logout button
                  TextButton.icon(
                    onPressed: () {
                      context.read<AuthProvider>().logout();
                      // Navigate to login page and remove all previous routes
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout,
                        size: 18, color: Colors.white70),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
