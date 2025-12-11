import 'package:flutter/material.dart';

import '../models/home_page_content.dart';
import '../services/home_page_content_service.dart';
import 'home_page_content_form_page.dart';

class HomeScreenEditorPage extends StatefulWidget {
  const HomeScreenEditorPage({super.key});

  @override
  State<HomeScreenEditorPage> createState() => _HomeScreenEditorPageState();
}

class _HomeScreenEditorPageState extends State<HomeScreenEditorPage> {
  final HomePageContentService _contentService = HomePageContentService();

  Future<void> _openForm({HomePageContent? content}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomePageContentFormPage(content: content),
      ),
    );
  }

  Future<void> _confirmDelete(HomePageContent content) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text('「${content.title}」を削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  '削除する',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !shouldDelete) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _contentService.deleteContent(
        contentId: content.id,
        imageUrls: content.imageUrls,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('「${content.title}」を削除しました')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('削除に失敗しました')),
      );
    }
  }

  Widget _buildContentCard(HomePageContent content) {
    final metadata = _buildMetadata(content);
    return Card(
      child: ListTile(
        onTap: () => _openForm(content: content),
        leading: _ContentThumbnail(imageUrl: content.imageUrls.isNotEmpty
            ? content.imageUrls.first
            : null),
        title: Row(
          children: [
            Expanded(
              child: Text(
                content.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(content.genre.label),
              backgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (metadata != null) ...[
                Text(
                  metadata,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                content.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<_ContentAction>(
          onSelected: (action) {
            switch (action) {
              case _ContentAction.edit:
                _openForm(content: content);
                break;
              case _ContentAction.delete:
                _confirmDelete(content);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ContentAction.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('編集'),
              ),
            ),
            PopupMenuItem(
              value: _ContentAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('削除'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _buildMetadata(HomePageContent content) {
    switch (content.genre) {
      case HomePageGenre.sales:
        final price = content.price;
        if (price == null) return null;
        return '価格: ¥${_formatNumber(price)}';
      case HomePageGenre.event:
        final date = content.eventDate;
        if (date == null) return null;
        final start = content.startTimeLabel ?? '--:--';
        final end = content.endTimeLabel ?? '--:--';
        return '開催日: ${_formatDate(date)}  $start 〜 $end';
      case HomePageGenre.news:
        return null;
    }
  }

  String _formatNumber(int value) {
    final digits = value.toString().split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム画面編集'),
        actions: [
          IconButton(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            tooltip: '新規ページ',
          ),
        ],
      ),
      body: StreamBuilder<List<HomePageContent>>(
        stream: _contentService.watchContents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                label: const Text('読み込みに失敗しました。再試行'),
              ),
            );
          }

          final contents = snapshot.data ?? [];
          if (contents.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_carousel_outlined,
                      size: 64, color: Colors.grey.shade500),
                  const SizedBox(height: 16),
                  const Text('ホーム画面に表示するページがありません'),
                  const SizedBox(height: 8),
                  const Text('右上のプラスから新しいページを追加しましょう'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemBuilder: (context, index) => _buildContentCard(contents[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: contents.length,
          );
        },
      ),
    );
  }
}

class _ContentThumbnail extends StatelessWidget {
  const _ContentThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        height: 60,
        child: AspectRatio(
          aspectRatio: 1,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Container(
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.grey.shade500,
                  ),
                )
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

enum _ContentAction { edit, delete }
