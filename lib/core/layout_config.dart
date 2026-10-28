class LayoutConfig {
  LayoutConfig({
    double leftFraction = .58,
    List<double> rowWeights = const [1, 1.2, .8],
    List<bool> rowEnabled = const [true, true, true],
    String theme = 'auto',
    double fontScale = 1,
  }) : leftFraction = finite(leftFraction, .58).clamp(.4, .75).toDouble(),
       rowWeights = List.unmodifiable(
         List.generate(
           3,
           (i) => i < rowWeights.length
               ? finite(rowWeights[i], 1).clamp(.1, 10).toDouble()
               : 1.0,
         ),
       ),
       rowEnabled = List.unmodifiable(
         List.generate(3, (i) => i < rowEnabled.length ? rowEnabled[i] : true),
       ),
       theme = ['auto', 'light', 'dark'].contains(theme) ? theme : 'auto',
       fontScale = finite(fontScale, 1).clamp(.8, 1.6).toDouble();
  final double leftFraction;
  final List<double> rowWeights;
  final List<bool> rowEnabled;
  final String theme;
  final double fontScale;
  static double finite(double value, double fallback) =>
      value.isFinite ? value : fallback;
  factory LayoutConfig.fromJson(Map<String, dynamic> json) => LayoutConfig(
    leftFraction: (json['leftFraction'] as num?)?.toDouble() ?? .58,
    rowWeights:
        (json['rowWeights'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [1, 1.2, .8],
    rowEnabled:
        (json['rowEnabled'] as List?)?.cast<bool>() ?? [true, true, true],
    theme: json['theme'] as String? ?? 'auto',
    fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1,
  );
  Map<String, dynamic> toJson() => {
    'leftFraction': leftFraction,
    'rowWeights': rowWeights,
    'rowEnabled': rowEnabled,
    'theme': theme,
    'fontScale': fontScale,
  };
  LayoutConfig copyWith({
    double? leftFraction,
    List<double>? rowWeights,
    List<bool>? rowEnabled,
    String? theme,
    double? fontScale,
  }) => LayoutConfig(
    leftFraction: leftFraction ?? this.leftFraction,
    rowWeights: rowWeights ?? this.rowWeights,
    rowEnabled: rowEnabled ?? this.rowEnabled,
    theme: theme ?? this.theme,
    fontScale: fontScale ?? this.fontScale,
  );
  List<double> get fractions {
    final active = [
      for (var i = 0; i < 3; i++)
        if (rowEnabled[i]) i,
    ];
    final result = [0.0, 0.0, 0.0];
    if (active.isEmpty) return result;
    if (active.length < 3) {
      for (final i in active) {
        result[i] = 1 / active.length;
      }
      return result;
    }
    var remaining = 1.0;
    final pending = [...active];
    while (pending.isNotEmpty) {
      final sum = pending.fold(0.0, (sum, i) => sum + rowWeights[i]);
      final small = pending
          .where((i) => remaining * rowWeights[i] / sum < .15)
          .toList();
      if (small.isEmpty) {
        for (final i in pending) {
          result[i] = remaining * rowWeights[i] / sum;
        }
        break;
      }
      for (final i in small) {
        result[i] = .15;
        remaining -= .15;
        pending.remove(i);
      }
    }
    return result;
  }
}
