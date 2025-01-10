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
    final selectedWorkspace =
        context.watch<WorkspaceProvider>().selectedWorkspace;

    if (selectedWorkspace == null) {
      return Container();
    }

    return Column(
      children: [
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

              // Filter for regular channels (channels with non-null names)
              final regularChannels = channelProvider.channels
                  .where((channel) => channel.name != null)
                  .toList();

              if (regularChannels.isEmpty) {
                return const Center(
                  child: Text('No channels yet'),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: regularChannels.length,
                itemBuilder: (context, index) {
                  final channel = regularChannels[index];
                  final isSelected =
                      channel.id == channelProvider.selectedChannel?.id;

                  return ListTile(
                    leading: Icon(
                      channel.isPrivate ? Icons.lock : Icons.tag,
                      color: isSelected ? Colors.blue : null,
                    ),
                    title: Text(
                      channel.name!,
                      style: TextStyle(
                        color: isSelected ? Colors.blue : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => channelProvider.selectChannel(channel),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (channel.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              channel.unreadCount > 9
                                  ? '9+'
                                  : channel.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        IconButton(
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
                                        Navigator.pop(
                                            context); // Close bottom sheet
                                        final authProvider =
                                            context.read<AuthProvider>();
                                        final userProvider =
                                            context.read<UserProvider>();

                                        if (authProvider.accessToken != null &&
                                            userProvider.userId != null) {
                                          final success = await channelProvider
                                              .leaveChannel(
                                            authProvider.accessToken!,
                                            channel.id,
                                            userProvider.userId!,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  success
                                                      ? 'Left ${channel.name}'
                                                      : channelProvider.error ??
                                                          'Failed to leave channel',
                                                ),
                                                backgroundColor:
                                                    success ? null : Colors.red,
                                              ),
                                            );
                                          }
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Unable to leave channel: User ID not found'),
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
                      ],
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
