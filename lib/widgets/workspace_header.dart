import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slack_frontend/providers/workspace_provider.dart';

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

    if (selectedWorkspace == null) {
      return const SizedBox(height: 56);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
      ),
      child: Row(
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
    );
  }
}
