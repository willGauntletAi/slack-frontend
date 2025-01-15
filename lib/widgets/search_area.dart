import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/search_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/ask_ai_provider.dart';

class SearchArea extends StatefulWidget {
  final VoidCallback onClose;

  const SearchArea({
    super.key,
    required this.onClose,
  });

  @override
  State<SearchArea> createState() => _SearchAreaState();
}

class _SearchAreaState extends State<SearchArea> {
  final _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  Timer? _aiDebounceTimer;
  bool _isDebouncingAi = false;
  static const _searchDebounceTime = Duration(milliseconds: 300);
  static const _askAiDebounceTime = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _aiDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _searchDebounceTimer?.cancel();
    _aiDebounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _isDebouncingAi = false;
      });
      return;
    }

    // Start debouncing AI
    setState(() {
      _isDebouncingAi = true;
    });

    _searchDebounceTimer = Timer(_searchDebounceTime, () {
      _performSearch();
    });

    _aiDebounceTimer = Timer(_askAiDebounceTime, () {
      setState(() {
        _isDebouncingAi = false;
      });
      _performAiSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final workspaceProvider = context.read<WorkspaceProvider>();
    final searchProvider = context.read<SearchProvider>();

    if (authProvider.accessToken == null ||
        workspaceProvider.selectedWorkspace == null) {
      return;
    }

    await searchProvider.search(
      authProvider.accessToken!,
      query,
      workspaceProvider.selectedWorkspace!.id,
    );
  }

  Future<void> _performAiSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final workspaceProvider = context.read<WorkspaceProvider>();
    final askAiProvider = context.read<AskAiProvider>();
    final channelProvider = context.read<ChannelProvider>();

    if (authProvider.accessToken == null ||
        workspaceProvider.selectedWorkspace == null) {
      return;
    }

    await askAiProvider.askAi(
      accessToken: authProvider.accessToken!,
      query: query,
      workspaceId: workspaceProvider.selectedWorkspace!.id,
      channelId: channelProvider.selectedChannel?.id,
    );
  }

  Widget _buildSkeletonCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: SizedBox(),
        ),
        title: Container(
          height: 16,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required String content,
    required String username,
    required DateTime createdAt,
    String? matchContext,
    double? relevanceScore,
    required String channelId,
    required String messageId,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            username[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(username)),
            if (relevanceScore != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'AI Relevance: ${(relevanceScore * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            if (matchContext != null) ...[
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                  ),
                  children: _buildMatchContextSpans(
                    matchContext,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          _formatDate(createdAt),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        onTap: () {
          final channelProvider = context.read<ChannelProvider>();
          final channel = channelProvider.channels.firstWhere(
            (c) => c.id == channelId,
            orElse: () => channelProvider.selectedChannel!,
          );

          channelProvider.selectChannel(channel, messageId: messageId);
          widget.onClose();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search messages or ask a question...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                tooltip: 'Close search',
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer2<SearchProvider, AskAiProvider>(
            builder: (context, searchProvider, askAiProvider, _) {
              if (_searchController.text.isEmpty) {
                return const Center(
                  child: Text('Enter a search term or ask a question'),
                );
              }

              final List<Widget> items = [];

              // Add AI section
              if (_isDebouncingAi || askAiProvider.isLoading) {
                items.addAll([
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Loading AI results...',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (askAiProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'AI search failed: ${askAiProvider.error}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ...List.generate(3, (_) => _buildSkeletonCard()),
                ]);
              } else if (askAiProvider.lastResponse != null) {
                if (askAiProvider.lastResponse!.answer.isNotEmpty) {
                  items.add(
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.psychology_outlined),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'AI Answer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(askAiProvider.lastResponse!.answer),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (askAiProvider.lastResponse!.relevantMessages.isNotEmpty) {
                  items.add(
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Most Relevant Messages',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );

                  items.addAll(
                    askAiProvider.lastResponse!.relevantMessages.map((msg) {
                      return _buildMessageCard(
                        content: msg.content,
                        username: msg.username,
                        createdAt: msg.createdAt,
                        relevanceScore: msg.similarity,
                        channelId: msg.channelId,
                        messageId: msg.id,
                      );
                    }),
                  );
                }
              }

              // Add search results section
              if (searchProvider.error != null) {
                items.add(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      searchProvider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              } else if (searchProvider.results.isNotEmpty) {
                items.add(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Search Results (${searchProvider.totalCount})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );

                items.addAll(
                  searchProvider.results.map((result) {
                    return _buildMessageCard(
                      content: result.content,
                      username: result.username,
                      createdAt: result.createdAt,
                      matchContext: result.matchContext,
                      channelId: result.channelId,
                      messageId: result.id,
                    );
                  }),
                );
              }

              if (items.isEmpty) {
                return const Center(
                  child: Text('No results found'),
                );
              }

              return ListView(
                children: items,
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  List<TextSpan> _buildMatchContextSpans(String text, Color highlightColor) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'<b>(.*?)</b>|([^<]+)');
    final Iterable<RegExpMatch> matches = exp.allMatches(text);

    for (final match in matches) {
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            backgroundColor: highlightColor.withOpacity(0.2),
            fontWeight: FontWeight.bold,
            color: highlightColor,
          ),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(text: match.group(2)));
      }
    }

    return spans;
  }
}
