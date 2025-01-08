import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slack_frontend/providers/channel_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/dm_provider.dart';
import '../providers/workspace_users_provider.dart';

class CreateDMDialog extends StatefulWidget {
  const CreateDMDialog({super.key});

  @override
  State<CreateDMDialog> createState() => _CreateDMDialogState();
}

class _CreateDMDialogState extends State<CreateDMDialog> {
  final searchController = TextEditingController();
  final selectedUsers = ValueNotifier<Set<WorkspaceUser>>({});

  @override
  void initState() {
    super.initState();
    // Fetch users when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final workspaceProvider = context.read<WorkspaceProvider>();
      final authProvider = context.read<AuthProvider>();
      final usersProvider = context.read<WorkspaceUsersProvider>();

      if (workspaceProvider.selectedWorkspace != null &&
          authProvider.accessToken != null) {
        usersProvider.fetchWorkspaceUsers(
          authProvider.accessToken!,
          workspaceProvider.selectedWorkspace!.id,
        );
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Message'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search users',
                hintText: 'Type to search users...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                // Trigger rebuild to filter users
                (context as Element).markNeedsBuild();
              },
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: selectedUsers,
              builder: (context, Set<WorkspaceUser> selected, _) {
                if (selected.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 8,
                    children: selected
                        .map((user) => Chip(
                              label: Text(user.username),
                              onDeleted: () {
                                selectedUsers.value = Set.from(selected)
                                  ..remove(user);
                              },
                            ))
                        .toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Builder(
                builder: (context) {
                  final workspaceProvider = context.watch<WorkspaceProvider>();
                  final workspaceId = workspaceProvider.selectedWorkspace?.id;

                  if (workspaceId == null) {
                    return const Center(
                      child: Text('Please select a workspace first'),
                    );
                  }

                  return Consumer<WorkspaceUsersProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading(workspaceId)) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final error = provider.getError(workspaceId);
                      if (error != null) {
                        return Center(child: Text('Error: $error'));
                      }

                      final allUsers = provider.getWorkspaceUsers(workspaceId);
                      final searchTerm = searchController.text.toLowerCase();
                      final currentUserId =
                          context.read<AuthProvider>().currentUser?.id;
                      final filteredUsers = allUsers.where((user) {
                        // Filter out the current user
                        if (user.id == currentUserId) return false;

                        return user.username
                                .toLowerCase()
                                .contains(searchTerm) ||
                            user.email.toLowerCase().contains(searchTerm);
                      }).toList();

                      if (filteredUsers.isEmpty) {
                        return const Center(
                          child: Text('No users found'),
                        );
                      }

                      return ValueListenableBuilder(
                        valueListenable: selectedUsers,
                        builder: (context, Set<WorkspaceUser> selected, _) {
                          return ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final isSelected = selected.contains(user);

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(user.username[0].toUpperCase()),
                                ),
                                title: Text(user.username),
                                subtitle: Text(user.email),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)
                                    : null,
                                onTap: () {
                                  if (isSelected) {
                                    selectedUsers.value = Set.from(selected)
                                      ..remove(user);
                                  } else {
                                    selectedUsers.value = Set.from(selected)
                                      ..add(user);
                                  }
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: selectedUsers,
          builder: (context, Set<WorkspaceUser> selected, _) {
            return TextButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      final authProvider = context.read<AuthProvider>();
                      if (authProvider.accessToken == null) return;

                      final dmProvider = context.read<DMProvider>();
                      final workspaceProvider =
                          context.read<WorkspaceProvider>();
                      if (workspaceProvider.selectedWorkspace == null) return;

                      final userIds = selected.map((u) => u.id).toList();

                      final channel = await dmProvider.createDMChannel(
                        authProvider.accessToken!,
                        workspaceProvider.selectedWorkspace!.id,
                        userIds,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        if (channel != null) {
                          context.read<ChannelProvider>().selectChannel(null);
                          dmProvider.selectChannel(channel);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create conversation'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Start Conversation'),
            );
          },
        ),
      ],
    );
  }
}
