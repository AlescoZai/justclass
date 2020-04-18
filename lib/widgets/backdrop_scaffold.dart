import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class Backdrop extends InheritedWidget {
  final _BackdropScaffoldState data;

  Backdrop({Key key, @required this.data, @required Widget child}) : super(key: key, child: child);

  static _BackdropScaffoldState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Backdrop>().data;

  @override
  bool updateShouldNotify(Backdrop old) => true;
}

class BackdropScaffold extends StatefulWidget {
  final AnimationController controller;
  final Widget title;
  final Widget backLayer;
  final Widget frontLayer;
  final List<Widget> actions;
  final double headerHeight;
  final BorderRadius frontLayerBorderRadius;
  final BackdropIconPosition iconPosition;
  final bool stickyFrontLayer;
  final Curve animationCurve;
  final Color appBarColor;
  final Color backLayerColor;
  final Widget leading;

  BackdropScaffold({
    this.controller,
    this.title,
    this.backLayer,
    this.frontLayer,
    this.leading,
    this.actions = const <Widget>[],
    this.headerHeight = 32.0,
    this.frontLayerBorderRadius = const BorderRadius.only(
      topLeft: Radius.circular(15.0),
      topRight: Radius.circular(15.0),
    ),
    this.iconPosition = BackdropIconPosition.leading,
    this.stickyFrontLayer = false,
    this.animationCurve = Curves.linear,
    this.appBarColor = Colors.blue,
    this.backLayerColor = Colors.blue,
  });

  @override
  _BackdropScaffoldState createState() => _BackdropScaffoldState();
}

class _BackdropScaffoldState extends State<BackdropScaffold> with SingleTickerProviderStateMixin {
  bool _shouldDisposeController = false;
  AnimationController _controller;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey _backLayerKey = GlobalKey();
  double _backPanelHeight = 0;

  AnimationController get controller => _controller;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _shouldDisposeController = true;
      _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 200), value: 1.0);
    } else {
      _controller = widget.controller;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _backPanelHeight = _getBackPanelHeight();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (_shouldDisposeController) _controller.dispose();
  }

  bool get isTopPanelVisible =>
      controller.status == AnimationStatus.completed || controller.status == AnimationStatus.forward;

  bool get isBackPanelVisible {
    final AnimationStatus status = controller.status;
    return status == AnimationStatus.dismissed || status == AnimationStatus.reverse;
  }

  void fling() => controller.fling(velocity: isTopPanelVisible ? -1.0 : 1.0);

  void showBackLayer() {
    if (isTopPanelVisible) controller.fling(velocity: -1.0);
  }

  void showFrontLayer() {
    if (isBackPanelVisible) controller.fling(velocity: 1.0);
  }

  double _getBackPanelHeight() =>
      ((_backLayerKey.currentContext?.findRenderObject() as RenderBox)?.size?.height) ?? 0.0;

  Animation<RelativeRect> getPanelAnimation(BuildContext context, BoxConstraints constraints) {
    var backPanelHeight, frontPanelHeight;

    if (widget.stickyFrontLayer && _backPanelHeight < constraints.biggest.height - widget.headerHeight) {
      // height is adapted to the height of the back panel
      backPanelHeight = _backPanelHeight;
      frontPanelHeight = -_backPanelHeight;
    } else {
      // height is set to fixed value defined in widget.headerHeight
      final height = constraints.biggest.height;
      backPanelHeight = height - widget.headerHeight;
      frontPanelHeight = -backPanelHeight;
    }
    return RelativeRectTween(
      begin: RelativeRect.fromLTRB(0.0, backPanelHeight, 0.0, frontPanelHeight),
      end: RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: controller,
      curve: widget.animationCurve,
    ));
  }

  Widget _buildInactiveLayer(BuildContext context) {
    return Offstage(
      offstage: isTopPanelVisible,
      child: GestureDetector(
        onTap: () => fling(),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.frontLayerBorderRadius,
              color: Colors.black12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackPanel() {
    return FocusScope(
      canRequestFocus: isBackPanelVisible,
      child: Container(
        width: double.infinity,
        color: widget.backLayerColor,
        child: Column(
          children: <Widget>[
            Flexible(key: _backLayerKey, child: widget.backLayer ?? Container()),
          ],
        ),
      ),
    );
  }

//  Widget _buildFrontPanel(BuildContext context) {
//    return Material(
//      elevation: 12.0,
//      borderRadius: widget.frontLayerBorderRadius,
//      child: Stack(
//        children: <Widget>[
//          widget.frontLayer,
//          _buildInactiveLayer(context),
//        ],
//      ),
//    );
//  }

  Widget _buildFrontPanel(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.frontLayerBorderRadius,
      child: Container(
        color: Colors.white,
        child: Stack(
          children: <Widget>[
            widget.frontLayer,
            _buildInactiveLayer(context),
          ],
        ),
      ),
    );
  }

  Future<bool> _willPopCallback(BuildContext context) async {
    if (isBackPanelVisible) {
      showFrontLayer();
      return null;
    }
    return true;
  }

  Widget _buildBody(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _willPopCallback(context),
      child: Scaffold(
        key: scaffoldKey,
        resizeToAvoidBottomInset: false,
        backgroundColor: widget.backLayerColor,
        appBar: AppBar(
          backgroundColor: widget.appBarColor,
          title: widget.title,
          actions: widget.iconPosition == BackdropIconPosition.action
              ? <Widget>[BackdropToggleButton()] + widget.actions
              : widget.actions,
          elevation: 0.0,
          leading: widget.iconPosition == BackdropIconPosition.leading ? BackdropToggleButton() : widget.leading,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                child: Stack(
                  children: <Widget>[
                    _buildBackPanel(),
                    PositionedTransition(
                      rect: getPanelAnimation(context, constraints),
                      child: _buildFrontPanel(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      data: this,
      child: Builder(
        builder: (context) => _buildBody(context),
      ),
    );
  }
}

class BackdropToggleButton extends StatelessWidget {
  final IconData icon;

  const BackdropToggleButton({
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Backdrop.of(context).controller;
    final anim = Tween<double>(begin: -0.75 * pi, end: 0).animate(controller);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(angle: anim.value, child: child);
      },
      child: IconButton(
        icon: Icon(this.icon, size: 30),
        onPressed: () => Backdrop.of(context).fling(),
      ),
    );
  }
}

enum BackdropIconPosition { none, leading, action }

class BackdropNavigationBackLayer extends StatelessWidget {
  final List<Widget> items;
  final ValueChanged<int> onTap;
  final Widget separator;

  BackdropNavigationBackLayer({
    Key key,
    @required this.items,
    this.onTap,
    this.separator,
  })  : assert(items != null),
        assert(items.isNotEmpty),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, position) => InkWell(
        child: items[position],
        onTap: () {
          // fling backdrop
          Backdrop.of(context).fling();

          // call onTap function and pass new selected index
          onTap?.call(position);
        },
      ),
      separatorBuilder: (builder, position) => separator ?? Container(),
    );
  }
}
