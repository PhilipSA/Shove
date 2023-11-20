import 'package:flutter/material.dart';

class ChessBoardWidget extends StatelessWidget {
  const ChessBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          int row = index ~/ 8;
          int col = index % 8;
          Color color = (row.isEven && col.isEven) || (row.isOdd && col.isOdd)
              ? Colors.white
              : Colors.black;

          return Container(
            color: color,
          );
        },
      ),
    );
  }
}
