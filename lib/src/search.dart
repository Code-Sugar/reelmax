import 'package:flutter/material.dart';
import 'design.dart';
import 'data.dart';
import 'localization.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.openDetail,
    this.showBack = false,
  });
  final ValueChanged<DramaInfo> openDetail;
  final bool showBack;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final query = TextEditingController();
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchDramas
        .where(
          (drama) =>
              drama.title.toLowerCase().contains(query.text.toLowerCase()),
        )
        .toList();
    return ColoredBox(
      color: canvasColor,
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyHeader(
              height: pageTop(context) + 206 + (widget.showBack ? 25 : 0),
              color: const Color(0xbb101012),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, pageTop(context), 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr(context, 'DISCOVER'),
                          style: type(
                            11,
                            weight: 720,
                            spacing: 1.1,
                            color: const Color(0xff8d8d97),
                          ),
                        ),
                        if (widget.showBack)
                          CircleControl(
                            label: tr(context, 'Back', '返回'),
                            size: 36,
                            onTap: () => Navigator.of(context).pop(),
                            child: const Glyph('detail-back', size: 22),
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      tr(context, 'Search'),
                      style: type(
                        42,
                        weight: 900,
                        volume: 24,
                        spacing: -1.47,
                        height: .94,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr(context, 'Find your next favorite.'),
                      style: type(
                        15,
                        weight: 430,
                        height: 1.35,
                        spacing: -.15,
                        color: const Color(0xffa1a1aa),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      decoration: BoxDecoration(
                        color: const Color(0xff1c1c1f),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: Color(0xff8e8e97),
                            size: 21,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: TextField(
                              key: const ValueKey('search-input'),
                              controller: query,
                              onChanged: (_) => setState(() {}),
                              style: type(16, weight: 500, spacing: -.24),
                              cursorColor: Colors.white,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: tr(context, 'Movies, Series, Genres'),
                                hintStyle: type(
                                  16,
                                  weight: 500,
                                  color: const Color(0xff85858c),
                                ),
                              ),
                            ),
                          ),
                          if (query.text.isNotEmpty)
                            Pressable(
                              label: '清空搜索',
                              onTap: () {
                                query.clear();
                                setState(() {});
                              },
                              child: const CircleAvatar(
                                radius: 9,
                                backgroundColor: Color(0xff8e8e93),
                                child: Icon(
                                  Icons.close,
                                  size: 13,
                                  color: Color(0xff1c1c1e),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 122),
            sliver: SliverList.list(
              children: [
                Text(
                  query.text.isEmpty
                      ? tr(context, 'Trending')
                      : '“${query.text}” 的结果',
                  style: type(21, weight: 700, spacing: -.525, height: 1.5),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < results.length; i++)
                  Pressable(
                    label: '打开 ${results[i].title}',
                    onTap: () => widget.openDetail(results[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 15,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x1affffff)),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 25,
                            child: Text(
                              '${i + 1}',
                              style: type(
                                16,
                                height: 1.5,
                                color: const Color(0xff77777e),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              results[i].title,
                              style: type(16, weight: 700, height: 1.5),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Color(0xff666666),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
