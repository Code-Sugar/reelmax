import 'package:flutter/material.dart';
import 'design.dart';
import 'localization.dart';
import 'account_state.dart';

const accountGold = Color(0xffe3c78d);
const accountMint = Color(0xffd5e0d9);
const accountMuted = Color(0xffa0a4a2);

String numberText(int number) => number.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
String dateText(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

/// Account screens share the catalogue's charcoal/olive backdrop and glass.
class AccountFrame extends StatelessWidget {
  const AccountFrame({
    super.key,
    required this.title,
    required this.children,
    this.back = true,
    this.trailing,
    this.footer,
    this.tabPage = false,
    this.scrollKey,
  });
  final String title;
  final List<Widget> children;
  final bool back, tabPage;
  final Widget? trailing, footer;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) => Material(
    color: canvasColor,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff111612),
            Color(0xff1b211c),
            Color(0xff111312),
            Color(0xff0c0d0d),
          ],
          stops: [0, .28, .62, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, pageTop(context), 20, 16),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: title == 'Reel Max'
                            ? type(24, weight: 800, slant: -8, spacing: -1.08)
                            : type(18, weight: 600, spacing: -.4),
                      ),
                    ),
                    if (back)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CircleControl(
                          label: tr(context, 'Back', '返回'),
                          size: 38,
                          onTap: () => Navigator.of(context).pop(),
                          child: const Glyph('detail-back', size: 23),
                        ),
                      ),
                    if (trailing != null)
                      Align(alignment: Alignment.centerRight, child: trailing!),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: scrollKey,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  tabPage ? 112 : 28 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            if (footer != null)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xf20f1210),
                  border: Border(top: BorderSide(color: Color(0x14ffffff))),
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  18 + MediaQuery.paddingOf(context).bottom,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    ),
  );
}

/// Quiet data surfaces leave reflective glass to the controls.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x20ffffff)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x12ffffff), Color(0x03ffffff)],
      ),
    ),
    child: child,
  );
}

class AccountButton extends StatelessWidget {
  const AccountButton({
    super.key,
    required this.text,
    required this.onTap,
    this.secondary = false,
    this.busy = false,
  });
  final String text;
  final VoidCallback? onTap;
  final bool secondary, busy;
  @override
  Widget build(BuildContext context) => Pressable(
    label: text,
    onTap: busy ? null : onTap,
    child: AnimatedOpacity(
      opacity: onTap == null && !busy ? .4 : 1,
      duration: motion,
      child: Glass(
        height: 50,
        width: double.infinity,
        variant: secondary ? GlassVariant.control : GlassVariant.play,
        borderOpacity: .28,
        child: Center(
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: secondary ? ink : canvasColor,
                  ),
                )
              : Text(
                  text,
                  textAlign: TextAlign.center,
                  style: type(
                    14,
                    weight: 650,
                    color: secondary ? ink : canvasColor,
                  ),
                ),
        ),
      ),
    ),
  );
}

class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.color = accountMint,
  });
  final IconData icon;
  final String title;
  final String? subtitle, trailing;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Pressable(
    label: title,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xffd4d8d4), size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: type(14, weight: 500, height: 1.3)),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: type(11, color: accountMuted, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: type(12, color: accountMuted)),
          const SizedBox(width: 9),
          const Icon(Icons.chevron_right, size: 18, color: accountMuted),
        ],
      ),
    ),
  );
}

class AccountSegments extends StatelessWidget {
  const AccountSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          Pressable(
            label: labels[i],
            selected: selected == i,
            onTap: () => onChanged(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[i],
                  maxLines: 1,
                  softWrap: false,
                  style: type(
                    18,
                    weight: 650,
                    color: selected == i ? ink : const Color(0xff777d78),
                    spacing: -.5,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: motion,
                  width: 18,
                  height: 2,
                  decoration: BoxDecoration(
                    color: selected == i ? ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class CoinMark extends StatelessWidget {
  const CoinMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffe1d2ad), Color(0xff9d8554)],
      ),
      border: Border.all(color: const Color(0xffeadcb9)),
    ),
    child: Icon(
      Icons.play_arrow_rounded,
      size: size * .55,
      color: const Color(0xff625235),
    ),
  );
}

/// Reuse catalogue artwork throughout the account journey.
class CinemaBanner extends StatelessWidget {
  const CinemaBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.label = 'REEL MAX PLUS',
    this.height = 182,
    this.foregroundPoster = 'poster-steve.png',
    this.backgroundPoster = 'poster-love-scout.png',
  });
  final String title, label, foregroundPoster, backgroundPoster;
  final String? subtitle;
  final Widget? action;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff101711)),
          LayoutBuilder(
            builder: (context, box) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -28,
                  top: -15,
                  width: box.maxWidth * .36,
                  height: height + 42,
                  child: Transform.rotate(
                    angle: .14,
                    child: Art(backgroundPoster, radius: 10),
                  ),
                ),
                Positioned(
                  right: box.maxWidth * .24,
                  top: 16,
                  width: box.maxWidth * .31,
                  height: height + 25,
                  child: Transform.rotate(
                    angle: .14,
                    child: Art(foregroundPoster, radius: 10),
                  ),
                ),
              ],
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff151d17),
                  Color(0xef151d17),
                  Color(0x73151d17),
                  Color(0x10151d17),
                ],
                stops: [0, .32, .64, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00ffffff), Color(0x99070b08)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: type(
                    9,
                    weight: 600,
                    spacing: 1.6,
                    color: const Color(0xffc9d0c5),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: type(26, weight: 650, height: 1.08, spacing: -.8),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    subtitle!,
                    style: type(
                      11,
                      color: const Color(0xffc3c8bf),
                      height: 1.4,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x24ffffff)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget accountLabel(String text) => Padding(
  padding: const EdgeInsets.only(top: 25, bottom: 14),
  child: Text(
    text,
    style: type(11, weight: 500, color: accountMuted, spacing: .6),
  ),
);

Widget demoNote(BuildContext context) => AccountScope.of(context).live
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Center(
          child: Text(
            tr(
              context,
              'Demo preview · No real account or payment is created.',
              '演示预览 · 不创建真实账号，不产生真实扣款。',
            ),
            style: type(10, color: accountMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
