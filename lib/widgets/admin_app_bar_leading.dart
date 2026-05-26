import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';

class AdminAppBarLeading extends ConsumerWidget {
  const AdminAppBarLeading({super.key, this.fallbackRoute});

  final String? fallbackRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();
    final role = ref.read(authProvider).userProfile?.role;
    final targetRoute =
        fallbackRoute ?? (role == 'admin_crew' ? '/admin/crew' : '/admin/priv');

    return IconButton(
      tooltip: canPop ? 'Indietro' : 'Home',
      icon: Icon(canPop ? Icons.arrow_back : Icons.home),
      onPressed: () {
        if (canPop) {
          Navigator.of(context).maybePop();
        } else {
          context.go(targetRoute);
        }
      },
    );
  }
}
