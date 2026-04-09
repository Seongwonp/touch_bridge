import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppText {
	AppText._();

	// Slightly larger defaults reduce cognitive and visual strain.
	static const TextTheme textTheme = TextTheme(
		headlineLarge: TextStyle(
			fontSize: 32,
			fontWeight: FontWeight.w700,
			color: AppColors.textPrimary,
			height: 1.2,
		),
		headlineMedium: TextStyle(
			fontSize: 26,
			fontWeight: FontWeight.w700,
			color: AppColors.textPrimary,
			height: 1.2,
		),
		titleLarge: TextStyle(
			fontSize: 22,
			fontWeight: FontWeight.w600,
			color: AppColors.textPrimary,
			height: 1.3,
		),
		bodyLarge: TextStyle(
			fontSize: 18,
			fontWeight: FontWeight.w500,
			color: AppColors.textPrimary,
			height: 1.4,
		),
		bodyMedium: TextStyle(
			fontSize: 16,
			fontWeight: FontWeight.w400,
			color: AppColors.textPrimary,
			height: 1.4,
		),
		bodySmall: TextStyle(
			fontSize: 14,
			fontWeight: FontWeight.w400,
			color: AppColors.textSecondary,
			height: 1.4,
		),
		labelLarge: TextStyle(
			fontSize: 18,
			fontWeight: FontWeight.w600,
			color: AppColors.textPrimary,
			height: 1.2,
		),
	);
}
