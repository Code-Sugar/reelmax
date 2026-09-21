import 'package:flutter/material.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'api.dart';
import 'design.dart';
import 'live_catalog.dart';
import 'localization.dart';

class LiveBubbles extends StatefulWidget {
  const LiveBubbles({
    super.key,
    required this.skitId,
    required this.dramaId,
    required this.seconds,
  });
  final int skitId, dramaId, seconds;
  @override
  State<LiveBubbles> createState() => _LiveBubblesState();
}

class _LiveBubblesState extends State<LiveBubbles> {
  final content = TextEditingController();
  bool busy = false;
  int tab = 0;
  String? error;
  Future<void> send(VoidCallback refresh) async {
    if (busy || content.text.trim().isEmpty || !await requireAccount(context)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AccountScope.of(context).api!.post('skit/bubble/send', {
        'skitId': widget.skitId,
        'dramaId': widget.dramaId,
        'content': content.text.trim(),
        'videoTime': widget.seconds,
      });
      if (mounted) {
        content.clear();
        refresh();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ApiView(
    key: ValueKey(tab),
    load: (api) =>
        api.get(tab == 0 ? 'skit/bubble/listAll' : 'skit/bubble/list', {
          'skitId': widget.skitId,
          'dramaId': widget.dramaId,
          if (tab == 1) 'startSec': widget.seconds,
          if (tab == 1) 'endSec': widget.seconds + 30,
        }),
    builder: (data, refresh) => AccountFrame(
      title: tr(context, 'Comments', '弹幕'),
      children: [
        AccountSegments(
          labels: [
            tr(context, 'All', '全部'),
            tr(context, 'This moment', '当前时间'),
          ],
          selected: tab,
          onChanged: (v) => setState(() => tab = v),
        ),
        const SizedBox(height: 16),
        for (final row in objects(data))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AccountCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(string(row['content']), style: type(14, height: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                    '${row['videoTime'] ?? 0}s',
                    style: type(11, color: accountMuted),
                  ),
                ],
              ),
            ),
          ),
        if (objects(data).isEmpty)
          ApiProblem(tr(context, 'No comments yet.', '暂无弹幕。')),
        TextField(
          controller: content,
          enabled: !busy,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: tr(
              context,
              'Comment at ${widget.seconds}s',
              '在 ${widget.seconds} 秒发送弹幕',
            ),
          ),
        ),
        if (error != null) ApiProblem(error!),
        AccountButton(
          text: tr(context, 'Send', '发送'),
          onTap: busy ? null : () => send(refresh),
          busy: busy,
        ),
      ],
    ),
  );
}
