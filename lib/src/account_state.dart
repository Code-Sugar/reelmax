import 'package:flutter/widgets.dart';
import 'api.dart';

enum OfferKind { subscription, coins }

enum CoinKind { purchase, bonus, spent }

class StoreOffer {
  const StoreOffer(
    this.id,
    this.title,
    this.chineseTitle,
    this.cents,
    this.kind, {
    this.coins = 0,
    this.bonus = 0,
    this.days = 0,
  });
  final String id, title, chineseTitle;
  final int cents, coins, bonus, days;
  final OfferKind kind;
  String get price => '\$${(cents / 100).toStringAsFixed(2)}';
}

const subscriptionOffers = [
  StoreOffer(
    'monthly',
    'Monthly',
    '月度会员',
    999,
    OfferKind.subscription,
    days: 30,
  ),
  StoreOffer(
    'yearly',
    'Yearly',
    '年度会员',
    5999,
    OfferKind.subscription,
    days: 365,
  ),
];
const coinOffers = [
  StoreOffer(
    'coins-300',
    '300 Coins',
    '300 金币',
    299,
    OfferKind.coins,
    coins: 300,
  ),
  StoreOffer(
    'coins-1000',
    '1,000 Coins',
    '1,000 金币',
    999,
    OfferKind.coins,
    coins: 1000,
    bonus: 100,
  ),
  StoreOffer(
    'coins-2500',
    '2,500 Coins',
    '2,500 金币',
    2499,
    OfferKind.coins,
    coins: 2500,
    bonus: 500,
  ),
  StoreOffer(
    'coins-6000',
    '6,000 Coins',
    '6,000 金币',
    4999,
    OfferKind.coins,
    coins: 6000,
    bonus: 1500,
  ),
];

class DemoOrder {
  const DemoOrder({
    required this.id,
    required this.offer,
    required this.date,
    required this.method,
  });
  final String id, method;
  final StoreOffer offer;
  final DateTime date;
}

class CoinEntry {
  const CoinEntry(
    this.title,
    this.chineseTitle,
    this.amount,
    this.balance,
    this.kind,
    this.date,
  );
  final String title, chineseTitle;
  final int amount, balance;
  final CoinKind kind;
  final DateTime date;
}

class DemoAccount {
  DemoAccount({
    required this.name,
    required this.email,
    required this.provider,
  });
  final String name, email, provider;
  int id = 0;
  Json data = {};
  int balance = 0;
  StoreOffer? subscription;
  DateTime? expires;
  final orders = <DemoOrder>[];
  final coins = <CoinEntry>[];
}

