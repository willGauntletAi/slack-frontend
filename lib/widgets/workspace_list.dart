import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';

class WorkspaceList extends StatelessWidget {
  final void Function() onCreateWorkspace;

  const WorkspaceList({
    super.key,
    required this.onCreateWorkspace,
  });

  @override
  Widget build(BuildContext context) {
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
                    onTap: onCreateWorkspace,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 32),
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
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  color: Colors.red,
                  tooltip: 'Logout',
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
                  final isSelected =
                      workspace.id == workspaceProvider.selectedWorkspace?.id;

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
                            onTap: () =>
                                workspaceProvider.selectWorkspace(workspace),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: isFullScreen ? 64 : 48,
                              height: isFullScreen ? 64 : 48,
                              alignment: Alignment.center,
                              child: Text(
                                workspace.name[0].toUpperCase(),
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isFullScreen ? 24 : 20,
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
                  onTap: onCreateWorkspace,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: isFullScreen ? 64 : 48,
                    height: isFullScreen ? 64 : 48,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add,
                      size: isFullScreen ? 32 : 24,
                    ),
                  ),
                ),
              ),
            ),
            if (isFullScreen) const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
