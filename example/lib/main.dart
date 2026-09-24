import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobius_carousel/mobius_carousel.dart';

import 'bird_palette.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobius Carousel Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63)),
        scaffoldBackgroundColor: const Color(0xFFFDF7F8),
      ),
      home: const HomePage(),
    );
  }
}

/// One offer, plus the bird photo that fronts it.
///
/// The photo is the only thing visible on the card: everything the offer
/// would normally show is kept in the tree but hidden (see [_BirdCard]),
/// and the card's accent colour is read off the photo at runtime rather
/// than hard-coded, so the pull-down ripple takes on the bird's colour.
@immutable
class _Bird {
  const _Bird({
    required this.asset,
    required this.species,
    required this.scientificName,
    required this.range,
    required this.fact,
    required this.photographer,
    required this.code,
  });

  /// Asset path of the photograph shown on the card.
  final String asset;

  /// Common name, e.g. "Red-and-green Macaw".
  final String species;

  /// Binomial name, e.g. "Ara chloropterus".
  final String scientificName;

  /// Where the bird lives, phrased to read after "from".
  final String range;

  /// One true sentence about the bird, shown on the details screen.
  final String fact;

  /// Photographer credited in assets/birds/CREDITS.md. Every photo is CC0.
  final String photographer;

  /// Short code shown in the (hidden) card chip and the claim dialog.
  final String code;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<_Bird> _birds = [
    _Bird(
      asset: 'assets/birds/red_and_green_macaw.jpg',
      species: 'Red-and-green Macaw',
      scientificName: 'Ara chloropterus',
      range: 'the forests of South America',
      fact: 'One of the largest macaws, with a wingspan of over a metre. '
          'The red lines across its bare cheek are made of tiny feathers, '
          'and the pattern is unique to each bird.',
      photographer: 'Dcoetzee',
      code: 'MACAW20',
    ),
    _Bird(
      asset: 'assets/birds/chilean_flamingo.jpg',
      species: 'Chilean Flamingo',
      scientificName: 'Phoenicopterus chilensis',
      range: 'the lakes of temperate South America',
      fact: 'Its pink comes from carotenoid pigments in the algae and '
          'crustaceans it filters out of the water — a flamingo fed '
          'differently fades to white.',
      photographer: 'Carlota Vidal',
      code: 'FLAM24',
    ),
    _Bird(
      asset: 'assets/birds/sun_conure.jpg',
      species: 'Sun Parakeet',
      scientificName: 'Aratinga solstitialis',
      range: 'north-eastern South America',
      fact: 'Endangered in the wild. Young birds are green and only turn '
          'this orange-gold as they mature.',
      photographer: 'Daderot',
      code: 'CONURE50',
    ),
    _Bird(
      asset: 'assets/birds/yellow_warbler.jpg',
      species: 'Yellow Warbler',
      scientificName: 'Setophaga petechia',
      range: 'the Americas, this one from the Galápagos',
      fact: 'Most populations migrate thousands of kilometres each year, '
          'but the Galápagos birds stay put all their lives.',
      photographer: 'Wmpearl',
      code: 'WARB15',
    ),
    _Bird(
      asset: 'assets/birds/yellow_collared_lovebird.jpg',
      species: 'Yellow-collared Lovebird',
      scientificName: 'Agapornis personatus',
      range: 'the woodlands of northern Tanzania',
      fact: 'Named for how tightly bonded pairs perch — pressed together, '
          'preening each other for long stretches.',
      photographer: 'Adam Kranz',
      code: 'LOVE100',
    ),
    _Bird(
      asset: 'assets/birds/indian_peacock.jpg',
      species: 'Indian Peafowl',
      scientificName: 'Pavo cristatus',
      range: 'the Indian subcontinent',
      fact: 'The national bird of India. The male grows his train of eyed '
          'feathers for the breeding season and sheds it afterwards, '
          'every year.',
      photographer: 'Bernard Spragg. NZ',
      code: 'PEA75',
    ),
  ];

  /// Accent colour per bird, extracted from its photo. Starts empty and
  /// fills in as the images decode; until then the carousel's own default
  /// accent is used, so the first frame never waits on image work.
  final Map<String, Color> _accents = <String, Color>{};

  @override
  void initState() {
    super.initState();
    _loadAccents();
  }

  Future<void> _loadAccents() async {
    for (final bird in _birds) {
      final color = await dominantColorOfAsset(bird.asset);
      if (!mounted) return;
      setState(() => _accents[bird.asset] = color);
    }
  }

