import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nakshatra/config/db.dart';
import 'package:nakshatra/model/login_response/user.dart';
import 'package:nakshatra/model/login_response/user_branch_linking.dart';
import 'package:nakshatra/router/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<({User? user, List<UserBranchLinking> linkings})> _load() async {
    final user = await LocalDb.getUser();
    final linkings = await LocalDb.getUserBranchLinkings();
    return (user: user, linkings: linkings);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: scheme.surface,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await LocalDb.logout();
              if (!context.mounted) return;
              context.go(AppRouter.login);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder(
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!.user;
          final linkings = snapshot.data!.linkings;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Unknown user',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(user?.email ?? ''),
                      const SizedBox(height: 4),
                      Text('User id: ${user?.id ?? ''}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Branches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (linkings.isEmpty)
                Text(
                  'No branch linkings found.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              else
                ...linkings.map((e) {
                  final b = e.branchDetails;
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      title: Text(b?.name ?? 'Unknown branch'),
                      subtitle: Text(b?.address ?? ''),
                      trailing: Text('Type: ${e.userType ?? '-'}'),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
