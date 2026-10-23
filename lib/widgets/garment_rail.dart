import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../theme/app_theme.dart';

/// Independent horizontal selector. Rebuilding its parent never resets a drag.
class GarmentRail extends StatefulWidget {
  const GarmentRail(
      {super.key,
      required this.title,
      required this.garments,
      required this.selectedId,
      required this.compact,
      required this.onSelected});

  final String title;
  final List<Garment> garments;
  final String? selectedId;
  final bool compact;
  final ValueChanged<Garment> onSelected;

  @override
  State<GarmentRail> createState() => _GarmentRailState();
}

class _GarmentRailState extends State<GarmentRail> {
  late final PageController _controller;

  int get _selectedIndex {
    final index = widget.garments.indexWhere((g) => g.id == widget.selectedId);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(
        initialPage: _selectedIndex,
        viewportFraction: widget.compact ? .42 : .76);
  }

  @override
  void didUpdateWidget(covariant GarmentRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idsChanged = !listEquals(oldWidget.garments.map((g) => g.id).toList(),
        widget.garments.map((g) => g.id).toList());
    if (idsChanged || oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients || widget.garments.isEmpty)
          return;
        final target = _selectedIndex;
        // onPageChanged updates selection while dragging: do not interrupt it.
        if ((_controller.page ?? 0).round() == target && !idsChanged) return;
        _controller.jumpToPage(target);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = (constraints.maxWidth * (widget.compact ? .42 : .76) - 16)
          .clamp(80.0, widget.compact ? 160.0 : 280.0);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Text('${widget.title} · ${widget.garments.length}',
              style: const TextStyle(
                  color: AppTheme.mediumBrown,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        if (widget.garments.isEmpty)
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                  'Agrega prendas de ${widget.title.toLowerCase()} en el armario.'))
        else
          SizedBox(
            height: side + 48,
            child: PageView.builder(
              key: ValueKey('rail-${widget.title}'),
              controller: _controller,
              pageSnapping: false,
              physics: const ClampingScrollPhysics(),
              itemCount: widget.garments.length,
              onPageChanged: (index) =>
                  widget.onSelected(widget.garments[index]),
              itemBuilder: (context, index) {
                final garment = widget.garments[index];
                final selected = garment.id ==
                    (widget.selectedId ?? widget.garments.first.id);
                return GestureDetector(
                  key: ValueKey('garment-${widget.title}-${garment.id}'),
                  onTap: () => widget.onSelected(garment),
                  child: Column(children: [
                    Container(
                      width: side,
                      height: side,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color:
                                  selected ? AppTheme.darkBrown : AppTheme.line,
                              width: selected ? 2 : 1)),
                      child: garment.imagePath.isEmpty
                          ? const Icon(Icons.checkroom_outlined)
                          : Image.file(File(garment.imagePath),
                              fit: BoxFit.contain,
                              cacheWidth: widget.compact ? 320 : 640,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined)),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(garment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal))),
                    Text('${index + 1} / ${widget.garments.length}',
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.mediumBrown)),
                  ]),
                );
              },
            ),
          ),
      ]);
    });
  }
}
