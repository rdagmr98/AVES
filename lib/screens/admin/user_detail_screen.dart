import 'package:flutter/material.dart';

import '../../models/user_models.dart';
import 'user_management_screen.dart';

@Deprecated('Use UserManagementScreen instead.')
class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return const UserManagementScreen();
  }
}
