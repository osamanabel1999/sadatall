import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../screens/offers/offers_screen.dart';

/// Talabat-style auto-scrolling banner carousel on the home screen, fed by
/// the same admin-managed announcements the "عروض" tab already lists
/// (GET /announcements/public?audience=user) — no new backend/admin work
/// needed, this just gives them a second, more prominent surface.
class AdCarousel extends StatefulWidget {
  const AdCarousel({super.key});

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _autoScrollTimer;

  List<Map<String, dynamic>> _ads = [];
  int _currentPage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await _apiService.getAnnouncements();
    if (!mounted) return;
    if (result.success && result.data != null) {
      final data = result.data['data'] ?? result.data;
      final list = (data['announcements'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .where((a) => (a['image_url'] as String?)?.isNotEmpty == true)
          .toList();
      setState(() {
        _ads = list;
        _loading = false;
      });
      if (_ads.length > 1) _startAutoScroll();
    } else {
      setState(() => _loading = false);
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _ads.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Decorative content — stay silent on loading/empty/error rather than
    // showing spinners or error states on the home screen.
    if (_loading || _ads.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _ads.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) => _AdCard(data: _ads[index]),
            ),
          ),
          if (_ads.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _ads.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentPage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _currentPage ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AdCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['image_url'] as String?;
    final title = data['title'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OffersScreen()));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.grey[200]),
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                ),
              // Subtle gradient so a title is always legible over any image.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 24, 14, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                    ),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
