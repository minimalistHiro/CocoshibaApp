import 'package:flutter/material.dart';

import '../models/campaign.dart';
import '../services/campaign_service.dart';
import 'campaign_form_page.dart';

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  final CampaignService _campaignService = CampaignService();
  late final Stream<List<Campaign>> _campaignsStream =
      _campaignService.watchCampaigns();

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CampaignFormPage()),
    );
  }

  void _openEdit(Campaign campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CampaignFormPage(campaign: campaign)),
    );
  }

  String _formatPeriod(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return '未設定';
    }
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final startLabel =
        '${start.year}/${twoDigits(start.month)}/${twoDigits(start.day)} '
        '${twoDigits(start.hour)}:${twoDigits(start.minute)}';
    final endLabel =
        '${end.year}/${twoDigits(end.month)}/${twoDigits(end.day)} '
        '${twoDigits(end.hour)}:${twoDigits(end.minute)}';
    return '$startLabel 〜 $endLabel';
  }

  Widget _buildCampaignCard(Campaign campaign) {
    return Card(
      child: ListTile(
        onTap: () => _openEdit(campaign),
        leading: _CampaignThumbnail(imageUrl: campaign.imageUrl),
        title: Text(
          campaign.title.isEmpty ? '無題のキャンペーン' : campaign.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '掲載期間: ${_formatPeriod(campaign.displayStart, campaign.displayEnd)}',
              maxLines: 2,
            ),
            const SizedBox(height: 2),
            Text(
              '開催期間: ${_formatPeriod(campaign.eventStart, campaign.eventEnd)}',
              maxLines: 2,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('キャンペーン編集'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_circle_outline),
            color: Theme.of(context).colorScheme.primary,
            tooltip: '新規キャンペーン',
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Campaign>>(
          stream: _campaignsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StateMessage(
                message: 'キャンペーンを読み込めませんでした: ${snapshot.error}',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final campaigns = snapshot.data ?? const <Campaign>[];
            if (campaigns.isEmpty) {
              return const _StateMessage(
                message: '作成済みのキャンペーンがありません',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              itemCount: campaigns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _buildCampaignCard(campaigns[index]),
            );
          },
        ),
      ),
    );
  }
}

class _CampaignThumbnail extends StatelessWidget {
  const _CampaignThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: 64,
        child: AspectRatio(
          aspectRatio: 2 / 1,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Container(
                  color: Colors.blueGrey.shade50,
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: Colors.blueGrey,
                  ),
                )
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.blueGrey.shade50,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
