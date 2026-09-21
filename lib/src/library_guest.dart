import 'package:flutter/material.dart';
import 'account_ui.dart';
import 'design.dart';
import 'localization.dart';

/// Fits the area between the library tabs and the floating navigation bar.
class LibraryStatus extends StatelessWidget {
  const LibraryStatus({
    super.key,
    required this.loading,
    required this.liked,
    this.error,
    required this.retry,
  });
  final bool loading, liked;
  final String? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final failed = !loading && error != null;
    final color = loading || failed
        ? accountMint
        : liked
        ? const Color(0xffeeaab8)
        : accountGold;
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                key: const ValueKey('library-status-content'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                color.withValues(alpha: .12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Glass(
                          width: 78,
                          height: 90,
                          radius: 23,
                          borderOpacity: .2,
                          child: Center(
                            child: loading
                                ? SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accountMint,
                                      backgroundColor: Colors.white10,
                                    ),
                                  )
                                : failed
                                ? Icon(
                                    Icons.refresh_rounded,
                                    size: 33,
                                    color: color,
                                  )
                                : Glyph(
                                    liked ? 'player-heart' : 'player-bookmark',
                                    size: 33,
                                    color: color,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    tr(
                      context,
                      loading
                          ? 'Getting your stories…'
                          : failed
                          ? 'Couldn’t load your list'
                          : liked
                          ? 'Your favorites start here'
                          : 'Make room for great stories',
                      loading
                          ? '正在整理你的故事…'
                          : failed
                          ? '暂时无法加载清单'
                          : liked
                          ? '喜欢的故事，从这里开始'
                          : '好故事，值得收藏',
                    ),
                    textAlign: TextAlign.center,
                    style: type(22, weight: 700, height: 1.2, spacing: -.5),
                  ),
                  const SizedBox(height: 11),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      tr(
                        context,
                        loading
                            ? 'Your list will be ready in a moment.'
                            : failed
                            ? 'Please try again in a moment.'
                            : liked
                            ? 'Tap the heart on a story you love.\nYou’ll find it here.'
                            : 'Tap the bookmark on a story.\nSave it here for your next watch.',
                        loading
                            ? '稍等片刻，马上就好。'
                            : failed
                            ? '请稍后重试。'
                            : liked
                            ? '遇见喜欢的短剧，点亮爱心，\n就能在这里找到它。'
                            : '看到想追的短剧，轻点收藏，\n下次打开就能找到。',
                      ),
                      textAlign: TextAlign.center,
                      style: type(13, color: accountMuted, height: 1.6),
                    ),
                  ),
                  if (failed) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 160,
                      child: AccountButton(
                        text: tr(context, 'Try again', '重试'),
                        onTap: retry,
                        secondary: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryGuest extends StatelessWidget {
  const LibraryGuest({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onSignIn,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final liked = selected == 1;
    final accent = liked ? const Color(0xffeeaab8) : accountGold;
    return AccountFrame(
      title: 'List',
      back: false,
      tabPage: true,
      children: [
        AccountSegments(
          labels: [tr(context, 'Collect', '收藏'), tr(context, 'Liked', '喜欢')],
          selected: selected,
          onChanged: onChanged,
        ),
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * .065).clamp(24, 58),
        ),
        Center(
          child: SizedBox(
            width: 268,
            height: 212,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 248,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: .12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(-57, 9),
                  child: Transform.rotate(
                    angle: -.19,
                    child: Glass(
                      width: 91,
                      height: 128,
                      radius: 18,
                      borderOpacity: .1,
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 28,
                          color: Color(0x36ffffff),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(57, 9),
                  child: Transform.rotate(
                    angle: .19,
                    child: Glass(
                      width: 91,
                      height: 128,
                      radius: 18,
                      borderOpacity: .1,
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 28,
                          color: Color(0x36ffffff),
                        ),
                      ),
                    ),
                  ),
                ),
                Glass(
                  width: 106,
                  height: 148,
                  radius: 22,
                  borderOpacity: .28,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Glyph(
                        liked ? 'player-heart' : 'player-bookmark',
                        key: ValueKey(liked),
                        size: 42,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: Container(
                    width: 32,
                    height: 2,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 25),
        Text(
          tr(
            context,
            liked ? 'Keep your favorites close.' : 'Your next favorite, saved.',
            liked ? '喜欢的故事，随时重温' : '收藏好故事，留给下一次',
          ),
          textAlign: TextAlign.center,
          style: type(26, weight: 750, height: 1.12, spacing: -.7),
        ),
        const SizedBox(height: 13),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            tr(
              context,
              liked
                  ? 'Sign in to find the stories you love,\nall in one place.'
                  : 'Sign in to save your favorite stories\nand come back whenever you like.',
              liked ? '登录后，把喜欢的短剧留在这里，\n随时回来重温。' : '登录后收藏心动的短剧，\n想看的时候，随时回来。',
            ),
            textAlign: TextAlign.center,
            style: type(13, color: accountMuted, height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: SizedBox(
            width: 216,
            child: AccountButton(
              text: tr(context, 'Sign in / Create account', '登录 / 注册'),
              onTap: onSignIn,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 14,
              color: accountMint.withValues(alpha: .5),
            ),
            const SizedBox(width: 6),
            Text(
              tr(context, 'A space for your stories', '属于你的故事清单'),
              style: type(11, color: accountMint.withValues(alpha: .5)),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
