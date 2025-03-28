import 'package:flutter/material.dart';

class CustomExpansionTile extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool isExpanded;
  final VoidCallback onTap;

  const CustomExpansionTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<CustomExpansionTile> createState() => _CustomExpansionTileState();
}

class _CustomExpansionTileState extends State<CustomExpansionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CustomExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[CustomExpansionTile] build - isExpanded: ${widget.isExpanded}');
    return Column(
      children: [
        // 헤더 부분
        InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                widget.leading,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.title,
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        widget.subtitle!,
                      ],
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
                const SizedBox(width: 8),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: widget.isExpanded ? 0.5 : 0,
                  child: const Icon(Icons.expand_more),
                ),
              ],
            ),
          ),
        ),
        // 확장되는 부분
        SizeTransition(sizeFactor: _controller, child: widget.child),
      ],
    );
  }
}
