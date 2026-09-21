import 'dart:async';
import 'package:flutter/material.dart';
import 'account_state.dart';
import 'api.dart';
import 'category.dart';
import 'data.dart';
import 'design.dart';
import 'detail.dart' show reelRoute;
import 'live_catalog.dart' show remoteDrama, ApiProblem;
import 'live_player.dart';
import 'localization.dart';

class LiveCategory extends StatefulWidget {
  const LiveCategory({super.key, required this.openDetail});
  final ValueChanged<DramaInfo> openDetail;
  @override
  State<LiveCategory> createState() => _LiveCategoryState();
}

class _LiveCategoryState extends State<LiveCategory> {
  List<Json> groups = [];
  String? selected;
  String? identity;
  String? failure;
  bool loading = false;
  int request = 0;
  late AccountStore account;
  String groupKey(Json group) => '${group['id'] ?? group['title']}';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    account = AccountScope.of(context);
    final next = '${account.api!.token}:${account.api!.language}';
    if (identity != next) {
      identity = next;
      groups = [];
      selected = null;
      unawaited(load());
    }
    final scope = account.historyScope;
    if (scope != null) unawaited(account.watchHistory.load(scope));
  }

  Future<void> load({bool fresh = false}) async {
    final version = ++request;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final api = account.api!;
      final query = {'language': 'en', 'device': 'apple'};
      // The documented init endpoint returns all title/module groups together.
      final result = fresh
          ? await api.get('skit/init', query)
          : await api.cachedGet('skit/init', query);
      if (!mounted || version != request) return;
      final incoming = objects(object(result)['init']);
      setState(() {
        groups = incoming;
        if (!groups.any((g) => groupKey(g) == selected)) {
          selected = groups.isEmpty ? null : groupKey(groups.first);
        }
      });
    } catch (e) {
      if (mounted && version == request) setState(() => failure = '$e');
    } finally {
      if (mounted && version == request) setState(() => loading = false);
    }
  }

  Future<void> openHistory(Json row) async {
    await Navigator.of(context).push(
      reelRoute(
        LivePlayer(
          skit: DramaInfo(
            serverId: integer(row['skitId']),
            title: string(row['skitName']),
            image: string(row['cover']),
          ),
          initialDramaId: integer(row['dramaId']),
          initialPosition: row['completed'] == true
              ? Duration.zero
              : Duration(milliseconds: integer(row['positionMs'])),
        ),
        player: true,
      ),
    );
    if (mounted) setState(() {});
  }

  Widget heading(String title, {VoidCallback? more}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: type(20, weight: 730, spacing: -.5)),
        ),
        if (more != null)
          CircleControl(
            label: 'More $title',
            size: 37,
            onTap: more,
            child: const Icon(Icons.chevron_right, size: 19),
          ),
      ],
    ),
  );

  Widget poster(Json row, {bool caption = true, bool history = false}) {
    final drama = history
        ? DramaInfo(
            serverId: integer(row['skitId']),
            title: string(row['skitName']),
            image: string(row['cover']),
          )
        : remoteDrama(row);
    final duration = integer(row['durationMs']);
    final position = integer(row['positionMs']);
    return Pressable(
      key: history
          ? ValueKey('history-${row['skitId']}-${row['dramaId']}')
          : null,
      label: drama.title,
      onTap: () => history ? openHistory(row) : widget.openDetail(drama),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption)
            AspectRatio(
              aspectRatio: 104 / (history ? 151 : 152),
              child: cover(
                row,
                history: history,
                duration: duration,
                position: position,
              ),
            )
          else
            Expanded(
              child: cover(
                row,
                history: history,
                duration: duration,
                position: position,
              ),
            ),
          if (caption) ...[
            const SizedBox(height: 4),
            Text(
              drama.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type(12, weight: 520, height: 1.05, spacing: -.18),
            ),
            const SizedBox(height: 2),
            Text(
              history ? string(row['episodeTitle']) : drama.genre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type(10, height: 1.2, color: const Color(0x87e6e6e8)),
            ),
            if (history) ...[
              const SizedBox(height: 2),
              Text(
                '${clock(position)} / ${clock(duration)}',
                style: type(10, height: 1.2, color: const Color(0x87e6e6e8)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget cover(
    Json row, {
    required bool history,
    required int duration,
    required int position,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      Art(string(row['cover']), radius: 10),
      if (history)
        Center(
          child: Glass(
            width: 34,
            height: 34,
            radius: 99,
            child: const Icon(Icons.play_arrow_rounded, size: 23),
          ),
        ),
      if (history)
        Positioned(
          left: 6,
          right: 6,
          bottom: 7,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: duration <= 0 ? 0 : (position / duration).clamp(0, 1),
              minHeight: 4,
              color: Colors.white,
              backgroundColor: const Color(0x44ffffff),
            ),
          ),
        ),
    ],
  );

  String clock(int ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget horizontal(
    List<Json> rows, {
    bool history = false,
    bool large = false,
  }) => LayoutBuilder(
    builder: (_, constraints) {
      final width = large
          ? (constraints.maxWidth + 20) * .69014
          : (constraints.maxWidth - 24) / 3;
      return SizedBox(
        height: large
            ? width * 331 / 245
            : width * (history ? 151 : 152) / 104 + (history ? 47 : 31),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            width: width,
            child: poster(rows[i], history: history, caption: !large),
          ),
        ),
      );
    },
  );

  void more(Json module, List<Json> rows) {
    Navigator.of(context).push(
      reelRoute(
        Scaffold(
          backgroundColor: const Color(0xff111613),
          appBar: AppBar(
            title: Text(string(module['title'])),
            backgroundColor: const Color(0xff111613),
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: .57,
            ),
            itemBuilder: (_, i) => poster(rows[i]),
          ),
        ),
      ),
    );
  }

  Widget module(Json module) {
    final rows = objects(
      module['skits'],
    ).where((r) => integer(r['id']) > 0).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final style = integer(module['style']);
    Widget body;
    switch (style) {
      case 1:
        body = LayoutBuilder(
          builder: (_, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: width * (150 / 335 + .203),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: width * 150 / 335,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ColoredBox(
                        color: const Color(0xff020302),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 1,
                              right: -42,
                              child: Text(
                                'Reel',
                                style: type(
                                  108,
                                  weight: 900,
                                  slant: -10,
                                  spacing: -14.04,
                                  height: .9,
                                  color: const Color(0xc71b2809),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 15,
                              left: 15,
                              right: 15,
                              child: Text(
                                string(module['subtitle']).isEmpty
                                    ? string(module['title'])
                                    : string(module['subtitle']),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: type(
                                  14,
                                  weight: 540,
                                  height: 1.16,
                                  spacing: -.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * .0716,
                    right: width * .0687,
                    bottom: width * .203 - width * 150 / 335 * .3467,
                    height:
                        (width * (1 - .0716 - .0687 - 2 * .0269) / 3) *
                        132 /
                        89,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(width: width * .0269),
                      itemBuilder: (_, i) => SizedBox(
                        width: width * (1 - .0716 - .0687 - 2 * .0269) / 3,
                        child: poster(rows[i], caption: false),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      case 2:
        body = LayoutBuilder(
          builder: (_, constraints) => SizedBox(
            height: constraints.maxWidth * 246 / 335,
            child: Row(
              children: [
                Expanded(flex: 124, child: poster(rows.first, caption: false)),
                if (rows.length > 1) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 100,
                    child: Column(
                      children: [
                        Expanded(child: poster(rows[1], caption: false)),
                        if (rows.length > 2) ...[
                          const SizedBox(height: 11),
                          Expanded(child: poster(rows[2], caption: false)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case 4:
        body = horizontal(rows, large: true);
      case 5:
        body = Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Pressable(
                  label: string(row['name']),
                  onTap: () => widget.openDetail(remoteDrama(row)),
                  child: AspectRatio(
                    aspectRatio: 335 / 128,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Art(string(row['cover']), radius: 20),
                        Positioned(
                          left: 15,
                          right: 15,
                          bottom: 15,
                          child: Text(
                            string(row['name']),
                            maxLines: 2,
                            style: type(22, weight: 750),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      default:
        body = horizontal(rows);
    }
    return Padding(
      key: ValueKey('module-${module['id']}-style-$style'),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (style != 1)
            heading(
              string(module['title']),
              more: integer(module['more']) == 1
                  ? () => more(module, rows)
                  : null,
            ),
          body,
          if (style == 1 && integer(module['more']) == 1)
            Pressable(
              label: 'More ${module['title']}',
              onTap: () => more(module, rows),
              child: Glass(
                height: 42,
                radius: 9,
                borderOpacity: .38,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, "See More Content You're Interested In"),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type(12, weight: 440),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = groups
        .where((g) => groupKey(g) == selected)
        .firstOrNull;
    final modules = objects(selectedGroup?['module'])
      ..sort((a, b) => integer(a['order']).compareTo(integer(b['order'])));
    return RefreshIndicator(
      onRefresh: () => load(fresh: true),
      child: CategoryPage(
        openDetail: widget.openDetail,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(tr(context, 'History')),
            AnimatedBuilder(
              animation: account.watchHistory,
              builder: (_, _) {
                final rows = account.historyScope == null
                    ? <Json>[]
                    : account.watchHistory.rows(account.historyScope!);
                return rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          tr(context, 'No watch history yet.', '暂无观看记录'),
                          style: type(13, color: const Color(0x99ebebed)),
                        ),
                      )
                    : horizontal(rows, history: true);
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x1cffffff)),
                gradient: const LinearGradient(
                  colors: [
                    Color(0x0effffff),
                    Color(0x050fffff),
                    Color(0x380e1413),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Explore Genres'),
                    style: type(
                      13,
                      weight: 650,
                      color: const Color(0x99ebebed),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 29,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final group = groups[i];
                        final key = groupKey(group);
                        return Pressable(
                          label: string(group['title']),
                          selected: selected == key,
                          onTap: () {
                            setState(() => selected = key);
                            unawaited(load(fresh: true));
                          },
                          child: AnimatedContainer(
                            duration: motion,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: BoxDecoration(
                              color: selected == key
                                  ? Colors.white
                                  : const Color(0x17ffffff),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Center(
                              child: Text(
                                string(group['title']),
                                style: type(
                                  12,
                                  color: selected == key
                                      ? const Color(0xff1f2021)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (failure != null)
              ApiProblem(failure!, retry: () => load(fresh: true)),
            if (!loading && failure == null && modules.isEmpty)
              Text(tr(context, 'No content yet.', '暂无内容'), style: type(13)),
            for (final entry in modules) module(entry),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
