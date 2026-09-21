import 'package:flutter/material.dart';
import 'data.dart';
import 'design.dart';
import 'localization.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.openDetail});
  final ValueChanged<DramaInfo> openDetail;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool collect = false, editing = false;
  final removed = <String>{};
  @override
  Widget build(BuildContext context) {
    final entries = (collect ? collected : history)
        .where((item) => !removed.contains(item.id))
        .toList();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff08090a), Color(0xff111111)],
          stops: [0, .3],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyHeader(
              height: pageTop(context) + 103,
              color: const Color(0xe00a0a0b),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, pageTop(context), 24, 0),
                child: Column(
                  children: [
                    Text(
                      tr(context, 'list'),
                      style: type(30, weight: 800, slant: -9, spacing: -1.8),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        for (final name in ['History', 'Collect']) ...[
                          if (name == 'Collect') const SizedBox(width: 18),
                          Pressable(
                            selected: collect == (name == 'Collect'),
                            onTap: () => setState(() {
                              collect = name == 'Collect';
                              editing = false;
                              removed.clear();
                            }),
                            child: Column(
                              children: [
                                Text(
                                  tr(context, name),
                                  style: type(
                                    25,
                                    weight: 700,
                                    spacing: -.875,
                                    color: collect == (name == 'Collect')
                                        ? Colors.white
                                        : const Color(0x61ebebed),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AnimatedContainer(
                                  duration: motion,
                                  curve: spring,
                                  width: 18,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(99),
                                    color: collect == (name == 'Collect')
                                        ? const Color(0xebffffff)
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              constraints: const BoxConstraints(minHeight: 954),
              padding: const EdgeInsets.fromLTRB(24, 13, 24, 112),
              child: Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${entries.length}',
                                  style: type(
                                    14,
                                    weight: 520,
                                    color: const Color(0xfff4f4f5),
                                  ),
                                ),
                                TextSpan(
                                  text: tr(
                                    context,
                                    ' Short Dramas In The List',
                                    ' 部短剧',
                                  ),
                                  style: type(
                                    14,
                                    weight: 430,
                                    color: const Color(0x8fe1e1e5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -5.5),
                          child: CircleControl(
                            key: const ValueKey('list-edit'),
                            size: 40,
                            label: editing ? '完成编辑' : '编辑列表',
                            onTap: () {
                              setState(() => editing = !editing);
                            },
                            child: editing
                                ? const Icon(
                                    Icons.check,
                                    size: 19,
                                    color: Color(0xc7f0f0f2),
                                  )
                                : const Glyph('list-edit', size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 22),
                    Entrance(
                      key: ValueKey('${entries[i].id}-$editing'),
                      child: _DramaRow(
                        item: entries[i],
                        editing: editing,
                        collect: collect,
                        onOpen: () {
                          if (!editing) {
                            widget.openDetail(entries[i].detail);
                          }
                        },
                        onDelete: () {
                          setState(() => removed.add(entries[i].id));
                        },
                      ),
                    ),
                  ],
                  if (entries.isEmpty)
                    SizedBox(
                      height: 350,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Glass(
                            width: 48,
                            height: 48,
                            child: Center(child: Icon(Icons.check, size: 20)),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            tr(context, 'List is clear', '片单已清空'),
                            style: type(17, weight: 700),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            tr(
                              context,
                              'You can collect more short dramas anytime.',
                              '随时收藏更多喜欢的短剧。',
                            ),
                            style: type(12, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DramaRow extends StatefulWidget {
  const _DramaRow({
    required this.item,
    required this.editing,
    required this.collect,
    required this.onOpen,
    required this.onDelete,
  });
  final Drama item;
  final bool editing, collect;
  final VoidCallback onOpen, onDelete;
  @override
  State<_DramaRow> createState() => _DramaRowState();
}

class _DramaRowState extends State<_DramaRow> {
  double offset = 0;
  bool dragging = false;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: 192,
      child: Stack(
        children: [
          Positioned(
            top: 6,
            bottom: 6,
            right: 5,
            width: 74,
            child: Pressable(
              label: '删除 ${widget.item.title}',
              onTap: widget.onDelete,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xffff6267),
                      Color(0xffe42f3a),
                      Color(0xffc51928),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline, size: 21),
                    const SizedBox(height: 5),
                    Text(tr(context, 'Delete'), style: type(10, weight: 600)),
                  ],
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: dragging
                ? Duration.zero
                : const Duration(milliseconds: 540),
            curve: arrive,
            transform: Matrix4.translationValues(offset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: widget.editing
                  ? null
                  : (details) => setState(() {
                      dragging = true;
                      offset = (offset + details.delta.dx).clamp(-96, 8);
                    }),
              onHorizontalDragEnd: widget.editing
                  ? null
                  : (_) => setState(() {
                      dragging = false;
                      offset = offset < -34 ? -84 : 0;
                    }),
              child: ColoredBox(
                color: const Color(0xff111111),
                child: Pressable(
                  onTap: () {
                    if (offset != 0) {
                      setState(() => offset = 0);
                    } else {
                      widget.onOpen();
                    }
                  },
                  label: '打开 ${widget.item.title}',
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(13),
                              bottom: Radius.circular(22),
                            ),
                            child: Art(
                              widget.item.image,
                              width: 128,
                              height: 192,
                            ),
                          ),
                          const SizedBox(width: 19),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: widget.editing ? 32 : 0,
                              ),
                              child: _copy(),
                            ),
                          ),
                        ],
                      ),
                      if (widget.editing)
                        Positioned(
                          right: 2,
                          top: 79,
                          child: Pressable(
                            label: '移除 ${widget.item.title}',
                            onTap: widget.onDelete,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xdb2f0c0e),
                                border: Border.all(
                                  color: const Color(0x8cff5a5b),
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Color(0xffff5a5f),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _copy() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        widget.item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: type(18, weight: 500, spacing: -.45, height: 1.18),
      ),
      const SizedBox(height: 7),
      Text(
        widget.item.genre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: type(
          12,
          weight: 430,
          color: const Color(0x80e5e5e8),
          height: 1.2,
        ),
      ),
      if (!widget.collect) ...[
        const SizedBox(height: 14),
        Text(
          '78% · Episode 1',
          style: type(12, weight: 450, color: const Color(0xe6f6f6f7)),
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: .78),
            duration: const Duration(milliseconds: 960),
            curve: arrive,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              color: Colors.white,
              backgroundColor: const Color(0x2bffffff),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Last Viewed 2 Days Ago',
          style: type(
            12,
            weight: 430,
            height: 1.2,
            color: const Color(0x80e5e5e8),
          ),
        ),
      ] else ...[
        const SizedBox(height: 11),
        Text(
          widget.item.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: type(
            11.5,
            weight: 410,
            height: 1.42,
            color: const Color(0x94e0e0e3),
          ),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 22,
          runSpacing: 6,
          children: [
            _metric('detail-heart', widget.item.favorites),
            _metric('detail-star', widget.item.readers),
          ],
        ),
      ],
    ],
  );
  Widget _metric(String icon, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Glyph(icon, size: 15),
      const SizedBox(width: 6),
      Text(value, style: type(12, weight: 520, color: const Color(0xc7f4f4f6))),
    ],
  );
}
