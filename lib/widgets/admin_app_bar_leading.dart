import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminAppBarLeading extends StatelessWidget {
  const AdminAppBarLeading({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return IconButton(
      tooltip: canPop ? 'Indietro' : 'Home',
      icon: Icon(canPop ? Icons.arrow_back : Icons.home),
      onPressed: () {
        if (canPop) {
          Navigator.of(context).maybePop();
        } else {
          context.go('/dashboard');
        }
      },
    );
  }
}
