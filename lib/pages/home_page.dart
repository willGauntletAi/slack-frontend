import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/user_provider.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _messageController = TextEditingController();
  final List<ChatMessage> _messages = []; // TODO: Replace with real messages
  Timer? _debounce;

  void _onSearchChanged(
    String value,
    ValueNotifier<bool> loadingNotifier,
    ValueNotifier<List<Channel>> channelsNotifier,
  ) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      loadingNotifier.value = true;
      
      final authProvider = context.read<AuthProvider>();
      final workspaceProvider = context.read<WorkspaceProvider>();
      if (authProvider.accessToken != null && workspaceProvider.selectedWorkspace != null) {
        final channels = await context.read<ChannelProvider>().fetchPublicChannels(
          authProvider.accessToken!,
          workspaceProvider.selectedWorkspace!.id,
          search: value,
        );
        channelsNotifier.value = channels;
        loadingNotifier.value = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Fetch workspaces when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.accessToken != null) {
        context.read<WorkspaceProvider>().fetchWorkspaces(authProvider.accessToken!);
      }
    });

    // Listen for workspace changes and fetch channels
    context.read<WorkspaceProvider>().addListener(() {
      final workspace = context.read<WorkspaceProvider>().selectedWorkspace;
      final authProvider = context.read<AuthProvider>();
      if (workspace != null && authProvider.accessToken != null) {
        context.read<ChannelProvider>().fetchChannels(
          authProvider.accessToken!,
          workspace.id,
        );
      } else {
        context.read<ChannelProvider>().clearChannels();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    _messageController.clear();
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isMe: true,
          timestamp: DateTime.now(),
        ),
      );
    });

    // TODO: Implement sending message to backend
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
    final searchController = TextEditingController();
    final searchNotifier = ValueNotifier<String>('');
    final channelsNotifier = ValueNotifier<List<Channel>>([]);
    final loadingNotifier = ValueNotifier<bool>(true);

    // Initial channel fetch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final workspaceProvider = context.read<WorkspaceProvider>();
      if (authProvider.accessToken != null && workspaceProvider.selectedWorkspace != null) {
        final channels = await context.read<ChannelProvider>().fetchPublicChannels(
          authProvider.accessToken!,
          workspaceProvider.selectedWorkspace!.id,
        );
        channelsNotifier.value = channels;
        loadingNotifier.value = false;
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Channel'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Channels',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  searchNotifier.value = value;
                  _onSearchChanged(value, loadingNotifier, channelsNotifier);
                },
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ValueListenableBuilder(
                  valueListenable: loadingNotifier,
                  builder: (context, isLoading, _) {
                    if (isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ValueListenableBuilder(
                      valueListenable: channelsNotifier,
                      builder: (context, channels, _) {
                        if (channels.isEmpty) {
                          return const Center(
                            child: Text('No channels found'),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: channels.length,
                          itemBuilder: (context, index) {
                            final channel = channels[index];
                            final isAlreadyMember = context
                                .read<ChannelProvider>()
                                .channels
                                .any((c) => c.id == channel.id);

                            return ListTile(
                              leading: Icon(channel.isPrivate ? Icons.lock : Icons.tag),
                              title: Text(channel.name),
                              trailing: isAlreadyMember
                                ? const Icon(Icons.check, color: Colors.green)
                                : TextButton(
                                    child: const Text('Join'),
                                    onPressed: () async {
                                      final authProvider = context.read<AuthProvider>();
                                      
                                      if (authProvider.accessToken == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Unable to join channel: Not authenticated'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      if (authProvider.currentUser == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Unable to join channel: User not found'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      final workspaceProvider = context.read<WorkspaceProvider>();
                                      if (workspaceProvider.selectedWorkspace == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Unable to join channel: No workspace selected'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      final success = await context.read<ChannelProvider>().joinChannel(
                                        authProvider.accessToken!,
                                        channel.id,
                                        authProvider.currentUser!.id,
                                        workspaceProvider.selectedWorkspace!.id,
                                      );
                                      
                                      if (context.mounted) {
                                        final error = context.read<ChannelProvider>().error;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success 
                                                ? 'Joined ${channel.name}'
                                                : error ?? 'Failed to join channel',
                                            ),
                                            backgroundColor: success ? Colors.green : Colors.red,
                                          ),
                                        );
                                        
                                        if (success) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                                  ),
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

  Widget _buildWorkspaceList() {
    return Consumer<WorkspaceProvider>(
      builder: (context, workspaceProvider, child) {
        final selectedWorkspace = workspaceProvider.selectedWorkspace;
        final bool isFullScreen = selectedWorkspace == null;

        if (workspaceProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (workspaceProvider.error != null) {
          return Center(child: Text(workspaceProvider.error!));
        }

        if (workspaceProvider.workspaces.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.workspaces_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'No workspaces yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Tooltip(
                message: 'Create Workspace',
                preferBelow: false,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                  child: InkWell(
                    onTap: _showCreateWorkspaceDialog,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: const Icon(Icons.add, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Create a workspace\nor ask for an invite',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton.icon(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            if (isFullScreen) ...[
              const SizedBox(height: 24),
              const Text(
                'Your Workspaces',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: isFullScreen ? 16 : 8,
                ),
                itemCount: workspaceProvider.workspaces.length,
                itemBuilder: (context, index) {
                  final workspace = workspaceProvider.workspaces[index];
                  final isSelected = workspace.id == workspaceProvider.selectedWorkspace?.id;
                  
                  return Tooltip(
                    message: workspace.name,
                    preferBelow: false,
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        vertical: isFullScreen ? 8 : 4,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.blue : Colors.grey[300],
                      ),
                      child: Stack(
                        children: [
                          InkWell(
                            onTap: () => workspaceProvider.selectWorkspace(workspace),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: isFullScreen ? 64 : 40,
                              height: isFullScreen ? 64 : 40,
                              alignment: Alignment.center,
                              child: Text(
                                workspace.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isFullScreen ? 24 : 16,
                                ),
                              ),
                            ),
                          ),
                          if (workspace.isInvited)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: isFullScreen ? 20 : 14,
                                height: isFullScreen ? 20 : 14,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mail_outline,
                                  color: Colors.white,
                                  size: isFullScreen ? 14 : 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Tooltip(
              message: 'Create Workspace',
              preferBelow: false,
              child: Container(
                margin: EdgeInsets.symmetric(
                  vertical: isFullScreen ? 16 : 4,
                  horizontal: isFullScreen ? 16 : 0,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: InkWell(
                  onTap: _showCreateWorkspaceDialog,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: isFullScreen ? 64 : 40,
                    height: isFullScreen ? 64 : 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add,
                      size: isFullScreen ? 32 : 24,
                    ),
                  ),
                ),
              ),
            ),
            if (isFullScreen)
              const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildChannelList() {
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
                      onPressed: _showInviteDialog,
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

                        if (shouldLeave == true && mounted) {
                          final authProvider = context.read<AuthProvider>();
                          if (authProvider.accessToken != null && authProvider.currentUser != null) {
                            final workspaceName = selectedWorkspace.name;
                            final success = await context.read<WorkspaceProvider>().leaveWorkspace(
                              authProvider.accessToken!,
                              selectedWorkspace.id,
                              authProvider.currentUser!.id,
                            );
                            
                            if (mounted) {
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
                            if (mounted) {
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
                      if (mounted) {
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
          onTap: _showCreateChannelDialog,
        ),
        ListTile(
          leading: const Icon(Icons.group_add),
          title: const Text('Join Channel'),
          onTap: _showJoinChannelDialog,
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
                                      if (mounted) {
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

  Widget _buildChatArea() {
    final selectedWorkspace = context.watch<WorkspaceProvider>().selectedWorkspace;

    if (selectedWorkspace == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspaces_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Welcome to Slack Clone!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select a workspace to start chatting\nor create your own',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Show accept/reject buttons for invited workspaces
    if (selectedWorkspace.isInvited) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mail_outline,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'Invitation to ${selectedWorkspace.name}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    if (authProvider.accessToken != null) {
                      final success = await context.read<WorkspaceProvider>().acceptInvite(
                        authProvider.accessToken!,
                        selectedWorkspace.id,
                      );
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                ? 'Joined ${selectedWorkspace.name}'
                                : context.read<WorkspaceProvider>().error ?? 'Failed to join workspace',
                            ),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );

                        if (success) {
                          // Fetch channels for the newly joined workspace
                          await context.read<ChannelProvider>().fetchChannels(
                            authProvider.accessToken!,
                            selectedWorkspace.id,
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Accept Invite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    if (authProvider.accessToken != null) {
                      final success = await context.read<WorkspaceProvider>().rejectInvite(
                        authProvider.accessToken!,
                        selectedWorkspace.id,
                      );
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                ? 'Rejected invitation to ${selectedWorkspace.name}'
                                : context.read<WorkspaceProvider>().error ?? 'Failed to reject invitation',
                            ),
                            backgroundColor: success ? null : Colors.red,
                          ),
                        );

                        if (success) {
                          // Clear the channels since we rejected the workspace
                          context.read<ChannelProvider>().clearChannels();
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Reject Invite'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(8.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _messages[index];
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Send a message',
                      border: InputBorder.none,
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _handleSubmitted(_messageController.text),
                ),
              ],
            ),
          ),
        ),
      ],
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
                  child: _buildWorkspaceList(),
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
                  child: _buildWorkspaceList(),
                ),
                // Channel list
                SizedBox(
                  width: 240,
                  child: _buildChannelList(),
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
                    body: _buildChatArea(),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: const Text('# general')),
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
                    child: _buildWorkspaceList(),
                  ),
                  // Channel list
                  Expanded(
                    child: _buildChannelList(),
                  ),
                ],
              ),
            ),
            body: _buildChatArea(),
          );
        }
      },
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime timestamp;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return const CircleAvatar(
      child: Text('U'),
    );
  }
}