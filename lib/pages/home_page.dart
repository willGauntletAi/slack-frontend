import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slack_frontend/widgets/workspace_header.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/message_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/dm_provider.dart';
import '../widgets/workspace_list.dart';
import '../widgets/channel_list.dart';
import '../widgets/chat_area.dart';
import '../widgets/dm_list.dart';
import '../widgets/dm_chat_area.dart';
import '../widgets/create_dm_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  VoidCallback? _workspaceListener;
  late final WorkspaceProvider _workspaceProvider;

  @override
  void initState() {
    super.initState();
    _workspaceProvider = context.read<WorkspaceProvider>();

    // Fetch workspaces when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        final wsProvider = context.read<WebSocketProvider>();
        if (authProvider.accessToken != null && !wsProvider.isConnected) {
          // Connect to WebSocket first
          try {
            await wsProvider.connect(authProvider.accessToken!);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to connect to WebSocket: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          // Then fetch workspaces
          if (mounted) {
            await _workspaceProvider.fetchWorkspaces(authProvider.accessToken!);
          }
        }
      }
    });

    // Listen for workspace changes and fetch channels
    _workspaceListener = () async {
      if (!mounted) return;
      final workspace = _workspaceProvider.selectedWorkspace;
      final authProvider = context.read<AuthProvider>();
      if (workspace != null && authProvider.accessToken != null) {
        try {
          // Fetch channels for the workspace
          await context.read<ChannelProvider>().fetchChannels(
                authProvider.accessToken!,
                workspace.id,
              );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load channels: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        context.read<ChannelProvider>().clearChannels();
        context.read<MessageProvider>().clearAllChannels();
      }
    };
    _workspaceProvider.addListener(_workspaceListener!);
  }

  @override
  void dispose() {
    if (_workspaceListener != null) {
      _workspaceProvider.removeListener(_workspaceListener!);
    }
    super.dispose();
  }

  void _showCreateWorkspaceDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Workspace'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Workspace Name',
            hintText: 'Enter workspace name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final authProvider = context.read<AuthProvider>();
                if (authProvider.accessToken != null) {
                  await context.read<WorkspaceProvider>().createWorkspace(
                        authProvider.accessToken!,
                        name,
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateChannelDialog() {
    final nameController = TextEditingController();
    final isPrivateController = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                hintText: 'Enter channel name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: isPrivateController,
              builder: (context, isPrivate, _) => CheckboxListTile(
                title: const Text('Private Channel'),
                value: isPrivate,
                onChanged: (value) =>
                    isPrivateController.value = value ?? false,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final authProvider = context.read<AuthProvider>();
                final workspaceProvider = context.read<WorkspaceProvider>();
                if (authProvider.accessToken != null &&
                    workspaceProvider.selectedWorkspace != null) {
                  final channel =
                      await context.read<ChannelProvider>().createChannel(
                            authProvider.accessToken!,
                            workspaceProvider.selectedWorkspace!.id,
                            name,
                            isPrivate: isPrivateController.value,
                          );
                  if (context.mounted && channel != null) {
                    Navigator.pop(context);
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Channel'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder(
            future: () async {
              final authProvider = context.read<AuthProvider>();
              final workspaceProvider = context.read<WorkspaceProvider>();
              if (authProvider.accessToken != null &&
                  workspaceProvider.selectedWorkspace != null) {
                return context.read<ChannelProvider>().fetchPublicChannels(
                      authProvider.accessToken!,
                      workspaceProvider.selectedWorkspace!.id,
                    );
              }
              return [];
            }(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final channels = snapshot.data ?? [];
              if (channels.isEmpty) {
                return const Center(
                    child: Text('No channels available to join'));
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return ListTile(
                    leading: Icon(channel.isPrivate ? Icons.lock : Icons.tag),
                    title: Text(channel.name),
                    trailing: TextButton(
                      child: const Text('Join'),
                      onPressed: () async {
                        final authProvider = context.read<AuthProvider>();
                        if (authProvider.accessToken == null ||
                            authProvider.currentUser == null) {
                          return;
                        }

                        final workspaceProvider =
                            context.read<WorkspaceProvider>();
                        if (workspaceProvider.selectedWorkspace == null) {
                          return;
                        }

                        final success =
                            await context.read<ChannelProvider>().joinChannel(
                                  authProvider.accessToken!,
                                  channel.id,
                                  authProvider.currentUser!.id,
                                  workspaceProvider.selectedWorkspace!.id,
                                );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Joined ${channel.name}'
                                    : context.read<ChannelProvider>().error ??
                                        'Failed to join channel',
                              ),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email address',
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;

              final authProvider = context.read<AuthProvider>();
              final workspaceProvider = context.read<WorkspaceProvider>();

              if (authProvider.accessToken == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Not authenticated'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              if (workspaceProvider.selectedWorkspace == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No workspace selected'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final success = await workspaceProvider.inviteUser(
                authProvider.accessToken!,
                workspaceProvider.selectedWorkspace!.id,
                email,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Invitation sent to $email'
                          : workspaceProvider.error ??
                              'Failed to send invitation',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  void _showCreateDmChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateDMDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = context.watch<ChannelProvider>().selectedChannel;
    final selectedDMChannel = context.watch<DMProvider>().selectedChannel;

    return Scaffold(
      body: Row(
        children: [
          // Workspace list
          SizedBox(
            width: 80,
            child: Material(
              elevation: 2,
              child: Column(
                children: [
                  Expanded(
                    child: WorkspaceList(
                      onCreateWorkspace: _showCreateWorkspaceDialog,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Channel list and DM list
          SizedBox(
            width: 250,
            child: Material(
              elevation: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkspaceHeader(onInviteUser: _showInviteDialog),
                  // Channels section
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Channels',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ChannelList(
                      onCreateChannel: _showCreateChannelDialog,
                      onJoinChannel: _showJoinChannelDialog,
                      onInviteUser: _showInviteDialog,
                    ),
                  ),
                  // Direct Messages section
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Direct Messages',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: DMList(
                      onCreateDmChannel: _showCreateDmChannelDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Chat area
          Expanded(
            child: selectedChannel != null
                ? const ChatArea()
                : selectedDMChannel != null
                    ? const DMChatArea()
                    : const Center(
                        child: Text('Select a channel or conversation'),
                      ),
          ),
        ],
      ),
    );
  }
}
