import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth_screen.dart';

class AccountScreen extends StatelessWidget {
  static const routeName = '/account';
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) => Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: auth.isLoggedIn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${auth.currentUser!.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.currentUser!.email,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await context.read<AuthProvider>().signOut();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signed out')),
                          );
                        },
                        child: const Text('Sign Out'),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('You are not signed in'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AuthScreen.routeName);
                        },
                        child: const Text('Sign In / Sign Up'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
