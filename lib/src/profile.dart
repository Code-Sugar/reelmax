import 'package:flutter/material.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'account_records.dart';
import 'auth.dart';
import 'design.dart';
import 'localization.dart';
import 'store.dart';
import 'live_account.dart';
import 'live_catalog.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.openPage,
    required this.openSearch,
  });
  final Future<void> Function(Widget) openPage;
  final VoidCallback openSearch;

  Future<void> protectedPage(AccountStore store, Widget page) async {
    if (!store.signedIn) await openPage(const AuthPage());
    if (store.signedIn) await openPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    final user = store.user;
    final initials = user == null
        ? ''
        : user.name
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part.characters.first)
              .join()
              .toUpperCase();
    return AccountFrame(
      title: 'Reel Max',
      back: false,
      tabPage: true,
      scrollKey: const ValueKey('profile-scroll'),
      trailing: CircleControl(
        key: const ValueKey('profile-search'),
        label: tr(context, 'Search', '搜索'),
        size: 36,
        onTap: openSearch,
        child: const Glyph('search', size: 21),
      ),
      children: [
        const SizedBox(height: 8),
        if (store.live &&
            store.sessionError != null &&
            (!store.signedIn || user == null))
          ApiProblem(store.sessionError!, retry: store.reloadProfile),
        Row(
          children: [
            Glass(
              width: 58,
              height: 58,
              borderOpacity: .3,
              child: Center(
                child: user == null
                    ? const Icon(
                        Icons.person_outline_rounded,
                        size: 28,
                        color: ink,
                      )
                    : Text(initials, style: type(20, weight: 600)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? tr(context, 'Your account', '个人中心'),
                    key: const ValueKey('profile-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type(23, weight: 650, spacing: -.6),
                  ),
                  const SizedBox(height: 9),
                  if (!store.signedIn && !store.restoring)
                    Pressable(
                      key: const ValueKey('profile-sign-in'),
                      label: 'Sign in / Create account',
                      onTap: () => openPage(const AuthPage()),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              tr(
                                context,
                                'Sign in / Create account',
                                '登录 / 注册',
                              ),
                              style: type(12, color: const Color(0xffc2c8c0)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: accountMuted,
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      user?.email ??
                          tr(
                            context,
                            store.restoring
                                ? 'Restoring account…'
                                : 'Signed in · Account details unavailable',
                            store.restoring ? '正在恢复账号…' : '已登录 · 账号资料暂不可用',
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type(11, color: accountMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        CinemaBanner(
          height: 176,
          title: tr(context, 'Every story.\nAll yours.', '每一集精彩，\n尽情看。'),
          action: Pressable(
            key: const ValueKey('profile-plus'),
            label: store.plus ? 'Manage membership' : 'Explore Plus',
            onTap: () => openPage(const StorePage()),
            child: Glass(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              variant: GlassVariant.filter,
              borderOpacity: .35,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(
                      context,
                      store.plus ? 'Manage membership' : 'Explore Plus',
                      store.plus ? '管理订阅' : '了解会员',
                    ),
                    style: type(11, weight: 550),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ),
        if (store.plus)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 12,
                  color: accountMint,
                ),
                const SizedBox(width: 5),
                Text(
                  tr(context, 'ACTIVE', '已开通'),
                  style: type(9, color: accountMint),
                ),
                const Spacer(),
                Text(
                  tr(
                    context,
                    'Until ${dateText(user!.expires!)}',
                    '有效期至 ${dateText(user.expires!)}',
                  ),
                  style: type(10, color: accountMuted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        AccountCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'My coins', '我的金币'),
                      style: type(11, color: accountMuted),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          store.live && store.signedIn && user == null
                              ? '—'
                              : numberText(user?.balance ?? 0),
                          key: const ValueKey('profile-balance'),
                          style: type(29, weight: 600, spacing: -.8),
                        ),
                        const SizedBox(width: 9),
                        const CoinMark(size: 19),
                      ],
                    ),
                  ],
                ),
              ),
              Pressable(
                key: const ValueKey('profile-top-up'),
                label: 'Top up',
                onTap: () => openPage(const StorePage(coins: true)),
                child: Glass(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  variant: GlassVariant.filter,
                  borderOpacity: .3,
                  child: Center(
                    child: Text(
                      tr(context, 'Top up', '充值'),
                      style: type(12, weight: 550),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        AccountRow(
          key: const ValueKey('profile-orders'),
          icon: Icons.receipt_long_outlined,
          title: tr(context, 'Orders', '订单记录'),
          onTap: () => protectedPage(store, const OrdersPage()),
        ),
        const Divider(height: 1, color: Color(0x16ffffff)),
        AccountRow(
          key: const ValueKey('profile-coin-history'),
          icon: Icons.swap_vert_rounded,
          title: tr(context, 'Coin history', '金币记录'),
          onTap: () => protectedPage(store, const CoinRecordsPage()),
        ),
        const Divider(height: 1, color: Color(0x16ffffff)),
        AccountRow(
          key: const ValueKey('profile-language'),
          icon: Icons.language_rounded,
          title: tr(context, 'Language', '应用语言'),
          trailing: store.chinese ? '简体中文' : 'English',
          onTap: () => openPage(const LanguagePage()),
        ),
        if (store.live) ...[
          AccountRow(
            icon: Icons.manage_accounts_outlined,
            title: tr(context, 'Account settings', '账号设置'),
            onTap: () => protectedPage(store, const LiveAccountSettings()),
          ),
          AccountRow(
            icon: Icons.workspace_premium_outlined,
            title: tr(context, 'My subscriptions', '我的订阅'),
            onTap: () => protectedPage(store, const LiveSubscriptions()),
          ),
          AccountRow(
            icon: Icons.help_outline,
            title: tr(context, 'Help & feedback', '帮助与反馈'),
            onTap: () => openPage(const LiveFeedback()),
          ),
          if (store.signedIn)
            AccountRow(
              icon: Icons.refresh,
              title: tr(context, 'Refresh account', '刷新账户'),
              onTap: store.reloadProfile,
            ),
        ],
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: TextButton(
                key: const ValueKey('profile-sign-out'),
                onPressed: store.signOut,
                child: Text(
                  tr(context, 'Sign out', '退出登录'),
                  style: type(12, color: accountMuted),
                ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            'Reel Max · 1.0',
            style: type(10, color: const Color(0xff707670), spacing: .4),
          ),
        ),
      ],
    );
  }
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    return AccountFrame(
      title: tr(context, 'Language', '应用语言'),
      children: [
        const SizedBox(height: 8),
        Text(
          tr(context, 'Display language', '显示语言'),
          style: type(23, weight: 600, spacing: -.5),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'Choose the language for menus and controls. Titles stay in their original language.',
            '选择菜单与操作按钮的显示语言，作品名称保留原文。',
          ),
          style: type(12, color: accountMuted, height: 1.6),
        ),
        const SizedBox(height: 28),
        AccountCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              for (final chinese in [false, true]) ...[
                if (chinese) const Divider(height: 1, color: Color(0x16ffffff)),
                Pressable(
                  key: ValueKey(chinese ? 'language-zh' : 'language-en'),
                  label: chinese ? '简体中文' : 'English',
                  selected: store.chinese == chinese,
                  onTap: () => store.setChinese(chinese),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 23),
                    child: Row(
                      children: [
                        Text(
                          chinese ? '中' : 'Aa',
                          style: type(21, weight: 500, color: accountMuted),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            chinese ? '简体中文' : 'English',
                            style: type(15, weight: 500),
                          ),
                        ),
                        if (store.chinese == chinese)
                          const Icon(Icons.check_rounded, size: 21, color: ink),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
