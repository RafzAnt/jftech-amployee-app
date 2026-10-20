import 'package:flutter/material.dart';

/// A part of the app that opens from a card on the Home or the Profile page: the page with a back arrow and its title.
class SectionPage extends StatelessWidget {
  final String title;
  final Widget child;

  const SectionPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(child: child),
      );
}
