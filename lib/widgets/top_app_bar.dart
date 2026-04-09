import 'package:flutter/material.dart';

class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
	const TopAppBar({
		super.key,
		required this.title,
		this.showBack = false,
		this.actions,
	});

	final String title;
	final bool showBack;
	final List<Widget>? actions;

	@override
	Size get preferredSize => const Size.fromHeight(kToolbarHeight);

	@override
	Widget build(BuildContext context) {
		return AppBar(
			automaticallyImplyLeading: showBack,
			title: Text(title),
			actions: actions,
		);
	}
}
