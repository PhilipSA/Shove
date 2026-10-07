// The min-max weights that the tuning tools adjust.
import 'package:shove/ai/min_max/min_max_config.dart';

typedef TuneParam = ({
  String name,
  int Function(MinMaxConfig) read,
  MinMaxConfig Function(MinMaxConfig, int) write,
});

List<int> _with(List<int> list, int index, int value) =>
    [...list]..[index] = value;

final tuneParams = <TuneParam>[
  (
    name: 'shoverValue',
    read: (c) => c.shoverValue,
    write: (c, v) => c.copyWith(shoverValue: v),
  ),
  (
    name: 'throwerValue',
    read: (c) => c.throwerValue,
    write: (c, v) => c.copyWith(throwerValue: v),
  ),
  (
    name: 'blockerValue',
    read: (c) => c.blockerValue,
    write: (c, v) => c.copyWith(blockerValue: v),
  ),
  (
    name: 'leaperValue',
    read: (c) => c.leaperValue,
    write: (c, v) => c.copyWith(leaperValue: v),
  ),
  (
    name: 'chargerValue',
    read: (c) => c.chargerValue,
    write: (c, v) => c.copyWith(chargerValue: v),
  ),
  (
    name: 'hookValue',
    read: (c) => c.hookValue,
    write: (c, v) => c.copyWith(hookValue: v),
  ),
  for (var i = 1; i <= 5; i++)
    (
      name: 'shoverAdvance[$i]',
      read: (c) => c.shoverAdvance[i],
      write: (c, v) => c.copyWith(shoverAdvance: _with(c.shoverAdvance, i, v)),
    ),
  for (var i = 1; i <= 6; i++)
    (
      name: 'passedShoverBonus[$i]',
      read: (c) => c.passedShoverBonus[i],
      write: (c, v) =>
          c.copyWith(passedShoverBonus: _with(c.passedShoverBonus, i, v)),
    ),
  for (var i = 1; i <= 3; i++)
    (
      name: 'shoverScarcity[$i]',
      read: (c) => c.shoverScarcity[i],
      write: (c, v) =>
          c.copyWith(shoverScarcity: _with(c.shoverScarcity, i, v)),
    ),
  (
    name: 'incapacitatedPenalty',
    read: (c) => c.incapacitatedPenalty,
    write: (c, v) => c.copyWith(incapacitatedPenalty: v),
  ),
  (
    name: 'throwerReach',
    read: (c) => c.throwerReach,
    write: (c, v) => c.copyWith(throwerReach: v),
  ),
  (
    name: 'leaperReach',
    read: (c) => c.leaperReach,
    write: (c, v) => c.copyWith(leaperReach: v),
  ),
  (
    name: 'blockerGuardBonus',
    read: (c) => c.blockerGuardBonus,
    write: (c, v) => c.copyWith(blockerGuardBonus: v),
  ),
  (
    name: 'shoverSupportBonus',
    read: (c) => c.shoverSupportBonus,
    write: (c, v) => c.copyWith(shoverSupportBonus: v),
  ),
  (
    name: 'springboardBonus',
    read: (c) => c.springboardBonus,
    write: (c, v) => c.copyWith(springboardBonus: v),
  ),
  (name: 'tempo', read: (c) => c.tempo, write: (c, v) => c.copyWith(tempo: v)),
];

MinMaxConfig configFromTheta(MinMaxConfig base, List<double> theta) {
  var config = base;
  for (var i = 0; i < tuneParams.length; i++) {
    config = tuneParams[i].write(config, theta[i].round());
  }
  return config;
}
