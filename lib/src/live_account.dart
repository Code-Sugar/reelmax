import 'package:flutter/material.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'api.dart';
import 'design.dart';
import 'detail.dart';
import 'live_catalog.dart';
import 'live_store.dart';
import 'localization.dart';

class LiveAccountSettings extends StatefulWidget {
  const LiveAccountSettings({super.key});
  @override
  State<LiveAccountSettings> createState() => _LiveAccountSettingsState();
}

class _LiveAccountSettingsState extends State<LiveAccountSettings> {
  final email = TextEditingController(), code = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> submit(bool send) async {
    if (busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(
        () => error = tr(context, 'Enter a valid email address.', '请输入有效邮箱。'),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final store = AccountScope.of(context);
      if (send) {
        await store.sendCode(email.text);
      } else {
        if (code.text.trim().isEmpty) throw const ApiException('请输入验证码。');
        await store.api!.post('user/bindEmail', {
          'email': email.text.trim(),
          'code': code.text.trim(),
        });
        await store.refreshProfile();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    final store = AccountScope.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, 'Delete account?', '删除账号？')),
        content: Text(
          tr(
            context,
            'This permanently deletes your account. This action cannot be undone.',
            '此操作会永久删除账号，无法撤销。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Keep account', '保留账号')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Delete account', '删除账号')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await store.api!.post('user/deleteAccount');
      await store.signOut();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountFrame(
    title: tr(context, 'Account settings', '账号设置'),
    children: [
      Text(tr(context, 'Bind email', '绑定邮箱'), style: type(22, weight: 650)),
      const SizedBox(height: 18),
      TextField(
        controller: email,
        readOnly: busy,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: tr(context, 'Email address', '邮箱地址'),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: code,
        readOnly: busy,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: tr(context, 'Verification code', '验证码'),
        ),
      ),
      TextButton(
        onPressed: busy ? null : () => submit(true),
        child: Text(tr(context, 'Send code', '发送验证码')),
      ),
      if (error != null) ApiProblem(error!),
      AccountButton(
        text: tr(context, 'Save', '保存'),
        busy: busy,
        onTap: busy ? null : () => submit(false),
      ),
      const SizedBox(height: 40),
      TextButton(
        onPressed: busy ? null : delete,
        child: Text(
          tr(context, 'Delete account', '删除账号'),
          style: type(13, color: const Color(0xffff8888)),
        ),
      ),
    ],
  );
}

class LiveSubscriptions extends StatefulWidget {
  const LiveSubscriptions({super.key});
  @override
  State<LiveSubscriptions> createState() => _LiveSubscriptionsState();
}

class _LiveSubscriptionsState extends State<LiveSubscriptions> {
  bool busy = false;
  String? error;
  Future<void> cancel(Json subscription, VoidCallback refresh) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, 'Cancel renewal?', '取消自动续订？')),
        content: Text(string(subscription['name'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Keep subscription', '保留订阅')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Cancel renewal', '取消续订')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AccountScope.of(context).api!.post('payment/subscription/cancel');
      if (mounted) refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiView(
    load: (api) => api.get('payment/subscription/list'),
    builder: (value, refresh) {
      final d = object(value);
      final subscriptions = [
        ...objects(d['active']),
        ...objects(d['inactive']),
      ];
      return AccountFrame(
        title: tr(context, 'My subscriptions', '我的订阅'),
        children: [
          if (error != null) ApiProblem(error!),
          for (final sub in subscriptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: AccountCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(string(sub['name']), style: type(22, weight: 600)),
                    const SizedBox(height: 12),
                    Text(
                      string(sub['description']),
                      style: type(14, color: accountMuted),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${tr(context, 'Expires', '到期时间')}: ${sub['expirationDate'] ?? '—'}',
                      style: type(12, color: accountMuted),
                    ),
                    if (integer(sub['canCancel']) == 1)
                      TextButton(
                        onPressed: busy ? null : () => cancel(sub, refresh),
                        child: Text(tr(context, 'Cancel renewal', '取消续订')),
                      ),
                    if (integer(sub['canRefund']) == 1)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context)
                                  .push(
                                    reelRoute(
                                      LiveFeedback(
                                        kind: 'refund',
                                        orderId: string(sub['orderId']),
                                      ),
                                    ),
                                  )
                                  .then((_) {
                                    if (mounted) refresh();
                                  }),
                        child: Text(tr(context, 'Request refund', '申请退款')),
                      ),
                  ],
                ),
              ),
            ),
          if (subscriptions.isEmpty)
            ApiProblem(tr(context, 'No subscriptions yet.', '暂无订阅。')),
          TextButton(
            onPressed: () =>
                Navigator.of(context).push(reelRoute(const LivePlanChanges())),
            child: Text(tr(context, 'Available plan changes', '可更换的套餐')),
          ),
        ],
      );
    },
  );
}

