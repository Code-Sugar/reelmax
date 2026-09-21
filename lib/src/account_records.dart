import 'package:flutter/material.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'design.dart';
import 'detail.dart';
import 'localization.dart';
import 'live_store.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    if (store.live) return const LiveRecordsPage();
    final orders = (store.user?.orders ?? <DemoOrder>[])
        .where(
          (order) =>
              filter == 0 ||
              order.offer.kind ==
                  (filter == 1 ? OfferKind.subscription : OfferKind.coins),
        )
        .toList();
    return AccountFrame(
      title: tr(context, 'Orders', '订单记录'),
      scrollKey: const ValueKey('orders-scroll'),
      children: [
        AccountSegments(
          labels: [
            tr(context, 'All', '全部'),
            tr(context, 'Membership', '会员'),
            tr(context, 'Coins', '金币'),
          ],
          selected: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 22),
        if (orders.isEmpty)
          _empty(
            context,
            Icons.receipt_long_outlined,
            tr(context, 'No orders yet', '暂无订单'),
            tr(
              context,
              'Your completed demo purchases will appear here.',
              '完成演示购买后，订单会显示在这里。',
            ),
          ),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Pressable(
              key: ValueKey('order-${order.id}'),
              label: order.id,
              onTap: () => Navigator.of(
                context,
              ).push(reelRoute(OrderDetailsPage(order: order))),
              child: AccountCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          order.offer.kind == OfferKind.coins
                              ? Icons.toll_rounded
                              : Icons.workspace_premium_rounded,
                          color: accountMint,
                          size: 23,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(
                              context,
                              order.offer.title,
                              order.offer.chineseTitle,
                            ),
                            style: type(16, weight: 650),
                          ),
                        ),
                        Text(order.offer.price, style: type(17, weight: 600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(order.id, style: type(10, color: accountMuted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          dateText(order.date),
                          style: type(12, color: accountMuted),
                        ),
                        const Spacer(),
                        Text(
                          tr(context, 'Completed', '已完成'),
                          style: type(11, color: accountMint),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.chevron_right,
                          size: 15,
                          color: accountMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({super.key, required this.order});
  final DemoOrder order;
  @override
  Widget build(BuildContext context) => AccountFrame(
    title: tr(context, 'Order details', '订单详情'),
    children: [
      const SizedBox(height: 18),
      Center(
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accountMint.withValues(alpha: .12),
          ),
          child: const Icon(Icons.check_rounded, color: accountMint, size: 34),
        ),
      ),
      const SizedBox(height: 18),
      Center(
        child: Text(
          tr(context, 'Payment complete', '支付完成'),
          style: type(25, weight: 750),
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: Text(
          tr(context, 'Demo receipt · No actual charge', '演示凭证 · 未产生真实扣款'),
          style: type(12, color: accountMuted),
        ),
      ),
      const SizedBox(height: 30),
      AccountCard(
        child: Column(
          children: [
            receiptRow(
              context,
              tr(context, 'Item', '商品'),
              tr(context, order.offer.title, order.offer.chineseTitle),
            ),
            receiptRow(context, tr(context, 'Order ID', '订单编号'), order.id),
            receiptRow(
              context,
              tr(context, 'Date', '时间'),
              dateText(order.date),
            ),
            receiptRow(
              context,
              tr(context, 'Payment method', '支付方式'),
              order.method,
            ),
            if (order.offer.bonus > 0)
              receiptRow(
                context,
                tr(context, 'Bonus coins', '赠送金币'),
                '+${numberText(order.offer.bonus)}',
              ),
            const Divider(height: 28, color: Color(0x20ffffff)),
            receiptRow(
              context,
              tr(context, 'Total', '订单金额'),
              order.offer.price,
              prominent: true,
            ),
          ],
        ),
      ),
    ],
  );
}

Widget receiptRow(
  BuildContext context,
  String label,
  String value, {
  bool prominent = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 9),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 4,
        child: Text(
          label,
          style: type(
            prominent ? 16 : 12,
            color: prominent ? ink : accountMuted,
            height: 1.4,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 6,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: type(
            prominent ? 23 : 12,
            weight: prominent ? 600 : 500,
            height: 1.4,
          ),
        ),
      ),
    ],
  ),
);

class CoinRecordsPage extends StatefulWidget {
  const CoinRecordsPage({super.key});
  @override
  State<CoinRecordsPage> createState() => _CoinRecordsPageState();
}

class _CoinRecordsPageState extends State<CoinRecordsPage> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    if (AccountScope.of(context).live) {
      return const LiveRecordsPage(coins: true);
    }
    final user = AccountScope.of(context).user;
    final entries = (user?.coins ?? <CoinEntry>[])
        .where(
          (entry) =>
              filter == 0 ||
              (filter == 1 ? entry.amount > 0 : entry.amount < 0),
        )
        .toList();
    return AccountFrame(
      title: tr(context, 'Coin history', '金币记录'),
      scrollKey: const ValueKey('coin-history-scroll'),
      children: [
        AccountCard(
          child: Row(
            children: [
              const CoinMark(size: 50),
              const SizedBox(width: 17),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Available balance', '可用余额'),
                    style: type(12, color: accountMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    numberText(user?.balance ?? 0),
                    key: const ValueKey('history-balance'),
                    style: type(35, weight: 550, spacing: -.9),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AccountSegments(
          labels: [
            tr(context, 'All', '全部'),
            tr(context, 'Added', '收入'),
            tr(context, 'Spent', '支出'),
          ],
          selected: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 22),
        if (entries.isEmpty)
          _empty(
            context,
            Icons.toll_outlined,
            tr(context, 'No coin activity yet', '暂无金币记录'),
            tr(
              context,
              'Top-ups, bonuses and spending will appear here.',
              '充值、奖励与使用明细会显示在这里。',
            ),
          ),
        for (final entry in entries)
          Padding(
            padding: EdgeInsets.zero,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x16ffffff))),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (entry.amount > 0 ? accountMint : accountGold)
                          .withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      entry.kind == CoinKind.bonus
                          ? Icons.redeem_rounded
                          : entry.amount > 0
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 20,
                      color: entry.amount > 0 ? accountMint : accountGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, entry.title, entry.chineseTitle),
                          style: type(14, weight: 500, height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateText(entry.date),
                          style: type(11, color: accountMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.amount > 0 ? '+' : '−'}${numberText(entry.amount.abs())}',
                        style: type(
                          17,
                          weight: 700,
                          color: entry.amount > 0 ? accountMint : ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          context,
                          'Balance ${numberText(entry.balance)}',
                          '余额 ${numberText(entry.balance)}',
                        ),
                        style: type(10, color: accountMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Widget _empty(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 60),
  child: Center(
    child: Column(
      children: [
        Icon(icon, size: 44, color: accountMuted),
        const SizedBox(height: 18),
        Text(title, style: type(20, weight: 650)),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: type(13, height: 1.5, color: accountMuted),
        ),
      ],
    ),
  ),
);
