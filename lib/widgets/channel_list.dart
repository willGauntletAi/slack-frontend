import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/user_provider.dart';

class ChannelList extends StatelessWidget {
  final void Function() onCreateChannel;
  final void Function() onJoinChannel;
  final void Function() onInviteUser;

  const ChannelList({
    super.key,
    required this.onCreateChannel,
    required this.onJoinChannel,
    required this.onInviteUser,
  });

  @override
  Widget build(BuildContext context) {
    final selectedWorkspace = context.watch<WorkspaceProvider>().selectedWorkspace;
    
    if (selectedWorkspace == null) {
      return Container();
    }

    return Column(
      children: [
        DrawerHeader(
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
                            content: Text('Are you sure you want to leave ${selectedWorkspace.name}?'),
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
                          if (authProvider.accessToken != null && authProvider.currentUser != null) {
                            final workspaceName = selectedWorkspace.name;
                            final success = await context.read<WorkspaceProvider>().leaveWorkspace(
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
                                  content: Text('Unable to leave workspace: User not found'),
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
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add Channel'),
          onTap: onCreateChannel,
        ),
        ListTile(
          leading: const Icon(Icons.group_add),
          title: const Text('Join Channel'),
          onTap: onJoinChannel,
        ),
        const Divider(),
        Expanded(
          child: Consumer<ChannelProvider>(
            builder: (context, channelProvider, _) {
              if (channelProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (channelProvider.error != null) {
                return Center(child: Text(channelProvider.error!));
              }

              if (channelProvider.channels.isEmpty) {
                return const Center(
                  child: Text('No channels yet'),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: channelProvider.channels.length,
                itemBuilder: (context, index) {
                  final channel = channelProvider.channels[index];
                  final isSelected = channel.id == channelProvider.selectedChannel?.id;
                  
                  return ListTile(
                    leading: Icon(
                      channel.isPrivate ? Icons.lock : Icons.tag,
                      color: isSelected ? Colors.blue : null,
                    ),
                    title: Text(
                      channel.name,
                      style: TextStyle(
                        color: isSelected ? Colors.blue : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => channelProvider.selectChannel(channel),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.exit_to_app),
                                  title: const Text('Leave Channel'),
                                  onTap: () async {
                                    Navigator.pop(context); // Close bottom sheet
                                    final authProvider = context.read<AuthProvider>();
                                    final userProvider = context.read<UserProvider>();
                                    
                                    if (authProvider.accessToken != null && userProvider.userId != null) {
                                      final success = await channelProvider.leaveChannel(
                                        authProvider.accessToken!,
                                        channel.id,
                                        userProvider.userId!,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success 
                                                ? 'Left ${channel.name}'
                                                : channelProvider.error ?? 'Failed to leave channel',
                                            ),
                                            backgroundColor: success ? null : Colors.red,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Unable to leave channel: User ID not found'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
} 