class LivePlanChanges extends StatelessWidget {
  const LivePlanChanges({super.key});
  @override
  Widget build(BuildContext context) => ApiView(
    load: (api) => api.get('payment/subscription/plan/change/list'),
    builder: (value, refresh) => AccountFrame(
      title: tr(context, 'Available plans', '可更换的套餐'),
      children: [
        for (final plan in objects(value))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AccountCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(string(plan['name']), style: type(20, weight: 600)),
                  const SizedBox(height: 12),
                  Text(price(plan), style: type(16)),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(reelRoute(LiveCheckout(offer: plan, coins: false))),
                    child: Text(tr(context, 'Continue', '继续')),
                  ),
                ],
              ),
            ),
          ),
        if (objects(value).isEmpty)
          ApiProblem(
            tr(context, 'No plan changes available.', '暂无可更换的套餐。'),
            retry: refresh,
          ),
      ],
    ),
  );
}

class LiveFeedback extends StatefulWidget {
  const LiveFeedback({
    super.key,
    this.kind = 'feedback',
    this.skitId,
    this.dramaId,
    this.orderId,
  });
  final String kind;
  final int? skitId, dramaId;
  final String? orderId;
  @override
  State<LiveFeedback> createState() => _LiveFeedbackState();
}

class _LiveFeedbackState extends State<LiveFeedback> {
  final content = TextEditingController(), contact = TextEditingController();
  bool busy = false, sent = false;
  String? error;
  Future<void> submit() async {
    if (busy || sent) return;
    if (content.text.trim().isEmpty) {
      setState(
        () => error = tr(context, 'Please describe the issue.', '请填写具体说明。'),
      );
      return;
    }
    if (!await requireAccount(context) || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AccountScope.of(context).api!.post(
        switch (widget.kind) {
          'refund' => 'payment/subscription/refund/apply',
          'report' => 'user/feedback/report/drama',
          _ => 'user/feedback/submit',
        },
        widget.kind == 'refund'
            ? {'orderId': widget.orderId, 'reason': content.text.trim()}
            : {
                if (widget.kind == 'feedback') 'feedbackType': 1,
                if (widget.kind == 'report') 'reason': content.text.trim(),
                if (widget.skitId != null) 'skitId': widget.skitId,
                if (widget.dramaId != null) 'dramaId': widget.dramaId,
                'content': content.text.trim(),
                'contact': contact.text.trim(),
                'images': '',
              },
      );
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    content.dispose();
    contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountFrame(
    title: tr(
      context,
      widget.kind == 'refund'
          ? 'Request refund'
          : widget.kind == 'report'
          ? 'Report episode'
          : 'Help & feedback',
      widget.kind == 'refund'
          ? '申请退款'
          : widget.kind == 'report'
          ? '举报剧集'
          : '帮助与反馈',
    ),
    children: [
      if (sent) ...[
        const Icon(Icons.check_circle_outline, size: 44, color: accountMint),
        const SizedBox(height: 18),
        Text(
          tr(
            context,
            'Submitted. Your request will be reviewed.',
            '已提交，请等待处理。',
          ),
          textAlign: TextAlign.center,
          style: type(17),
        ),
      ] else ...[
        TextField(
          controller: content,
          readOnly: busy,
          minLines: 5,
          maxLines: 8,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: tr(context, 'Details', '具体说明'),
          ),
        ),
        if (widget.kind != 'refund')
          TextField(
            controller: contact,
            readOnly: busy,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: tr(context, 'Contact email (optional)', '联系邮箱（选填）'),
            ),
          ),
        if (error != null) ApiProblem(error!),
        const SizedBox(height: 24),
        AccountButton(
          text: tr(context, 'Submit', '提交'),
          onTap: busy ? null : submit,
          busy: busy,
        ),
      ],
    ],
  );
}
