class DramaInfo {
  const DramaInfo({
    required this.title,
    required this.image,
    this.description = '',
    this.genre = '',
    this.preview = 'racing-preview.mp4',
    this.posterScale = 1,
    this.serverId,
  });

  final String title, image, description, genre, preview;
  final double posterScale;
  final int? serverId;
  String get id => serverId?.toString() ?? '$title:$image';
}

class Feature {
  const Feature(
    this.title,
    this.genre,
    this.age,
    this.subtitle,
    this.image,
    this.video, {
    this.serverId,
  });
  final String title, genre, age, subtitle, image, video;
  final int? serverId;
  DramaInfo get detail => DramaInfo(
    title: title,
    serverId: serverId,
    image: image,
    description: serverId != null
        ? subtitle
        : title == 'Battle Of Two Cities'
        ? 'Dokja was an average office worker until the story he had followed '
              'for years became his reality. Caught between two rival cities, '
              'he must decide who to trust as a hidden power threatens everything '
              'he knows. An unexpected alliance could change his fate — and '
              'the future of both cities.'
        : 'One driver. One last chance to change everything. With his career '
              'on the line, a gifted racer returns to the track alongside a '
              'fearless newcomer. As old rivalries resurface and the stakes '
              'rise, they discover that the hardest race is the one beyond '
              'the finish line.',
    genre: genre,
    preview: video,
    // The original hero PNGs contain transparent, curved outer margins.
    posterScale: serverId == null ? 1.22 : 1,
  );
}

const features = [
  Feature(
    'Battle Of Two Cities',
    'Fantasy · Romance',
    '18+',
    'Dokja Was An Average Office Worker…',
    'battle-of-two-cities.png',
    'racing-preview.mp4',
  ),
  Feature(
    'Redline',
    'Action · Drama',
    '13+',
    'One driver. One last chance to change everything.',
    'euphoria-cover.png',
    'next-preview.mp4',
  ),
];
const episodes = ['racing-preview.mp4', 'episode-04.mp4', 'episode-05.mp4'];

// Fixed content for the detail-page preview until a catalog is connected.
const detailSynopsis =
    'An unexpected encounter brings two very different lives together. '
    'As family secrets come to light, loyalty and love are put to the test. '
    'Every choice draws them closer to a truth that could change everything.';
const detailCast = [
  (name: 'Brad Pitt', image: 'cast-brad.png'),
  (name: 'Kerry Condon', image: 'cast-kerry.png'),
  (name: 'Damson Idris', image: 'cast-damson.png'),
  (name: 'Javier Bardem', image: 'cast-javier.png'),
];

class Drama {
  const Drama(
    this.id,
    this.image, {
    this.description = '',
    this.favorites = '',
    this.readers = '',
  });
  final String id, image, description, favorites, readers;
  String get title => 'My Sister Covets MyFiancé';
  String get genre => 'Fantasy · Romance';
  DramaInfo get detail => DramaInfo(
    title: title,
    image: image,
    description: description,
    genre: genre,
  );
}

final searchDramas = [
  const DramaInfo(title: 'The Last Signal', image: 'poster-chosen-one.png'),
  features[1].detail,
  const DramaInfo(title: 'Afterlight', image: 'poster-greendale.png'),
  const DramaInfo(title: 'Neon Drift', image: 'poster-john-wick.png'),
];

const history = [
  Drama('film', 'list-film-yourself.png'),
  Drama('love', 'list-love-story.png'),
  Drama('pitt', 'list-the-pitt.png'),
  Drama('euphoria', 'list-euphoria.png'),
];
const collected = [
  Drama(
    'saved-love',
    'list-love-story.png',
    description:
        'A love story caught between family ambition and a dangerous secret.',
    favorites: '18.6K',
    readers: '284K',
  ),
  Drama(
    'saved-euphoria',
    'list-euphoria.png',
    description:
        'A restless night exposes the secrets no one was ready to face.',
    favorites: '12.4K',
    readers: '196K',
  ),
  Drama(
    'saved-film',
    'list-film-yourself.png',
    description:
        'An unexpected romance tests loyalty, family, and everything she trusts.',
    favorites: '9.8K',
    readers: '143K',
  ),
];
