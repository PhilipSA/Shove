import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';

class CellulaTabNavigation extends StatefulWidget {
  final CellulaTokens cellulaTokens;
  final List<Widget> tabs;
  final List<Widget> tabBarViews;
  final bool fullWidth;
  final Function(int) onTabSelected;

  const CellulaTabNavigation({
    required this.cellulaTokens,
    required this.tabs,
    required this.tabBarViews,
    required this.onTabSelected,
    this.fullWidth = true,
    super.key,
  });

  @override
  createState() => CellulaTabNavigationState();
}

class CellulaTabNavigationState extends State<CellulaTabNavigation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: widget.tabs.length);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    widget.onTabSelected(_tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.tabs.length == widget.tabBarViews.length,
      'Tabs and TabBarViews must have the same length',
    );

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: CellulaSpacing.x2.spacing),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: widget.cellulaTokens.border.defaultColor,
                  width: CellulaSpacing.x0_25.spacing,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: widget.tabs,
              isScrollable: !widget.fullWidth,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: widget.cellulaTokens.border.interactive,
                  width: CellulaSpacing.x0_25.spacing,
                ),
              ),
              indicatorColor: widget.cellulaTokens.border.interactive,
              dividerColor: widget.cellulaTokens.border.defaultColor,
              automaticIndicatorColorAdjustment: false,
              labelPadding: EdgeInsets.only(
                bottom: CellulaSpacing.x0_5.spacing,
                top: CellulaSpacing.x1.spacing,
              ),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.tabBarViews.toList(),
          ),
        ),
      ],
    );
  }
}
