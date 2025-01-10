import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slack_frontend/providers/channel_provider.dart';
import '../providers/auth_provider.dart';

class DMList extends StatelessWidget {
  final void Function() onCreateDmChannel;
  const DMList({super.key, required this.onCreateDmChannel});

  @override
  Widget build(BuildContext context) {
    final channelProvider = context.watch<ChannelProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    // Filter for DM channels (channels with null name)
    final dmChannels = channelProvider.channels
        .where((channel) => channel.name == null)
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('New DM'),
          onTap: onCreateDmChannel,
        ),
        if (dmChannels.isEmpty)
          const ListTile(
            dense: true,
            title: Text(
              'No conversations yet',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          )
        else
          ...dmChannels.map((channel) {
            // Get the other usernames (not the current user)
            final otherUsernames = channel.usernames.where(
              (username) => username != currentUser?.username,
            );

            final isSelected =
                channelProvider.selectedChannel?.id == channel.id;
            return ListTile(
              selected: isSelected,
              leading: const Icon(Icons.person_outline),
              title: Text(
                otherUsernames.join(', '),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: channel.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
                    )
                  : null,
              onTap: () => channelProvider.selectChannel(
                channel,
                messageId:
                    channel.unreadCount > 50 ? channel.lastReadMessage : null,
              ),
            );
          }),
      ],
    );
  }
}
