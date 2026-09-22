import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelmax/src/design.dart';

void main() {
  const url = 'https://example.test/poster.jpg';

  testWidgets('expanding artwork keeps one image cache key', (tester) async {
    ImageProvider? first;
    for (final size in [80.0, 240.0, 390.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: size,
              height: size * 1.7,
              child: const Art(url, decodeToDisplaySize: false),
            ),
          ),
        ),
      );
      final provider = tester.widget<Image>(find.byType(Image)).image;
      first ??= provider;
      expect(provider, isA<NetworkImage>());
      expect(provider, first);
    }
    expect(tester.takeException(), isNull);
  });

  test(
    'cover decoding preserves source ratio and enough pixels for the crop',
    () {
      const portraitBox = ArtNetworkImage(
        url,
        pixelWidth: 128,
        pixelHeight: 192,
      );
      final landscape = portraitBox.decodeSize(1920, 1080);
      expect(landscape.width, 342);
      expect(landscape.height, 192);

      const landscapeBox = ArtNetworkImage(
        url,
        pixelWidth: 320,
        pixelHeight: 128,
      );
      final portrait = landscapeBox.decodeSize(1080, 1920);
      expect(portrait.width, 320);
      expect(portrait.height, 569);
      expect(portrait.width! / portrait.height!, closeTo(1080 / 1920, .001));
    },
  );

  test('contain, one bounded dimension and small originals remain sharp', () {
    const contain = ArtNetworkImage(
      url,
      pixelWidth: 128,
      pixelHeight: 192,
      fit: BoxFit.contain,
    );
    final landscape = contain.decodeSize(1920, 1080);
    expect(landscape.width, 128);
    expect(landscape.height, 72);
    final narrow = const ArtNetworkImage(
      url,
      pixelWidth: 300,
    ).decodeSize(2000, 3000);
    expect(narrow.width, 300);
    expect(narrow.height, 450);
    final short = const ArtNetworkImage(
      url,
      pixelHeight: 300,
    ).decodeSize(2000, 3000);
    expect(short.width, 200);
    expect(short.height, 300);
    final small = contain.decodeSize(80, 120);
    expect(small.width, 80);
    expect(small.height, 120);
  });

  testWidgets('Art accounts for DPR and zoom without changing layout or fit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<ArtNetworkImage> render(double width, double height) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: const Art(url, scale: 1.1, alignment: Alignment.topCenter),
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.topCenter);
      expect(tester.getSize(find.byType(Art)), Size(width, height));
      return image.image as ArtNetworkImage;
    }

    final first = await render(100, 150);
    expect(first.pixelWidth, 384);
    expect(first.pixelHeight, 512);
    final nearby = await render(101, 151);
    expect(
      nearby,
      first,
      reason: 'Nearby sizes share the same decoded bitmap.',
    );
    expect(nearby.hashCode, first.hashCode);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unbounded dimension never becomes an infinite decode size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: UnconstrainedBox(child: Art(url, width: 100))),
    );
    final provider =
        tester.widget<Image>(find.byType(Image)).image as ArtNetworkImage;
    expect(provider.pixelWidth, 256);
    expect(provider.pixelHeight, isNull);
    expect(tester.takeException(), isNull);
  });
}
