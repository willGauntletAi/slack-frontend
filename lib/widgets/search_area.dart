import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/search_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import 'chat_message.dart';

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
  Timer? _debounceTimer;
  static const _debounceTime = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceTime, () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search header
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
                    hintText: 'Search messages...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                tooltip: 'Close search',
              ),
            ],
          ),
        ),
        // Search results
        Expanded(
          child: Consumer<SearchProvider>(
            builder: (context, searchProvider, _) {
              if (searchProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (searchProvider.error != null) {
                return Center(
                  child: Text(
                    searchProvider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (_searchController.text.isEmpty) {
                return const Center(
                  child: Text('Enter a search term to begin'),
                );
              }

              if (searchProvider.results.isEmpty) {
                return const Center(
                  child: Text('No results found'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: searchProvider.results.length +
                    1, // +1 for total count header
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '${searchProvider.totalCount} results',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  final result = searchProvider.results[index - 1];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          result.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(result.username),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.content),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                                fontSize: 12,
                              ),
                              children: _buildMatchContextSpans(
                                result.matchContext,
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        _formatDate(result.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
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
        // Text within <b> tags
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            backgroundColor: highlightColor.withOpacity(0.2),
            fontWeight: FontWeight.bold,
            color: highlightColor,
          ),
        ));
      } else if (match.group(2) != null) {
        // Text outside <b> tags
        spans.add(TextSpan(text: match.group(2)));
      }
    }

    return spans;
  }
}
