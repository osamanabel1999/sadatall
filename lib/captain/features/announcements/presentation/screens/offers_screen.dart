import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/api_config.dart';

class CaptainOffersScreen extends StatefulWidget {
  const CaptainOffersScreen({super.key});

  @override
  State<CaptainOffersScreen> createState() => _CaptainOffersScreenState();
}

class _CaptainOffersScreenState extends State<CaptainOffersScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final baseUrl = ApiConfig.baseUrl;
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/announcements/public',
        queryParameters: {'page': '1', 'limit': '20', 'audience': 'captain'},
        options: Options(
          headers: {'X-Tenant-ID': 'SADAT'},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = response.data['data'];
      final list = (data['announcements'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (mounted) {
        setState(() {
          _announcements = list;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          final data = e.response?.data;
          _error = (data is Map ? (data['error'] ?? data['message']) : null) ??
              'حدث خطأ في تحميل العروض: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ في تحميل العروض: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عروض وأخبار')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _announcements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('لا توجد عروض أو أخبار حالياً',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _announcements.length,
                        itemBuilder: (_, i) =>
                            _AnnouncementCard(data: _announcements[i]),
                      ),
                    ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnnouncementCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['image_url'] as String?;
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final publishedAt = data['published_at'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(body,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 14)),
                if (publishedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(_formatDate(publishedAt),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[400])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
