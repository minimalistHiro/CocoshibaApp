import 'package:flutter/material.dart';

import '../models/menu_item.dart';
import '../services/menu_service.dart';
import 'menu_form_page.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key});

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  final MenuService _menuService = MenuService();

  Future<void> _openForm({MenuItem? menu}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuFormPage(menu: menu),
      ),
    );
  }

  Future<void> _confirmDelete(MenuItem menu) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text('${menu.name} を削除しますか？'),
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
      await _menuService.deleteMenu(
        menuId: menu.id,
        imageUrl: menu.imageUrl,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${menu.name}を削除しました')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('メニューの削除に失敗しました')),
      );
    }
  }

  Widget _buildMenuCard(MenuItem menu) {
    final priceText = '${menu.price}円';
    return Card(
      child: ListTile(
        onTap: () => _openForm(menu: menu),
        leading: _MenuThumbnail(imageUrl: menu.imageUrl),
        title: Text(menu.name),
        subtitle: Text('${menu.category.label} ・ $priceText'),
        trailing: PopupMenuButton<_MenuAction>(
          onSelected: (action) {
            switch (action) {
              case _MenuAction.edit:
                _openForm(menu: menu);
                break;
              case _MenuAction.delete:
                _confirmDelete(menu);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _MenuAction.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('編集'),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.delete,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メニュー編集'),
        actions: [
          IconButton(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle_outline),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'メニューを追加',
          ),
        ],
      ),
      body: StreamBuilder<List<MenuItem>>(
        stream: _menuService.watchMenus(),
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

          final menus = snapshot.data ?? [];
          if (menus.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu_outlined,
                      size: 64, color: Colors.grey.shade500),
                  const SizedBox(height: 16),
                  const Text('登録されたメニューがありません'),
                  const SizedBox(height: 8),
                  const Text('右上のプラスボタンからメニューを追加しましょう'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemBuilder: (context, index) => _buildMenuCard(menus[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: menus.length,
          );
        },
      ),
    );
  }
}

class _MenuThumbnail extends StatelessWidget {
  const _MenuThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: AspectRatio(
          aspectRatio: 1,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Container(
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_not_supported_outlined,
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

enum _MenuAction { edit, delete }
