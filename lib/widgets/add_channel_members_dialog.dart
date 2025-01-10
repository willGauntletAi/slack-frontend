import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/workspace_users_provider.dart';

class AddChannelMembersDialog extends StatefulWidget {
  final String channelId;
  final String channelName;

  const AddChannelMembersDialog({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<AddChannelMembersDialog> createState() =>
      _AddChannelMembersDialogState();
}

class _AddChannelMembersDialogState extends State<AddChannelMembersDialog> {
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
          excludeChannelId: widget.channelId,
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
      title: Text('Add Members to #${widget.channelName}'),
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

                      final channelProvider = context.read<ChannelProvider>();
                      final userIds = selected.map((u) => u.id).toList();

                      final success = await channelProvider.addChannelMembers(
                        authProvider.accessToken!,
                        widget.channelId,
                        userIds,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Added ${selected.length} member${selected.length == 1 ? '' : 's'} to #${widget.channelName}'
                                  : channelProvider.operationError ??
                                      'Failed to add members to channel',
                            ),
                            backgroundColor: success ? null : Colors.red,
                          ),
                        );
                      }
                    },
              child: const Text('Add Members'),
            );
          },
        ),
      ],
    );
  }
}
