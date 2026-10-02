import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shove/main.dart';
import 'package:shove/ui/about/about_board_widget.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/game_board/shove_board_view.dart';
import 'package:shove/ui/play/player_selection_widget.dart';

import 'test_helpers.dart';

late MockAudioPlayers audio;

Future<void> pumpApp(WidgetTester tester) =>
    tester.pumpWidget(MyApp(createAudioPlayer: audio.create));

Future<void> openPlayerSelection(WidgetTester tester) async {
  await pumpApp(tester);
  await tester.tap(find.text('Play'));
  await tester.pumpAndSettle();
}

Future<void> selectPlayerType(
  WidgetTester tester,
  int dropdownIndex,
  String type,
) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w is DropdownButton).at(dropdownIndex),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(type).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => audio = MockAudioPlayers());

  testWidgets('start screen offers play and rules', (tester) async {
    await pumpApp(tester);

    expect(find.text('Shove'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
  });

  testWidgets('"How to play" opens the rules', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('How to play'));
    await tester.pumpAndSettle();

    expect(find.byType(About), findsOneWidget);
    expect(find.textContaining('Shover: moves one step'), findsOneWidget);
  });

  testWidgets('"Play" opens player selection and starts menu music', (
    tester,
  ) async {
    await openPlayerSelection(tester);

    expect(find.byType(PlayersWidget), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);
    final menuMusic = audio.created.single;
    verify(menuMusic.setReleaseMode(ReleaseMode.loop)).called(1);
    verify(menuMusic.play(any, volume: anyNamed('volume'))).called(1);
  });

  testWidgets('starting without names shows validation errors', (tester) async {
    await openPlayerSelection(tester);
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.text('Name can not be empty'), findsNWidgets(2));
    expect(find.byType(ShoveBoardWidget), findsNothing);
  });

  testWidgets('starting with names opens the game for both players', (
    tester,
  ) async {
    await openPlayerSelection(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Alice');
    await tester.enterText(find.byType(TextField).at(1), 'Bob');
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.byType(ShoveBoardWidget), findsOneWidget);
    expect(find.byType(BoardWidget), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('To move'), findsOneWidget);

    final [menuMusic, gameMusic] = audio.created;
    verify(menuMusic.stop()).called(1);
    verify(gameMusic.play(any, volume: anyNamed('volume'))).called(1);
  });

  testWidgets('choosing an AI opponent marks it as AI in the game', (
    tester,
  ) async {
    await openPlayerSelection(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Alice');
    await tester.enterText(find.byType(TextField).at(1), 'Bob');
    await selectPlayerType(tester, 1, 'randomAi');
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob (AI)'), findsOneWidget);
  });
}
