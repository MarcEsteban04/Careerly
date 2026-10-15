enum GoalPeriod {
  weekly('This week'),
  monthly('This month'),
  once('One-time');

  const GoalPeriod(this.label);

  final String label;

  static GoalPeriod fromName(String name) => values.firstWhere(
        (period) => period.name == name,
        orElse: () => GoalPeriod.once,
      );
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.target,
    required this.progress,
    required this.period,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        title: json['title'] as String,
        target: json['target'] as int,
        progress: json['progress'] as int,
        period: GoalPeriod.fromName(json['period'] as String),
      );

  final String id;
  final String title;
  final int target;
  final int progress;
  final GoalPeriod period;

  bool get isComplete => progress >= target;

  double get fraction => (progress / target).clamp(0, 1).toDouble();

  Goal copyWith({int? progress}) => Goal(
        id: id,
        title: title,
        target: target,
        progress: progress ?? this.progress,
        period: period,
      );
}
