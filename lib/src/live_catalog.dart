import 'dart:async';
import 'package:flutter/material.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'api.dart';
import 'auth.dart';
import 'data.dart';
import 'design.dart';
import 'detail.dart';
import 'home.dart';
import 'localization.dart';
import 'live_player.dart';
import 'category.dart';

DramaInfo remoteDrama(Json d) => DramaInfo(
  serverId: integer(d['id']),
  title: string(d['name']),
  image: string(d['cover']),
  description: string(d['workIntroduction']),
  preview: string(d['previewVideo']),
  genre: objects(d['genres']).map((g) => string(g['genre'])).join(' · '),
);

class ApiView extends StatefulWidget {
  const ApiView({
    super.key,
    required this.load,
    required this.builder,
    this.placeholder,
  });
  final Widget? placeholder;
  final Future<dynamic> Function(SkitApi api) load;
  final Widget Function(dynamic value, VoidCallback refresh) builder;
  @override
  State<ApiView> createState() => _ApiViewState();
}

class _ApiViewState extends State<ApiView> {
  Future<dynamic>? pending;
  String? identity;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = AccountScope.of(context).api!;
    final next = '${api.token}:${api.language}:${api.catalogRevision}';
    if (pending == null || identity != next) {
      identity = next;
      pending = widget.load(api);
    }
  }

  @override
  void didUpdateWidget(covariant ApiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final api = AccountScope.of(context).api!;
    final next = '${api.token}:${api.language}:${api.catalogRevision}';
    if (identity != next) {
      identity = next;
      pending = widget.load(api);
    }
  }

  void refresh() =>
      setState(() => pending = widget.load(AccountScope.of(context).api!));
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: pending,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return snapshot.hasData
            ? widget.builder(snapshot.data, refresh)
            : widget.placeholder ??
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
      }
      if (snapshot.hasError) {
        return widget.placeholder ??
            ApiProblem('${snapshot.error}', retry: refresh);
      }
      return widget.builder(snapshot.data, refresh);
    },
  );
}

class ApiProblem extends StatelessWidget {
  const ApiProblem(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: type(13, color: accountMuted, height: 1.5),
          ),
          if (retry != null)
            TextButton(
              onPressed: retry,
              child: Text(tr(context, 'Retry', '重试')),
            ),
        ],
      ),
    ),
  );
}

Future<bool> requireAccount(BuildContext context) async {
  final store = AccountScope.of(context);
  await store.initialize();
  if (!context.mounted) return false;
  if (!store.signedIn) {
    await Navigator.of(context).push(reelRoute(const AuthPage()));
  }
  return context.mounted && store.signedIn;
}

class LiveHome extends StatefulWidget {
  const LiveHome({
    super.key,
    required this.active,
    required this.openDetail,
    required this.openSearch,
  });
  final bool active;
  final ValueChanged<DramaInfo> openDetail;
  final VoidCallback openSearch;
  @override
  State<LiveHome> createState() => _LiveHomeState();
}

class _LiveHomeState extends State<LiveHome> {
  String filter = 'New';
  @override
  Widget build(BuildContext context) => ApiView(
    load: (api) => api.cachedGet('skit/show'),
    builder: (data, refresh) {
      final tabs = objects(object(data)['tabs']);
      final tab = tabs.where((v) => v['tabName'] == filter).firstOrNull;
      final entries = objects(
        tab?['dramas'],
      ).where((v) => integer(v['skitId']) > 0).toList();
      if (entries.isEmpty) {
        return AccountFrame(
          title: 'Reel Max',
          back: false,
          tabPage: true,
          children: [
            AccountSegments(
              labels: const ['New', 'Top', 'Exclusive'],
              selected: ['New', 'Top', 'Exclusive'].indexOf(filter),
              onChanged: (i) =>
                  setState(() => filter = ['New', 'Top', 'Exclusive'][i]),
            ),
            ApiProblem(
              tr(context, 'No videos available yet.', '暂无可播放内容。'),
              retry: refresh,
            ),
          ],
        );
      }
      return HomePage(
        key: ValueKey(filter),
        active: widget.active,
        openDetail: widget.openDetail,
        openSearch: widget.openSearch,
        selectedFilter: filter,
        onFilter: (v) => setState(() => filter = v),
        items: entries
            .map(
              (d) => Feature(
                string(d['skitName']),
                objects(
                  d['skitGenres'],
                ).map((e) => string(e['genre'])).join(' · '),
                '',
                string(d['skitDescription']),
                string(d['cover']),
                string(d['dramaSerie']),
                serverId: integer(d['skitId']),
              ),
            )
            .toList(),
      );
    },
  );
}

