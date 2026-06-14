import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
	const InfoCard({
		super.key,
		required this.title,
		required this.message,
		this.leading,
	});

	final String title;
	final String message;
	final Widget? leading;

	@override
	Widget build(BuildContext context) {
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Row(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						if (leading != null) ...[
							leading!,
							const SizedBox(width: 12),
						],
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(title, style: Theme.of(context).textTheme.titleLarge),
									const SizedBox(height: 8),
									Text(message, style: Theme.of(context).textTheme.bodyLarge),
								],
							),
						),
					],
				),
			),
		);
	}
}
