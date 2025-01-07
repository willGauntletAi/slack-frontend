import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/user_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _messageController = TextEditingController();
  final List<ChatMessage> _messages = []; // TODO: Replace with real messages

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
                  if (mounted) {
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
                  if (mounted && channel != null) {
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
                      child: InkWell(
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
              Text(
                selectedWorkspace.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
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

              final workspaceChannels = channelProvider.getChannelsForWorkspace(selectedWorkspace.id);
              
              if (workspaceChannels.isEmpty) {
                return const Center(
                  child: Text('No channels in this workspace'),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: workspaceChannels.length,
                itemBuilder: (context, index) {
                  final channel = workspaceChannels[index];
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
                                      if (mounted) {
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
    final selectedChannel = context.watch<ChannelProvider>().selectedChannel;

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