class LiveCategory extends StatelessWidget {
  const LiveCategory({super.key, required this.openDetail});
  final ValueChanged<DramaInfo> openDetail;
  @override
  Widget build(BuildContext context) => ApiView(
    placeholder: CategoryPage(openDetail: openDetail),
    load: (api) => api.cachedGet('skit/init', {
      'language': api.language,
      'device': api.platform,
    }),
    builder: (value, refresh) {
      final sections = <String, List<DramaInfo>>{};
      // Match named sections only: an unrelated module must never replace a
      // designed section just because it has the same position in the response.
      for (final group in objects(object(value)['init'])) {
        for (final module in objects(group['module'])) {
          final title = string(module['title']).trim().toLowerCase();
          final rows = objects(
            module['skits'],
          ).where((d) => integer(d['id']) > 0).map(remoteDrama).toList();
          if (rows.isNotEmpty) sections[title] = rows;
        }
      }
      return CategoryPage(openDetail: openDetail, sections: sections);
    },
  );
}

class LiveListPage extends StatefulWidget {
  const LiveListPage({
    super.key,
    required this.title,
    required this.path,
    required this.openDetail,
    this.query = const {},
    this.search = false,
    this.library = false,
  });
  final String title, path;
  final Json query;
  final bool search, library;
  final ValueChanged<DramaInfo> openDetail;
  @override
  State<LiveListPage> createState() => _LiveListPageState();
}

