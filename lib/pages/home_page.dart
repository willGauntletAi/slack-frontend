import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../widgets/workspace_list.dart';
import '../widgets/channel_list.dart';
import '../widgets/chat_area.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.accessToken != null) {
          _workspaceProvider.fetchWorkspaces(authProvider.accessToken!);
        }
      }
    });

    // Listen for workspace changes and fetch channels
    _workspaceListener = () {
      if (!mounted) return;
      final workspace = _workspaceProvider.selectedWorkspace;
      final authProvider = context.read<AuthProvider>();
      if (workspace != null && authProvider.accessToken != null) {
        context.read<ChannelProvider>().fetchChannels(
          authProvider.accessToken!,
          workspace.id,
        );
      } else {
        context.read<ChannelProvider>().clearChannels();
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
                onChanged: (value) => isPrivateController.value = value ?? false,
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
                if (authProvider.accessToken != null && workspaceProvider.selectedWorkspace != null) {
                  final channel = await context.read<ChannelProvider>().createChannel(
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
              if (authProvider.accessToken != null && workspaceProvider.selectedWorkspace != null) {
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
                return const Center(child: Text('No channels available to join'));
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
                        if (authProvider.accessToken == null || authProvider.currentUser == null) {
                          return;
                        }

                        final workspaceProvider = context.read<WorkspaceProvider>();
                        if (workspaceProvider.selectedWorkspace == null) {
                          return;
                        }

                        final success = await context.read<ChannelProvider>().joinChannel(
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
                                  : context.read<ChannelProvider>().error ?? 'Failed to join channel',
                              ),
                              backgroundColor: success ? Colors.green : Colors.red,
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
                        : workspaceProvider.error ?? 'Failed to send invitation',
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 600;
        final selectedWorkspace = context.watch<WorkspaceProvider>().selectedWorkspace;
        final selectedChannel = context.watch<ChannelProvider>().selectedChannel;

        // If no workspace is selected, show only the workspace list in full screen
        if (selectedWorkspace == null) {
          return Scaffold(
            appBar: isWideScreen ? null : AppBar(title: const Text('Workspaces')),
            body: Container(
              color: Colors.grey[200],
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWideScreen ? 400 : double.infinity,
                  ),
                  child: WorkspaceList(
                    onCreateWorkspace: _showCreateWorkspaceDialog,
                  ),
                ),
              ),
            ),
          );
        }

        // Regular layout when a workspace is selected
        if (isWideScreen) {
          return Scaffold(
            body: Row(
              children: [
                // Workspace list
                Container(
                  width: 65,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: WorkspaceList(
                    onCreateWorkspace: _showCreateWorkspaceDialog,
                  ),
                ),
                // Channel list
                SizedBox(
                  width: 240,
                  child: ChannelList(
                    onCreateChannel: _showCreateChannelDialog,
                    onJoinChannel: _showJoinChannelDialog,
                    onInviteUser: _showInviteDialog,
                  ),
                ),
                const VerticalDivider(width: 1),
                // Chat area
                Expanded(
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(
                        selectedChannel != null
                          ? '${selectedChannel.isPrivate ? "🔒" : "#"} ${selectedChannel.name}'
                          : 'No channel selected'
                      ),
                    ),
                    body: const ChatArea(),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                selectedChannel != null
                  ? '${selectedChannel.isPrivate ? "🔒" : "#"} ${selectedChannel.name}'
                  : 'No channel selected'
              ),
            ),
            drawer: Drawer(
              child: Row(
                children: [
                  // Workspace list
                  Container(
                    width: 65,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: WorkspaceList(
                      onCreateWorkspace: _showCreateWorkspaceDialog,
                    ),
                  ),
                  // Channel list
                  Expanded(
                    child: ChannelList(
                      onCreateChannel: _showCreateChannelDialog,
                      onJoinChannel: _showJoinChannelDialog,
                      onInviteUser: _showInviteDialog,
                    ),
                  ),
                ],
              ),
            ),
            body: const ChatArea(),
          );
        }
      },
    );
  }
}