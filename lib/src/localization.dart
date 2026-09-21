import 'package:flutter/widgets.dart';
import 'account_state.dart';

String tr(BuildContext context, String english, [String? chinese]) =>
    AccountScope.maybeOf(context)?.chinese == true
    ? chinese ?? _chinese[english] ?? english
    : english;

const _chinese = {
  'Today': '今日',
  'Profile': '我的',
  'Search': '搜索',
  'List': '片单',
  'list': '片单',
  'New': '最新',
  'Top': '热门',
  'Exclusive': '独家',
  'Play': '播放',
  'Next': '下一部',
  'History': '历史记录',
  'Collect': '收藏',
  'Saved': '已收藏',
  'Edit': '编辑',
  'Done': '完成',
  'Delete': '删除',
  'All': '全部',
  'Fantasy': '奇幻',
  'Action': '动作',
  'Romance': '爱情',
  'Sci-Fi': '科幻',
  'Explore Genres': '探索分类',
  'Hot New': '热门新剧',
  'Popular Tpday': '今日热播',
  'Today In Cinemas': '今日影院',
  'DISCOVER': '发现',
  'Find your next favorite.': '发现下一部心仪好剧。',
  'Movies, Series, Genres': '电影、剧集、类型',
  'Trending': '热门搜索',
  'Watch Trailer': '观看预告',
  'More': '展开',
  'Less': '收起',
  'Cast': '演员',
  'Episodes': '剧集',
  'You Might Like': '猜你喜欢',
  '3 available': '可观看 3 集',
  'Quality': '清晰度',
  'Choose your video quality': '选择视频清晰度',
  '20 episodes · 5 available': '共 20 集 · 可观看 5 集',
  'Episodes 06–20 are locked': '第 6–20 集尚未解锁',
};
