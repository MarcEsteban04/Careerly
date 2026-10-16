import 'package:flutter/material.dart';

import '../../../applications/presentation/widgets/company_avatar.dart';

/// Employer logo from the job board, falling back to the company initial.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({
    super.key,
    required this.company,
    this.url,
    this.size = 44,
  });

  final String company;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final fallback = CompanyAvatar(company: company, size: size);
    if (url == null || url.isEmpty) return fallback;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Center(
          child: Text(
            company.trim().isEmpty ? '?' : company.trim()[0].toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
