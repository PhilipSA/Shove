/// Tunable parameters of the min-max search. The defaults are the strongest
/// variant found by `tool/min_max_tournament.dart`.
class MinMaxConfig {
  // Piece values; 100 is roughly one shover.
  final int shoverValue;
  final int throwerValue;
  final int blockerValue;
  final int leaperValue;
  final int chargerValue;
  final int hookValue;
  /// Shover bonus by rows left to the goal.
  final List<int> shoverAdvance;

  /// Extra shover bonus by rows left to the goal when nothing can stop it.
  final List<int> passedShoverBonus;

  final int incapacitatedPenalty;
  final int throwerReach;
  final int leaperReach;
  final int blockerGuardBonus;

  /// Bonus for a shover with a friendly piece right behind it.
  final int shoverSupportBonus;

  /// Bonus for a shover with a friendly leaper ahead to hop over.
  final int springboardBonus;
  /// A piece that can be shoved off the board loses value / divisor.
  final int edgeDangerOwnTurnDivisor;
  final int edgeDangerOpponentTurnDivisor;

  /// Penalty by number of shovers left (index), none beyond the list.
  final List<int> shoverScarcity;

  final int tempo;

  /// Quiet moves from this index and at this depth are searched shallower first.
  final int lateMoveReductionFromIndex;
  final int lateMoveReductionMinDepth;

  final int maxQuiescenceDepth;

  const MinMaxConfig({
    this.shoverValue = 160,
    this.throwerValue = 280,
    this.blockerValue = 180,
    this.leaperValue = 280,
    this.chargerValue = 360,
    this.hookValue = 240,
    this.shoverAdvance = const [0, 300, 150, 80, 40, 16, 0, 0],
    this.passedShoverBonus = const [0, 260, 150, 80, 40, 20, 6, 0],
    this.incapacitatedPenalty = 30,
    this.throwerReach = 20,
    this.leaperReach = 10,
    this.blockerGuardBonus = 10,
    this.shoverSupportBonus = 0,
    this.springboardBonus = 30,
    this.edgeDangerOwnTurnDivisor = 3,
    this.edgeDangerOpponentTurnDivisor = 1,
    this.shoverScarcity = const [0, -300, -120, -45],
    this.tempo = 15,
    this.lateMoveReductionFromIndex = 4,
    this.lateMoveReductionMinDepth = 3,
    this.maxQuiescenceDepth = 6,
  });

  MinMaxConfig copyWith({
    int? shoverValue,
    int? throwerValue,
    int? blockerValue,
    int? leaperValue,
    int? chargerValue,
    int? hookValue,
    List<int>? shoverAdvance,
    List<int>? passedShoverBonus,
    int? incapacitatedPenalty,
    int? throwerReach,
    int? leaperReach,
    int? blockerGuardBonus,
    int? shoverSupportBonus,
    int? springboardBonus,
    int? edgeDangerOwnTurnDivisor,
    int? edgeDangerOpponentTurnDivisor,
    List<int>? shoverScarcity,
    int? tempo,
    int? lateMoveReductionFromIndex,
    int? lateMoveReductionMinDepth,
    int? maxQuiescenceDepth,
  }) => MinMaxConfig(
    shoverValue: shoverValue ?? this.shoverValue,
    throwerValue: throwerValue ?? this.throwerValue,
    blockerValue: blockerValue ?? this.blockerValue,
    leaperValue: leaperValue ?? this.leaperValue,
    chargerValue: chargerValue ?? this.chargerValue,
    hookValue: hookValue ?? this.hookValue,
    shoverAdvance: shoverAdvance ?? this.shoverAdvance,
    passedShoverBonus: passedShoverBonus ?? this.passedShoverBonus,
    incapacitatedPenalty: incapacitatedPenalty ?? this.incapacitatedPenalty,
    throwerReach: throwerReach ?? this.throwerReach,
    leaperReach: leaperReach ?? this.leaperReach,
    blockerGuardBonus: blockerGuardBonus ?? this.blockerGuardBonus,
    shoverSupportBonus: shoverSupportBonus ?? this.shoverSupportBonus,
    springboardBonus: springboardBonus ?? this.springboardBonus,
    edgeDangerOwnTurnDivisor:
        edgeDangerOwnTurnDivisor ?? this.edgeDangerOwnTurnDivisor,
    edgeDangerOpponentTurnDivisor:
        edgeDangerOpponentTurnDivisor ?? this.edgeDangerOpponentTurnDivisor,
    shoverScarcity: shoverScarcity ?? this.shoverScarcity,
    tempo: tempo ?? this.tempo,
    lateMoveReductionFromIndex:
        lateMoveReductionFromIndex ?? this.lateMoveReductionFromIndex,
    lateMoveReductionMinDepth:
        lateMoveReductionMinDepth ?? this.lateMoveReductionMinDepth,
    maxQuiescenceDepth: maxQuiescenceDepth ?? this.maxQuiescenceDepth,
  );

  @override
  String toString() =>
      'MinMaxConfig('
      'shoverValue: $shoverValue, throwerValue: $throwerValue, '
      'blockerValue: $blockerValue, leaperValue: $leaperValue, '
      'chargerValue: $chargerValue, hookValue: $hookValue, '
      'shoverAdvance: $shoverAdvance, passedShoverBonus: $passedShoverBonus, '
      'incapacitatedPenalty: $incapacitatedPenalty, '
      'throwerReach: $throwerReach, leaperReach: $leaperReach, '
      'blockerGuardBonus: $blockerGuardBonus, '
      'shoverSupportBonus: $shoverSupportBonus, '
      'springboardBonus: $springboardBonus, '
      'edgeDangerOwnTurnDivisor: $edgeDangerOwnTurnDivisor, '
      'edgeDangerOpponentTurnDivisor: $edgeDangerOpponentTurnDivisor, '
      'shoverScarcity: $shoverScarcity, tempo: $tempo, '
      'lateMoveReductionFromIndex: $lateMoveReductionFromIndex, '
      'lateMoveReductionMinDepth: $lateMoveReductionMinDepth, '
      'maxQuiescenceDepth: $maxQuiescenceDepth)';
}