class _LiveListPageState extends State<LiveListPage> {
  final input = TextEditingController();
  Timer? debounce;
  int page = 0, generation = 0, tab = 0;
  bool busy = false, more = true;
  String? error, identity;
  final entries = <Json>[];
  final selected = <int>{};
  String get path => widget.library
      ? (tab == 0 ? 'skit/myCollectList' : 'skit/myLikeList')
      : widget.path;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = AccountScope.of(context).api!;
    final next = '${api.token}:${api.language}:${api.catalogRevision}';
    if (identity != next) {
      identity = next;
      load(reset: true);
    }
  }

  @override
  void didUpdateWidget(covariant LiveListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final api = AccountScope.of(context).api!;
    final next = '${api.token}:${api.language}:${api.catalogRevision}';
    if (identity != next) {
      identity = next;
      load(reset: true);
    }
  }

  Future<void> load({bool reset = false}) async {
    if (busy && !reset) return;
    final attempt = ++generation;
    if (reset) {
      page = 0;
      entries.clear();
      selected.clear();
      more = true;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await AccountScope.of(context).api!.get(path, {
        ...widget.query,
        'page': page + 1,
        'pageSize': 20,
        if (widget.search) 'keyword': input.text.trim(),
      });
      if (!mounted || attempt != generation) return;
      final rows = objects(data);
      setState(() {
        entries.addAll(rows);
        page++;
        more = data is Map && data['pages'] != null
            ? page < integer(data['pages'])
            : rows.length >= 20;
      });
    } catch (e) {
      if (mounted && attempt == generation) setState(() => error = '$e');
    } finally {
      if (mounted && attempt == generation) setState(() => busy = false);
    }
  }

  Future<void> removeSelected() async {
    if (busy || selected.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Apply each documented set-status operation; no undocumented batch enum assumptions.
      for (final id in selected) {
        await AccountScope.of(context).api!.post(
          tab == 0 ? 'skit/collect' : 'skit/like',
          {'skitId': id, 'status': 0},
        );
      }
      if (mounted) await load(reset: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    return AccountFrame(
      title: widget.title,
      back: !widget.library,
      tabPage: widget.library,
      children: [
        if (widget.search)
          TextField(
            controller: input,
            decoration: InputDecoration(
              hintText: tr(context, 'Search titles', '搜索剧名'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 350),
                () => load(reset: true),
              );
            },
          ),
        if (widget.library) ...[
          AccountSegments(
            labels: [tr(context, 'Collect', '收藏'), tr(context, 'Liked', '喜欢')],
            selected: tab,
            onChanged: (i) {
              setState(() => tab = i);
              load(reset: true);
            },
          ),
          if (!store.signedIn)
            AccountButton(
              text: tr(context, 'Sign in', '登录'),
              onTap: () async {
                if (await requireAccount(context)) load(reset: true);
              },
            ),
          if (selected.isNotEmpty)
            TextButton(
              onPressed: busy ? null : removeSelected,
              child: Text(
                tr(
                  context,
                  'Remove selected (${selected.length})',
                  '移除已选（${selected.length}）',
                ),
              ),
            ),
        ],
        const SizedBox(height: 18),
        for (final entry in entries)
          Builder(
            builder: (context) {
              final d = remoteDrama(
                entry.containsKey('skit') ? object(entry['skit']) : entry,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Pressable(
                  onTap: () => widget.openDetail(d),
                  child: Row(
                    children: [
                      Art(d.image, width: 84, height: 116, radius: 12),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.title, style: type(17, weight: 600)),
                            const SizedBox(height: 8),
                            Text(d.genre, style: type(12, color: accountMuted)),
                            const SizedBox(height: 8),
                            Text(
                              d.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: type(11, color: accountMuted),
                            ),
                          ],
                        ),
                      ),
                      if (widget.library)
                        Checkbox(
                          value: selected.contains(d.serverId),
                          onChanged: busy
                              ? null
                              : (v) => setState(() {
                                  v == true
                                      ? selected.add(d.serverId!)
                                      : selected.remove(d.serverId);
                                }),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (error != null)
          ApiProblem(error!, retry: () => load(reset: page == 0)),
        if (busy)
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        if (!busy && error == null && entries.isEmpty)
          ApiProblem(tr(context, 'No results yet.', '暂无内容。')),
        if (!busy && more && entries.isNotEmpty)
          TextButton(
            onPressed: load,
            child: Text(tr(context, 'Load more', '加载更多')),
          ),
      ],
    );
  }
}

class LiveDetail extends StatefulWidget {
  const LiveDetail({super.key, required this.drama});
  final DramaInfo drama;
  @override
  State<LiveDetail> createState() => _LiveDetailState();
}

class _LiveDetailState extends State<LiveDetail> {
  @override
  Widget build(BuildContext context) => ApiView(
    placeholder: _page(context, const {}, () {}),
    load: (api) => api.cachedGet('skit/detail', {
      'id': widget.drama.serverId,
      'userId': AccountScope.of(context).user?.id ?? 0,
    }),
    builder: (value, refresh) => _page(context, object(value), refresh),
  );

  Widget _page(BuildContext context, Json data, VoidCallback refresh) {
    final original = widget.drama;
    String field(String key, String fallback) =>
        string(data[key]).isEmpty ? fallback : string(data[key]);
    final genres = objects(
      data['genres'],
    ).map((g) => string(g['genre'])).join(' · ');
    final drama = DramaInfo(
      serverId: original.serverId,
      title: field('name', original.title),
      image: field('cover', original.image),
      description: field('workIntroduction', original.description),
      genre: genres.isEmpty ? original.genre : genres,
      preview: field('previewVideo', original.preview),
      posterScale: original.posterScale,
    );
    return DetailPage(
      drama: drama,
      initialLiked: integer(data['isLiked']) == 1,
      likeCount: data['likeCount'] == null ? null : integer(data['likeCount']),
      score: string(data['score']).isEmpty ? null : string(data['score']),
      remoteEpisodes: objects(data['dramas']).isEmpty
          ? null
          : objects(data['dramas']),
      onLiked: (_) {},
      toggleLike: (value) async {
        if (!await requireAccount(context)) return false;
        if (!context.mounted) return false;
        await AccountScope.of(context).api!.post('skit/like', {
          'skitId': drama.serverId,
          'status': value ? 1 : 0,
        });
        return true;
      },
      playEpisode: (index) async {
        await Navigator.of(context).push(
          reelRoute(LivePlayer(skit: drama, initialIndex: index), player: true),
        );
        if (mounted) refresh();
      },
    );
  }
}
