import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobius_carousel/mobius_carousel.dart';

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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<MobiusItem> _items = [
    MobiusItem(
      code: 'AQUA20',
      provider: 'Aquaflow Co.',
      accountNumber: '#100000000001',
      billAmount: '₹1,420',
      logo: Icons.water_drop,
      color: Color(0xFF2D67E0),
    ),
    MobiusItem(
      code: 'VOLT24',
      provider: 'Voltline Power',
      accountNumber: '#100000000002',
      billAmount: '₹30,200',
      logo: Icons.electric_bolt,
      color: Color(0xFFE91E63),
    ),
    MobiusItem(
      code: 'FLAME24',
      provider: 'Blueflame Gas',
      accountNumber: '#100000000003',
      billAmount: '₹2,850',
      logo: Icons.local_fire_department,
      color: Color(0xFFE0A800),
    ),
    MobiusItem(
      code: 'SKY50',
      provider: 'Skywave Mobile',
      accountNumber: '#100000000004',
      billAmount: '₹899',
      logo: Icons.sim_card,
      color: Color(0xFF7B61FF),
    ),
    MobiusItem(
      code: 'HELIX100',
      provider: 'Helix Energy',
      accountNumber: '#100000000005',
      billAmount: '₹4,300',
      logo: Icons.bolt,
      color: Color(0xFF00B894),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MobiusCarousel(
      items: _items,
      header: const _DemoHeader(),
      footer: const _DragHint(),
      rippleStyle: MobiusRippleStyle.semiCircle,
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

class _ClaimedDestinationPage extends StatelessWidget {
  final MobiusItem item;
  const _ClaimedDestinationPage({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? const Color(0xFFE91E63);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer Details'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.logo ?? Icons.local_offer, color: color, size: 64),
              const SizedBox(height: 16),
              Text(
                item.provider ?? '',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.accountNumber ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Text(
                item.billAmount ?? '',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Code: ${item.code ?? ''}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
