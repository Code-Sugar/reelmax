import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'api.dart';
import 'design.dart';
import 'detail.dart';
import 'live_catalog.dart';
import 'localization.dart';

class LiveStorePage extends StatefulWidget {
  const LiveStorePage({super.key, this.coins = false});
  final bool coins;
  @override
  State<LiveStorePage> createState() => _LiveStorePageState();
}

class _LiveStorePageState extends State<LiveStorePage> {
  late int tab = widget.coins ? 1 : 0;
  int selected = 0;
  @override
  Widget build(BuildContext context) => ApiView(
    key: ValueKey(tab),
    load: (api) => api.get(
      tab == 0 ? 'payment/subscription/price/list' : 'payment/coin/price/list',
    ),
    builder: (data, refresh) {
      final offers = objects(
        data,
      ).where((e) => e['status'] == null || integer(e['status']) == 1).toList();
      final offer = offers.isEmpty
          ? null
          : offers[selected.clamp(0, offers.length - 1)];
      return AccountFrame(
        title: tr(context, 'Membership & coins', '会员与金币'),
        footer: offer == null
            ? null
            : AccountButton(
                text: tr(
                  context,
                  'Continue · ${price(offer)}',
                  '继续 · ${price(offer)}',
                ),
                onTap: () async {
                  if (!await requireAccount(context) || !context.mounted) {
                    return;
                  }
                  Navigator.of(context).push(
                    reelRoute(LiveCheckout(offer: offer, coins: tab == 1)),
                  );
                },
              ),
        children: [
          AccountSegments(
            labels: [
              tr(context, 'Membership', '会员'),
              tr(context, 'Coins', '金币'),
            ],
            selected: tab,
            onChanged: (value) => setState(() {
              tab = value;
              selected = 0;
            }),
          ),
          const SizedBox(height: 24),
          if (tab == 0)
            CinemaBanner(
              height: 190,
              title: tr(context, 'Stay for the\nwhole story.', '好故事，\n一集也不错过。'),
            ),
          if (tab == 1)
            Center(
              child: Column(
                children: [
                  Text(
                    tr(context, 'Available balance', '可用金币'),
                    style: type(12, color: accountMuted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${AccountScope.of(context).user?.balance ?? 0}',
                    style: type(44, weight: 650),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          for (var i = 0; i < offers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Pressable(
                onTap: () => setState(() => selected = i),
                child: AccountCard(
                  child: Row(
                    children: [
                      Icon(
                        i == selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: i == selected ? accountMint : accountMuted,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tab == 0
                                  ? string(offers[i]['name'])
                                  : tr(
                                      context,
                                      '${offers[i]['coin']} coins',
                                      '${offers[i]['coin']} 金币',
                                    ),
                              style: type(18, weight: 650),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tab == 0
                                  ? string(offers[i]['describe'])
                                  : tr(
                                      context,
                                      '+${offers[i]['awardCoin']} bonus coins',
                                      '赠送 ${offers[i]['awardCoin']} 金币',
                                    ),
                              style: type(12, color: accountMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(price(offers[i]), style: type(18, weight: 600)),
                    ],
                  ),
                ),
              ),
            ),
          if (offers.isEmpty)
            ApiProblem(
              tr(context, 'No offers available.', '暂无可购买套餐。'),
              retry: refresh,
            ),
        ],
      );
    },
  );
}

String price(Json offer) =>
    '${string(offer['currency']).isEmpty ? 'USD' : offer['currency']} ${num.tryParse('${offer['currentCost'] ?? offer['price']}')?.toStringAsFixed(2) ?? '—'}';

class LiveCheckout extends StatefulWidget {
  const LiveCheckout({super.key, required this.offer, required this.coins});
  final Json offer;
  final bool coins;
  @override
  State<LiveCheckout> createState() => _LiveCheckoutState();
}

class _LiveCheckoutState extends State<LiveCheckout> {
  String? method, error;
  bool busy = false, submitted = false;
  String? checkoutUrl;
  Future<void> pay() async {
    if (busy || method == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = AccountScope.of(context).api!;
      final result = await api
          .post(widget.coins ? 'payment/coin' : 'payment/member', {
            'payName': method,
            widget.coins ? 'coinId' : 'memberId': widget.offer['id'],
            'device': api.platform,
            'targetUrl': const String.fromEnvironment(
              'PAYMENT_SUCCESS_URL',
              defaultValue: 'reelmax://payment/success',
            ),
            'cancelUrl': const String.fromEnvironment(
              'PAYMENT_CANCEL_URL',
              defaultValue: 'reelmax://payment/cancel',
            ),
          });
      final data = object(result);
      final url = result is String
          ? result
          : string(data['url'] ?? data['payUrl'] ?? data['checkoutUrl']);
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const ApiException('支付接口未返回可打开的收银台地址。');
      }
      if (!mounted) return;
      setState(() {
        checkoutUrl = url;
        submitted = true;
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ApiException('无法打开收银台，请重试打开。');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiView(
    load: (api) => api.get('payment/payWay/list', {'device': api.platform}),
    builder: (data, refresh) {
      final ways = data is List ? data : object(data)['list'] ?? [];
      final names = <String>[];
      if (ways is List) {
        for (final way in ways) {
          final name = way is String
              ? way
              : string(object(way)['payName'] ?? object(way)['name']);
          if (name.isNotEmpty) names.add(name);
        }
      }
      return AccountFrame(
        title: tr(context, 'Checkout', '确认订单'),
        children: [
          AccountCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.coins
                      ? '${widget.offer['coin']} ${tr(context, 'Coins', '金币')}'
                      : string(widget.offer['name']),
                  style: type(24, weight: 650),
                ),
                const SizedBox(height: 18),
                Text(price(widget.offer), style: type(32, weight: 700)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(context, 'Payment method', '支付方式'),
            style: type(18, weight: 650),
          ),
          for (final name in names)
            ListTile(
              leading: Icon(
                method == name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(name),
              enabled: !busy && !submitted,
              onTap: () => setState(() => method = name),
            ),
          if (names.isEmpty)
            ApiProblem(
              tr(
                context,
                'No payment methods are configured for this device.',
                '当前设备暂无可用支付方式。',
              ),
              retry: refresh,
            ),
          if (error != null) ApiProblem(error!),
          const SizedBox(height: 24),
          if (!submitted)
            AccountButton(
              text: tr(context, 'Open secure checkout', '前往收银台'),
              busy: busy,
              onTap: method == null || busy ? null : pay,
            ),
          if (submitted) ...[
            Text(
              tr(
                context,
                'Complete payment in the checkout page. Your balance and membership are confirmed by the server.',
                '请在收银台完成支付，金币与会员权益以服务器确认结果为准。',
              ),
              style: type(13, height: 1.5, color: accountMuted),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(checkoutUrl!),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(tr(context, 'Reopen checkout', '重新打开收银台')),
            ),
            AccountButton(
              text: tr(context, 'Check order status', '查看订单状态'),
              onTap: () async {
                await Navigator.of(
                  context,
                ).push(reelRoute(const LiveRecordsPage()));
                if (!context.mounted) return;
                try {
                  await AccountScope.of(context).refreshProfile();
                } catch (e) {
                  if (mounted) setState(() => error = '$e');
                }
              },
            ),
          ],
        ],
      );
    },
  );
}

class LiveRecordsPage extends StatefulWidget {
  const LiveRecordsPage({super.key, this.coins = false});
  final bool coins;
  @override
  State<LiveRecordsPage> createState() => _LiveRecordsPageState();
}

class _LiveRecordsPageState extends State<LiveRecordsPage> {
  final rows = <Json>[];
  int page = 0;
  bool busy = false, more = true, started = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    if (reset) {
      rows.clear();
      page = 0;
      more = true;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await AccountScope.of(context).api!.get(
        widget.coins ? 'user/coinRecord/list' : 'payment/orderRecord/list',
        {'page': page + 1, 'pageSize': 20},
      );
      if (!mounted) return;
      final next = objects(result);
      setState(() {
        rows.addAll(next);
        page++;
        more = object(result)['pages'] == null
            ? next.length >= 20
            : page < integer(object(result)['pages']);
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountFrame(
    title: tr(
      context,
      widget.coins ? 'Coin history' : 'Orders',
      widget.coins ? '金币记录' : '订单记录',
    ),
    trailing: IconButton(
      onPressed: busy ? null : () => load(reset: true),
      icon: const Icon(Icons.refresh),
    ),
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AccountCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  string(
                    row['name'] ??
                        row['title'] ??
                        row['description'] ??
                        row['describe'] ??
                        row['orderId'],
                  ),
                  style: type(17, weight: 600),
                ),
                const SizedBox(height: 10),
                for (final key
                    in widget.coins
                        ? ['coin', 'amount', 'balance', 'type', 'createdAt']
                        : [
                            'orderId',
                            'price',
                            'amount',
                            'currency',
                            'payName',
                            'status',
                            'createdAt',
                          ])
                  if (row[key] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '${recordLabel(context, key)}: ${row[key]}',
                        style: type(12, color: accountMuted),
                      ),
                    ),
              ],
            ),
          ),
        ),
      if (error != null)
        ApiProblem(error!, retry: () => load(reset: page == 0)),
      if (busy) const Center(child: CircularProgressIndicator()),
      if (!busy && error == null && rows.isEmpty)
        ApiProblem(tr(context, 'No records yet.', '暂无记录。')),
      if (!busy && more && rows.isNotEmpty)
        TextButton(
          onPressed: load,
          child: Text(tr(context, 'Load more', '加载更多')),
        ),
    ],
  );
}

String recordLabel(BuildContext context, String key) => tr(
  context,
  {
        'orderId': 'Order number',
        'price': 'Price',
        'amount': 'Amount',
        'currency': 'Currency',
        'payName': 'Payment method',
        'status': 'Status',
        'createdAt': 'Date',
        'coin': 'Coins',
        'balance': 'Balance',
        'type': 'Type',
      }[key] ??
      key,
  {
        'orderId': '订单号',
        'price': '价格',
        'amount': '金额/数量',
        'currency': '币种',
        'payName': '支付方式',
        'status': '状态',
        'createdAt': '时间',
        'coin': '金币',
        'balance': '余额',
        'type': '类型',
      }[key] ??
      key,
);
