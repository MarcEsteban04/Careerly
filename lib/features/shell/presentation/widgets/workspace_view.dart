import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/workspace_controller.dart';
import '../../data/workspace_data.dart';

/// Rebuilds with the workspace and handles the shared loading and error
/// states, so tabs only describe the loaded case.
class WorkspaceView extends StatelessWidget {
  const WorkspaceView({
    super.key,
    required this.controller,
    required this.builder,
    this.loading,
  });

  final WorkspaceController controller;
  final Widget Function(BuildContext context, WorkspaceData data) builder;

  /// Placeholder while loading; defaults to a spinner.
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.data;
        final error = controller.error;
        if (data != null) return builder(context, data);
        if (error != null) return WorkspaceError(controller: controller);
        return loading ??
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            );
      },
    );
  }
}

/// Friendly error with a retry button.
class WorkspaceError extends StatelessWidget {
  const WorkspaceError({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.error!;
    final missingSchema = isMissingSchemaError(error);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: EmptyState(
        icon: missingSchema ? Icons.storage_rounded : Icons.cloud_off_rounded,
        title: missingSchema
            ? 'One setup step left'
            : "Couldn't load your workspace",
        message: friendlyErrorMessage(error),
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
        onAction: controller.retry,
      ),
    );
  }
}
