import 'package:flutter/material.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'design.dart';
import 'localization.dart';

enum _AuthMode { login, register, recover, reset, resetDone }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  final name = TextEditingController(),
      confirm = TextEditingController(),
      code = TextEditingController();
  _AuthMode mode = _AuthMode.login;
  bool obscure = true, busy = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [email, password, name, confirm, code]) {
      controller.dispose();
    }
    super.dispose();
  }

  void switchMode(_AuthMode value) {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      mode = value;
      error = null;
      password.clear();
      confirm.clear();
      code.clear();
    });
  }

  Future<void> submit() async {
    if (busy || !(form.currentState?.validate() ?? false)) return;
    final store = AccountScope.of(context);
    if (store.live) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        busy = true;
        error = null;
      });
      try {
        await store.initialize();
        if (mode == _AuthMode.recover) {
          await store.sendCode(email.text);
          if (!mounted) return;
          setState(() {
            busy = false;
            mode = _AuthMode.reset;
          });
        } else if (mode == _AuthMode.reset) {
          await store.resetPassword(email.text, code.text, password.text);
          if (!mounted) return;
          setState(() {
            busy = false;
            mode = _AuthMode.resetDone;
            password.clear();
            confirm.clear();
          });
        } else {
          await store.loginEmail(
            email.text,
            password.text,
            nickname: mode == _AuthMode.register ? name.text : null,
            code: mode == _AuthMode.register ? code.text : null,
          );
          if (mounted) Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      } finally {
        if (mounted) setState(() => busy = false);
      }
      return;
    }
    if (mode == _AuthMode.register && store.hasAccount(email.text)) {
      setState(
        () => error = tr(
          context,
          'This demo account already exists. Please sign in.',
          '这个演示账号已存在，请直接登录。',
        ),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => busy = false);
    if (mode == _AuthMode.recover) {
      switchMode(_AuthMode.reset);
    } else if (mode == _AuthMode.reset) {
      switchMode(_AuthMode.resetDone);
    } else {
      store.signIn(
        email.text,
        name: mode == _AuthMode.register ? name.text : null,
        register: mode == _AuthMode.register,
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> social(String provider) async {
    if (busy) return;
    final store = AccountScope.of(context);
    if (store.live) {
      setState(
        () => error = tr(
          context,
          '$provider sign-in is not configured yet. Please use email.',
          '$provider 登录暂未配置，请先使用邮箱登录。',
        ),
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1d2524),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text(
          tr(context, '$provider demo sign-in', '$provider 演示登录'),
          style: type(21, weight: 750, height: 1.2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alex Morgan', style: type(18, weight: 650)),
            const SizedBox(height: 7),
            Text(
              'alex.${provider.toLowerCase()}@example.com',
              style: type(12, color: accountMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            Text(
              tr(
                context,
                'Use this sample profile to preview social sign-in. No connection to $provider is made.',
                '使用示例资料体验社交登录，不会连接 $provider 账号。',
              ),
              style: type(13, color: accountMuted, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', '取消')),
          ),
          TextButton(
            key: const ValueKey('social-demo-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Use demo account', '使用演示账号')),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    store.signIn(
      'alex.${provider.toLowerCase()}@example.com',
      name: 'Alex Morgan',
      provider: provider,
    );
    Navigator.of(context).pop();
  }

  Widget field(
    String id,
    String label,
    TextEditingController controller, {
    bool secret = false,
    bool emailField = false,
    bool numeric = false,
    String? hint,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: type(12, weight: 600, color: const Color(0xffb6c0bc)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('auth-$id'),
          controller: controller,
          readOnly: busy,
          validator: validate,
          obscureText: secret && obscure,
          autocorrect: !secret && !emailField,
          enableSuggestions: !secret,
          keyboardType: emailField
              ? TextInputType.emailAddress
              : numeric
              ? TextInputType.number
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          style: type(15, height: 1.3),
          scrollPadding: const EdgeInsets.all(90),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0x08ffffff),
            hintText: hint,
            hintStyle: type(14, color: const Color(0xff828982)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x24ffffff)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x24ffffff)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accountMint),
            ),
            errorMaxLines: 2,
            errorStyle: type(11, height: 1.3, color: const Color(0xffff9b9b)),
            suffixIcon: secret
                ? IconButton(
                    tooltip: tr(
                      context,
                      obscure ? 'Show password' : 'Hide password',
                      obscure ? '显示密码' : '隐藏密码',
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: accountMuted,
                      size: 19,
                    ),
                  )
                : null,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final live = AccountScope.of(context).live;
    final registering = mode == _AuthMode.register;
    final emailMode = mode == _AuthMode.login || registering;
    final title = switch (mode) {
      _AuthMode.login => tr(context, 'Welcome back.', '欢迎回来。'),
      _AuthMode.register => tr(context, 'Create account', '创建账号'),
      _AuthMode.recover => tr(context, 'Forgot your password?', '忘记密码了？'),
      _AuthMode.reset => tr(context, 'Set a new password.', '设置新密码。'),
      _AuthMode.resetDone => tr(context, 'All set.', '设置完成。'),
    };
    final subtitle = switch (mode) {
      _AuthMode.login => tr(
        context,
        'Sign in and pick up where you left off.',
        '登录账号，继续上次的精彩。',
      ),
      _AuthMode.register => tr(
        context,
        'One account. A world of stories.',
        '一个账号，尽享万千故事。',
      ),
      _AuthMode.recover => tr(
        context,
        live
            ? 'Enter your email to receive a reset code.'
            : 'Enter your email to preview password recovery.',
        live ? '输入邮箱，接收重置密码验证码。' : '输入邮箱，体验密码找回流程。',
      ),
      _AuthMode.reset => tr(
        context,
        live
            ? 'Enter the verification code sent to your email.'
            : 'Demo code: 123456. No email was sent.',
        live ? '请输入邮件中的验证码。' : '演示验证码：123456，不会发送真实邮件。',
      ),
      _AuthMode.resetDone => tr(
        context,
        live
            ? 'Your password has been reset. Sign in with your new password.'
            : 'Password reset preview complete. You can now try signing in with sample details.',
        live ? '密码已重置，请使用新密码登录。' : '密码重置演示已完成，现在可以使用示例资料体验登录。',
      ),
    };
    return AccountFrame(
      title: 'Reel Max',
      scrollKey: const ValueKey('auth-scroll'),
      children: [
        if (mode == _AuthMode.login)
          CinemaBanner(
            title: title,
            label: tr(context, 'YOUR NEXT CHAPTER', '精彩待续'),
            height: 148,
            foregroundPoster: 'history-fashion.png',
            backgroundPoster: 'history-crowd.png',
          )
        else ...[
          const SizedBox(height: 12),
          Text(title, style: type(26, weight: 650, spacing: -.7, height: 1.15)),
        ],
        const SizedBox(height: 14),
        Text(subtitle, style: type(12, color: accountMuted, height: 1.5)),
        const SizedBox(height: 22),
        if (emailMode) ...[
          Row(
            children: [
              for (final provider in ['Google', 'Facebook']) ...[
                if (provider == 'Facebook') const SizedBox(width: 12),
                Expanded(
                  child: Pressable(
                    key: ValueKey('auth-${provider.toLowerCase()}'),
                    label: 'Continue with $provider',
                    onTap: () => social(provider),
                    child: Glass(
                      height: 44,
                      variant: GlassVariant.filter,
                      borderOpacity: .27,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Glyph(provider.toLowerCase(), size: 18),
                          const SizedBox(width: 9),
                          Text(provider, style: type(13, weight: 500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                const Expanded(
                  child: Divider(height: 1, color: Color(0x18ffffff)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    tr(context, 'or use email', '或使用邮箱'),
                    style: type(10, color: accountMuted),
                  ),
                ),
                const Expanded(
                  child: Divider(height: 1, color: Color(0x18ffffff)),
                ),
              ],
            ),
          ),
        ],
        if (mode != _AuthMode.resetDone)
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (registering)
                  field(
                    'name',
                    tr(context, 'Name', '昵称'),
                    name,
                    hint: 'Alex Morgan',
                    validate: (v) => (v?.trim().length ?? 0) < 2
                        ? tr(
                            context,
                            'Enter at least 2 characters.',
                            '请至少输入 2 个字符。',
                          )
                        : null,
                  ),
                if (mode != _AuthMode.reset)
                  field(
                    'email',
                    tr(context, 'Email address', '邮箱地址'),
                    email,
                    emailField: true,
                    hint: 'alex@example.com',
                    validate: (v) =>
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v?.trim() ?? '')
                        ? tr(
                            context,
                            'Enter a valid email address.',
                            '请输入有效的邮箱地址。',
                          )
                        : null,
                  ),
                if (mode == _AuthMode.reset)
                  field(
                    'code',
                    tr(context, 'Verification code', '验证码'),
                    code,
                    numeric: true,
                    hint: live ? null : '123456',
                    validate: (v) => live
                        ? ((v?.trim().isEmpty ?? true)
                              ? tr(
                                  context,
                                  'Enter the verification code.',
                                  '请输入验证码。',
                                )
                              : null)
                        : v != '123456'
                        ? tr(
                            context,
                            'Use the demo code 123456.',
                            '请输入演示验证码 123456。',
                          )
                        : null,
                  ),
                if (mode != _AuthMode.recover)
                  field(
                    'password',
                    tr(
                      context,
                      mode == _AuthMode.reset ? 'New password' : 'Password',
                      mode == _AuthMode.reset ? '新密码' : '密码',
                    ),
                    password,
                    secret: true,
                    hint: tr(context, '8 or more characters', '至少 8 个字符'),
                    validate: (v) => (v?.length ?? 0) < 8
                        ? tr(
                            context,
                            'Use at least 8 characters.',
                            '密码至少需要 8 个字符。',
                          )
                        : null,
                  ),
                if (registering || mode == _AuthMode.reset)
                  field(
                    'confirm',
                    tr(context, 'Confirm password', '确认密码'),
                    confirm,
                    secret: true,
                    validate: (v) => v != password.text
                        ? tr(
                            context,
                            'The passwords do not match.',
                            '两次输入的密码不一致。',
                          )
                        : null,
                  ),
                if (mode == _AuthMode.login)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('auth-forgot'),
                      onPressed: () => switchMode(_AuthMode.recover),
                      child: Text(
                        tr(context, 'Forgot password?', '忘记密码？'),
                        style: type(12, color: accountMint),
                      ),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      error!,
                      style: type(
                        12,
                        color: const Color(0xffff9b9b),
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                AccountButton(
                  key: const ValueKey('auth-submit'),
                  busy: busy,
                  onTap: submit,
                  text: tr(
                    context,
                    registering
                        ? 'Create account'
                        : mode == _AuthMode.login
                        ? 'Sign in'
                        : mode == _AuthMode.recover
                        ? (live ? 'Send reset code' : 'Preview reset code')
                        : 'Reset password',
                    registering
                        ? '注册账号'
                        : mode == _AuthMode.login
                        ? '登录'
                        : mode == _AuthMode.recover
                        ? (live ? '发送验证码' : '获取演示验证码')
                        : '重置密码',
                  ),
                ),
              ],
            ),
          ),
        if (mode == _AuthMode.resetDone)
          AccountButton(
            key: const ValueKey('auth-reset-done'),
            text: tr(context, 'Back to sign in', '返回登录'),
            onTap: () => switchMode(_AuthMode.login),
          ),
        if (emailMode)
          Center(
            child: TextButton(
              key: const ValueKey('auth-switch'),
              onPressed: () => switchMode(
                registering ? _AuthMode.login : _AuthMode.register,
              ),
              child: Text(
                tr(
                  context,
                  registering
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                  registering ? '已有账号？立即登录' : '还没有账号？立即注册',
                ),
                style: type(12, color: accountMint, height: 1.4),
              ),
            ),
          ),
        demoNote(context),
      ],
    );
  }
}