/// Live accounts use SkitApi; the in-memory demo is explicitly selected by tests.
class AccountStore extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (api != null) api!.onUnauthorized = null;
    super.dispose();
  }

  AccountStore({this.api}) {
    api?.onUnauthorized = () {
      user = null;
      sessionError = '登录已过期，请重新登录。';
      notifyListeners();
    };
  }
  final SkitApi? api;
  bool get live => api != null;
  bool restoring = false;
  String? sessionError;
  Future<void>? _initializing;
  Future<void> initialize() => _initializing ??= _restore();
  Future<void> _restore() async {
    if (api == null) return;
    restoring = true;
    try {
      await api!.restore();
      chinese = await api!.storage.read('reelmax-language') == 'zh';
      api!.language = chinese ? 'zh' : 'en';
      if (api!.token != null) {
        final saved = await api!.readProfile();
        if (saved != null && integer(saved['id']) > 0) user = _readUser(saved);
        notifyListeners();
        await refreshProfile();
      }
    } catch (e) {
      sessionError = profileError(e);
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  String profileError(Object error) => api?.token != null
      ? chinese
            ? '账号资料暂时加载失败，登录状态已保留，请稍后重试。'
            : 'Account details could not be refreshed. You are still signed in.'
      : '$error';

  DemoAccount _readUser(Json info) {
    final account = DemoAccount(
      name: string(info['nickname']),
      email: string(info['email'] ?? info['accountId']),
      provider: string(info['type']),
    );
    account.id = integer(info['id']);
    account.data = info;
    account.balance = integer(info['balance']);
    account.expires = DateTime.tryParse(string(info['memberDate']));
    return account;
  }

  Future<void> loginEmail(
    String email,
    String password, {
    String? nickname,
    String? code,
  }) async {
    final check = object(
      await api!.get('user/checkEmailExists', {'email': email.trim()}),
    );
    final exists = integer(check['status']) == 1;
    if (nickname == null && !exists) {
      throw const ApiException('该邮箱尚未注册，请先创建账号。');
    }
    if (nickname != null && exists) throw const ApiException('该邮箱已注册，请直接登录。');
    final result = object(
      await api!.post('user/register', {
        'type': 'email',
        'accountId': email.trim(),
        'email': email.trim(),
        'password': password,
        if (nickname != null) 'nickname': nickname.trim(),
        if (code != null && code.isNotEmpty) 'code': code.trim(),
        'device': api!.platform,
        'deviceInfo': '${api!.platform} / Reel Max',
      }),
    );
    final authorization = string(result['authorization']);
    final info = object(result['info']);
    if (authorization.isEmpty || integer(info['id']) == 0) {
      throw const ApiException('登录响应缺少账号或令牌，请联系管理员。');
    }
    await api!.setToken(authorization);
    user = _readUser(info);
    await api!.saveProfile(info, authorization);
    if (api!.token != authorization) return;
    sessionError = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (api == null || api!.token == null) return;
    final token = api!.token;
    final value = object(await api!.get('user/info'));
    if (token != api!.token) return;
    final info = value.containsKey('info') ? object(value['info']) : value;
    if (integer(info['id']) == 0) throw const ApiException('用户资料返回不完整，请重试。');
    user = _readUser(info);
    await api!.saveProfile(info, token!);
    if (api!.token != token) return;
    sessionError = null;
    notifyListeners();
  }

  Future<void> reloadProfile() async {
    try {
      await refreshProfile();
    } catch (e) {
      sessionError = profileError(e);
      notifyListeners();
    }
  }

  Future<void> sendCode(String email) =>
      api!.post('user/sendVerifyCode', {'email': email.trim()});
  Future<void> resetPassword(String email, String code, String password) =>
      api!.post('user/resetEmailPassword', {
        'email': email.trim(),
        'code': code.trim(),
        'password': password,
      });
  bool chinese = false;
  DemoAccount? user;
  final _accounts = <String, DemoAccount>{};
  int _sequence = 1000;
  bool get signedIn => live ? api!.token != null : user != null;
  bool get plus => user?.expires?.isAfter(DateTime.now()) ?? false;
  bool hasAccount(String email) =>
      _accounts.containsKey(email.trim().toLowerCase());

  void signIn(
    String email, {
    String? name,
    String provider = 'Email',
    bool register = false,
  }) {
    final key = email.trim().toLowerCase();
    user = _accounts.putIfAbsent(key, () {
      final account = DemoAccount(
        name: name?.trim().isNotEmpty == true
            ? name!.trim()
            : key.split('@').first,
        email: key,
        provider: provider,
      );
      final now = DateTime.now();
      if (register) {
        account.balance = 100;
        account.coins.add(
          CoinEntry('Welcome gift', '新人奖励', 100, 100, CoinKind.bonus, now),
        );
      } else {
        account.balance = 120;
        account.orders.add(
          DemoOrder(
            id: 'RM-DEMO-1000',
            offer: coinOffers.first,
            date: now.subtract(const Duration(days: 2)),
            method: 'Demo card •••• 4242',
          ),
        );
        account.coins.addAll([
          CoinEntry(
            'Episode unlocks',
            '剧集解锁',
            -200,
            120,
            CoinKind.spent,
            now.subtract(const Duration(days: 1)),
          ),
          CoinEntry(
            'Welcome gift',
            '新人奖励',
            20,
            320,
            CoinKind.bonus,
            now.subtract(const Duration(days: 2)),
          ),
          CoinEntry(
            '300 Coins',
            '300 金币',
            300,
            300,
            CoinKind.purchase,
            now.subtract(const Duration(days: 2)),
          ),
        ]);
      }
      return account;
    });
    notifyListeners();
  }

  Future<void> signOut() async {
    user = null;
    sessionError = null;
    final clearing = api?.setToken(null);
    notifyListeners();
    await clearing;
  }

  void setChinese(bool value) {
    if (chinese == value) return;
    chinese = value;
    if (api != null) {
      api!.language = value ? 'zh' : 'en';
      api!.storage.write('reelmax-language', value ? 'zh' : 'en');
    }
    notifyListeners();
  }

  DemoOrder purchase(StoreOffer offer, String method) {
    if (live) {
      throw StateError('Live purchases must be verified by the server.');
    }
    final account = user;
    if (account == null) throw StateError('Sign in before a demo purchase.');
    final now = DateTime.now();
    final order = DemoOrder(
      id: 'RM-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${++_sequence}',
      offer: offer,
      date: now,
      method: method,
    );
    if (offer.kind == OfferKind.coins) {
      account.balance += offer.coins;
      account.coins.insert(
        0,
        CoinEntry(
          offer.title,
          offer.chineseTitle,
          offer.coins,
          account.balance,
          CoinKind.purchase,
          now,
        ),
      );
      if (offer.bonus > 0) {
        account.balance += offer.bonus;
        account.coins.insert(
          0,
          CoinEntry(
            'Bonus coins',
            '赠送金币',
            offer.bonus,
            account.balance,
            CoinKind.bonus,
            now,
          ),
        );
      }
    } else {
      account.subscription = offer;
      account.expires = now.add(Duration(days: offer.days));
    }
    account.orders.insert(0, order);
    notifyListeners();
    return order;
  }
}

class AccountScope extends InheritedNotifier<AccountStore> {
  const AccountScope({
    super.key,
    required AccountStore store,
    required super.child,
  }) : super(notifier: store);
  static AccountStore of(BuildContext context) => maybeOf(context)!;
  static AccountStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}
