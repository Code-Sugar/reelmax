import 'package:flutter/material.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'account_records.dart';
import 'auth.dart';
import 'design.dart';
import 'detail.dart';
import 'localization.dart';
import 'live_store.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key, this.coins = false});
  final bool coins;
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late int tab = widget.coins ? 1 : 0;
  int plan = 1, pack = 1;
  bool opening = false;
  Future<void> checkout(StoreOffer offer) async {
    if (opening) return;
    setState(() => opening = true);
    final store = AccountScope.of(context);
    try {
      if (!store.signedIn) {
        await Navigator.of(context).push(reelRoute(const AuthPage()));
      }
      if (!mounted || !store.signedIn) return;
      await Navigator.of(context).push(reelRoute(CheckoutPage(offer: offer)));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    if (store.live) return LiveStorePage(coins: widget.coins);
    final offer = tab == 0 ? subscriptionOffers[plan] : coinOffers[pack];
    final currentPlan = store.plus && store.user?.subscription?.id == offer.id;
    return AccountFrame(
      title: tr(context, 'Membership & coins', '会员与金币'),
      scrollKey: const ValueKey('store-scroll'),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AccountButton(
            key: const ValueKey('store-continue'),
            text: currentPlan
                ? tr(context, 'Current plan', '当前套餐')
                : tr(
                    context,
                    'Continue · ${offer.price}',
                    '继续 · ${offer.price}',
                  ),
            onTap: currentPlan || opening ? null : () => checkout(offer),
          ),
          const SizedBox(height: 11),
          Text(
            tr(
              context,
              'Demo prices in USD · No real charge',
              '演示价格（美元）· 不会真实扣款',
            ),
            style: type(10, color: accountMuted),
          ),
        ],
      ),
      children: [
        AccountSegments(
          labels: [
            tr(context, 'Reel Max Plus', 'Reel Max 会员'),
            tr(context, 'Coins', '金币'),
          ],
          selected: tab,
          onChanged: (value) => setState(() => tab = value),
        ),
        const SizedBox(height: 24),
        if (tab == 0) ...[
          CinemaBanner(
            height: 220,
            title: tr(context, 'Stay for the\nwhole story.', '好故事，\n一集也不错过。'),
            subtitle: tr(
              context,
              'Every episode. One membership.',
              '一个会员，畅享全部剧集。',
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.play_circle_outline,
                size: 16,
                color: accountMint,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tr(context, 'All 20 demo episodes included', '解锁全部 20 集演示剧集'),
                  style: type(12, color: accountMint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            tr(context, 'Choose your plan', '选择订阅套餐'),
            style: type(16, weight: 600),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < subscriptionOffers.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            planTile(context, index),
          ],
          const SizedBox(height: 18),
          Text(
            tr(
              context,
              'Your membership starts as soon as checkout is complete.',
              '完成演示购买后，会员权益立即生效。',
            ),
            style: type(11, color: accountMuted, height: 1.5),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              tr(context, 'Available balance', '可用金币'),
              style: type(12, color: accountMuted),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CoinMark(size: 29),
              const SizedBox(width: 12),
              Text(
                numberText(store.user?.balance ?? 0),
                key: const ValueKey('store-balance'),
                style: type(46, weight: 550, spacing: -1.8),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            tr(context, 'Choose a coin pack', '选择金币包'),
            style: type(17, weight: 600, spacing: -.3),
          ),
          const SizedBox(height: 16),
          for (var row = 0; row < 2; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: coinTile(context, row * 2)),
                  const SizedBox(width: 12),
                  Expanded(child: coinTile(context, row * 2 + 1)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.redeem_outlined, size: 17, color: accountGold),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'A little extra, on us. Bonus coins arrive with your purchase.',
                    '购买即享额外赠送，奖励金币随充值一起到账。',
                  ),
                  style: type(12, color: accountMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget selectionSurface({required bool selected, required Widget child}) =>
      AnimatedContainer(
        duration: motion,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? const Color(0xffb9c7bd) : const Color(0x25ffffff),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? const [Color(0x29d1e0d4), Color(0x087c9d86)]
                : const [Color(0x0cffffff), Color(0x04ffffff)],
          ),
        ),
        child: child,
      );

  Widget planTile(BuildContext context, int index) {
    final offer = subscriptionOffers[index];
    return Pressable(
      key: ValueKey('plan-${offer.id}'),
      label: offer.title,
      selected: plan == index,
      onTap: () => setState(() => plan = index),
      child: selectionSurface(
        selected: plan == index,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
          child: Row(
            children: [
              Icon(
                plan == index
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: plan == index ? ink : accountMuted,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, offer.title, offer.chineseTitle),
                      style: type(15, weight: 550),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      tr(
                        context,
                        index == 1
                            ? 'Save 50% with annual'
                            : '30 days of full access',
                        index == 1 ? '年度订阅节省 50%' : '畅享 30 天会员权益',
                      ),
                      style: type(10, color: accountMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(offer.price, style: type(23, weight: 600, spacing: -.5)),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      index == 0 ? 'per month' : 'per year',
                      index == 0 ? '每月' : '每年',
                    ),
                    style: type(10, color: accountMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget coinTile(BuildContext context, int index) {
    final offer = coinOffers[index];
    return Pressable(
      key: ValueKey(offer.id),
      label: offer.title,
      selected: pack == index,
      onTap: () => setState(() => pack = index),
      child: selectionSurface(
        selected: pack == index,
        child: SizedBox(
          height: 140,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CoinMark(size: 20),
                    const Spacer(),
                    if (pack == index)
                      const Icon(Icons.check_rounded, size: 16, color: ink),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  numberText(offer.coins),
                  style: type(27, weight: 600, spacing: -.7),
                ),
                const SizedBox(height: 6),
                Text(
                  offer.bonus > 0
                      ? tr(
                          context,
                          '+${numberText(offer.bonus)} bonus',
                          '+${numberText(offer.bonus)} 赠送',
                        )
                      : tr(context, 'Starter pack', '轻享金币包'),
                  style: type(10, color: accountGold),
                ),
                const Spacer(),
                Text(offer.price, style: type(13, weight: 500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.offer});
  final StoreOffer offer;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  int method = 0;
  bool busy = false;
  DemoOrder? completed;
  static const methods = ['Demo card •••• 4242', 'Google Pay', 'PayPal'];

  Future<void> pay() async {
    if (busy || completed != null) return;
    final store = AccountScope.of(context);
    final buyer = store.user;
    if (buyer == null) return;
    setState(() => busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (store.user != buyer) {
      setState(() => busy = false);
      return;
    }
    final order = store.purchase(widget.offer, methods[method]);
    setState(() {
      completed = order;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    final offer = widget.offer;
    final coins = offer.kind == OfferKind.coins;
    if (completed != null) {
      return AccountFrame(
        title: tr(context, 'Purchase complete', '购买成功'),
        children: [
          const SizedBox(height: 30),
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accountMint.withValues(alpha: .06),
                border: Border.all(color: accountMint.withValues(alpha: .3)),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: accountGold,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              tr(
                context,
                coins ? 'Your coins are here.' : 'Welcome to Plus.',
                coins ? '金币已到账。' : '欢迎成为会员。',
              ),
              key: const ValueKey('purchase-success'),
              textAlign: TextAlign.center,
              style: type(26, weight: 650, spacing: -.6),
            ),
          ),
          const SizedBox(height: 13),
          Center(
            child: Text(
              tr(
                context,
                coins
                    ? '${numberText(offer.coins + offer.bonus)} coins added to your balance.'
                    : 'All 20 demo episodes are now unlocked.',
                coins
                    ? '${numberText(offer.coins + offer.bonus)} 金币已加入余额。'
                    : '全部 20 集演示剧集已解锁。',
              ),
              textAlign: TextAlign.center,
              style: type(14, color: accountMuted, height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          AccountCard(
            child: Column(
              children: [
                receiptRow(
                  context,
                  tr(
                    context,
                    coins ? 'New balance' : 'Your plan',
                    coins ? '最新余额' : '订阅套餐',
                  ),
                  coins
                      ? numberText(store.user!.balance)
                      : tr(context, offer.title, offer.chineseTitle),
                  prominent: true,
                ),
                receiptRow(
                  context,
                  tr(context, 'Order ID', '订单编号'),
                  completed!.id,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AccountButton(
            key: const ValueKey('purchase-done'),
            text: tr(context, 'Done', '完成'),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          AccountButton(
            text: tr(context, 'View order', '查看订单'),
            secondary: true,
            onTap: () => Navigator.of(
              context,
            ).push(reelRoute(OrderDetailsPage(order: completed!))),
          ),
          demoNote(context),
        ],
      );
    }
    return AccountFrame(
      title: tr(context, 'Checkout', '确认支付'),
      scrollKey: const ValueKey('checkout-scroll'),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                tr(context, 'Total', '合计'),
                style: type(14, color: accountMuted),
              ),
              const Spacer(),
              Text(offer.price, style: type(27, weight: 600, spacing: -.7)),
            ],
          ),
          const SizedBox(height: 15),
          AccountButton(
            key: const ValueKey('checkout-pay'),
            text: tr(context, 'Confirm demo purchase', '确认演示购买'),
            busy: busy,
            onTap: pay,
          ),
          const SizedBox(height: 10),
          Text(
            tr(context, 'Preview only · No actual charge', '仅供演示 · 不产生真实扣款'),
            style: type(10, color: accountMuted),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 8),
        AccountCard(
          child: Row(
            children: [
              if (coins)
                const CoinMark(size: 44)
              else
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: accountMint,
                  size: 36,
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coins
                          ? tr(context, offer.title, offer.chineseTitle)
                          : 'Reel Max Plus',
                      style: type(19, weight: 600),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      coins
                          ? tr(
                              context,
                              '${numberText(offer.bonus)} bonus coins',
                              '赠送 ${numberText(offer.bonus)} 金币',
                            )
                          : tr(
                              context,
                              '${offer.title} membership',
                              offer.chineseTitle,
                            ),
                      style: type(12, color: accountMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        accountLabel(tr(context, 'PAYMENT METHOD', '支付方式')),
        for (var i = 0; i < methods.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Pressable(
              key: ValueKey('checkout-method-$i'),
              label: methods[i],
              selected: method == i,
              onTap: busy ? null : () => setState(() => method = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: method == i
                      ? const Color(0x10ffffff)
                      : const Color(0x05ffffff),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: method == i
                        ? const Color(0x66ffffff)
                        : const Color(0x20ffffff),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      i == 0
                          ? Icons.credit_card_rounded
                          : i == 1
                          ? Icons.account_balance_wallet_outlined
                          : Icons.payments_outlined,
                      color: accountMint,
                      size: 23,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(methods[i], style: type(13, weight: 600)),
                    ),
                    Icon(
                      method == i ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: method == i ? accountMint : accountMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        accountLabel(tr(context, 'ORDER SUMMARY', '订单明细')),
        receiptRow(
          context,
          tr(context, 'Item', '商品'),
          tr(context, offer.title, offer.chineseTitle),
        ),
        receiptRow(
          context,
          tr(context, 'Demo total (USD)', '演示金额（美元）'),
          offer.price,
        ),
        Text(
          tr(
            context,
            'Payment methods are shown for preview. This checkout only updates your demo profile.',
            '支付方式仅用于界面预览，完成后只更新演示账号的数据。',
          ),
          style: type(11, color: accountMuted, height: 1.5),
        ),
      ],
    );
  }
}