  List<MobiusItem> get _items => [
        for (final bird in _birds)
          MobiusItem(
            code: bird.code,
            // The dialog reads "<billAmount> from <provider>".
            provider: bird.range,
            accountNumber: bird.scientificName,
            billAmount: bird.species,
            logo: Icons.flutter_dash,
            // Drives the card glow, the claim dialog and — the point of
            // the demo — the drag-down ripple behind the cards.
            color: _accents[bird.asset],
            data: bird,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return MobiusCarousel(
      items: _items,
      header: const _DemoHeader(),
      footer: const _DragHint(),
      rippleStyle: MobiusRippleStyle.semiCircle,
      cardBuilder: (context, item, isFocused) =>
          _BirdCard(item: item, isFocused: isFocused),
      onCenterCardTap: (item) {
        debugPrint('center tapped: ${item.provider}');
      },
      onOfferClaimed: (item) {
        debugPrint('offer claimed: ${item.provider} — ${item.billAmount}');
      },
      onClaimConfirmed: (context, item) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ClaimedDestinationPage(item: item),
          ),
        );
      },
    );
  }
}

/// A card whose face is a bird photograph.
///
/// The offer details are still built — code chip, logo badge, provider,
/// account number, dashed divider and bill amount — but wrapped in a
/// [Visibility] that is `visible: false` while keeping its state, size and
/// animations. They occupy exactly the space they always did and can be
/// switched back on by flipping one flag; they simply are not painted.
class _BirdCard extends StatelessWidget {
  const _BirdCard({required this.item, required this.isFocused});

  final MobiusItem item;
  final bool isFocused;

  /// Flip to `true` to reveal the offer details over the photo again.
  static const bool _showOfferDetails = false;

  @override
  Widget build(BuildContext context) {
    final bird = item.data as _Bird;
    final accent = item.color ?? const Color(0xFFE91E63);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? accent.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: isFocused ? 26 : 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              bird.asset,
              fit: BoxFit.cover,
              // The photo is the card's whole visual; announce the bird
              // rather than leaving an unlabelled image to a screen reader.
              semanticLabel: bird.species,
            ),
            Visibility(
              visible: _showOfferDetails,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              maintainInteractivity: false,
              child: _OfferDetails(item: item, accent: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// The offer content that normally fills the card. Kept in the tree and
/// hidden by [_BirdCard]; unchanged otherwise.
class _OfferDetails extends StatelessWidget {
  const _OfferDetails({required this.item, required this.accent});

  final MobiusItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final softTint = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      Colors.white,
    );

    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: softTint,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              item.code ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.logo ?? Icons.flutter_dash, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            item.provider ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.accountNumber ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
          ),
          const SizedBox(height: 18),
          Text(
            'Bill Amount',
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.billAmount ?? '',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Example header with a live "Reward ends in HH:MM:SS Hrs" countdown.
class _DemoHeader extends StatefulWidget {
  const _DemoHeader();

  @override
  State<_DemoHeader> createState() => _DemoHeaderState();
}

class _DemoHeaderState extends State<_DemoHeader> {
  late int _remainingSeconds;
  Timer? _ticker;

  static const Color _accent = Color(0xFFC2185B);

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 12 * 3600 + 24 * 60 + 30;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          const Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
              children: [
                TextSpan(text: 'Get '),
                TextSpan(text: '₹20 Cashback'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unlock instant cashback on your\nnext payment',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8C8C8C),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: _accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  const TextSpan(text: 'Reward ends in '),
                  TextSpan(
                    text: '$_formattedTime ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: 'Hrs'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHint extends StatelessWidget {
  const _DragHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.keyboard_double_arrow_down,
          size: 28,
          color: const Color(0xFFC2185B).withValues(alpha: 0.6),
        ),
        const SizedBox(height: 6),
        const Text(
          'Drag down to Claim the Offer',
          style: TextStyle(
            color: Color(0xFF6B6B6B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Destination screen after a claim: the bird behind the card.
class _ClaimedDestinationPage extends StatelessWidget {
  const _ClaimedDestinationPage({required this.item});

  final MobiusItem item;

  @override
  Widget build(BuildContext context) {
    final bird = item.data! as _Bird;
    final color = item.color ?? const Color(0xFFE91E63);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                bird.species,
                style: const TextStyle(
                  // Material 3's FlexibleSpaceBar styles its title with
                  // titleLarge and ignores SliverAppBar.foregroundColor, so
                  // the colour has to be set here or the name renders dark
                  // on a dark photograph.
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    bird.asset,
                    fit: BoxFit.cover,
                    semanticLabel: bird.species,
                  ),
                  // Keeps the title legible over a bright photo.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  bird.scientificName,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.public,
                  label: 'Found in',
                  value: bird.range,
                  color: color,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.local_offer_outlined,
                  label: 'Claimed with',
                  value: bird.code,
                  color: color,
                ),
                const SizedBox(height: 24),
                Text(
                  bird.fact,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
                const SizedBox(height: 28),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      color.withValues(alpha: 0.08),
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          // The accent really is this photograph's colour.
                          child: const Icon(
                            Icons.palette_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This screen is tinted with the dominant colour '
                            'of the photo above, read from the image at run '
                            'time.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.black.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Photograph by ${bird.photographer} · public domain (CC0) '
                  'via Wikimedia Commons. See assets/birds/CREDITS.md.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled fact on the details screen.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          '$label  ',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8A8A8A),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ),
      ],
    );
  }
}
