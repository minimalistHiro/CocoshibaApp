import 'package:flutter/material.dart';

import '../models/menu_item.dart';
import '../services/menu_service.dart';
import 'menu_form_page.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key});

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage>
    with SingleTickerProviderStateMixin {
  final MenuService _menuService = MenuService();
  late final TabController _tabController;
  final Map<MenuCategory, List<String>> _overrideOrderIds = {};
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: MenuCategory.values.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

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

  List<MenuItem> _sortedMenusForCategory(
    List<MenuItem> menus,
    MenuCategory category,
  ) {
    final categoryMenus =
        menus.where((menu) => menu.category == category).toList()
          ..sort((a, b) {
            final aOrder =
                a.orderIndex ?? (a.createdAt?.millisecondsSinceEpoch ?? 0);
            final bOrder =
                b.orderIndex ?? (b.createdAt?.millisecondsSinceEpoch ?? 0);
            if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            final aCreated = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bCreated = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return aCreated.compareTo(bCreated);
          });

    final overrideIds = _overrideOrderIds[category];
    if (overrideIds == null) return categoryMenus;

    final menuById = {
      for (final menu in categoryMenus) menu.id: menu,
    };
    final reordered = <MenuItem>[];
    for (final id in overrideIds) {
      final menu = menuById[id];
      if (menu != null) reordered.add(menu);
    }
    for (final menu in categoryMenus) {
      if (!overrideIds.contains(menu.id)) {
        reordered.add(menu);
      }
    }
    return reordered;
  }

  Future<void> _handleReorder({
    required MenuCategory category,
    required List<MenuItem> menus,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final reordered = List<MenuItem>.from(menus);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    setState(() {
      _overrideOrderIds[category] =
          reordered.map((menu) => menu.id).toList(growable: false);
      _isReordering = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _menuService.updateMenuOrder(
        category: category,
        menus: reordered,
      );
      if (!mounted) return;
      setState(() {
        _overrideOrderIds.remove(category);
        _isReordering = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _overrideOrderIds.remove(category);
        _isReordering = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('並び替えの保存に失敗しました')),
      );
    }
  }

  Widget _buildFilteredList(List<MenuItem> menus) {
    final selectedCategory = MenuCategory.values[_tabController.index];
    final filteredMenus = _sortedMenusForCategory(menus, selectedCategory);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: MenuCategory.values
              .map((category) => Tab(text: category.label))
              .toList(),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filteredMenus.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_outlined,
                          size: 64, color: Colors.grey.shade500),
                      const SizedBox(height: 12),
                      Text('${selectedCategory.label} のメニューはまだありません'),
                    ],
                  ),
                )
              : ReorderableListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  onReorder: (oldIndex, newIndex) => _handleReorder(
                    category: selectedCategory,
                    menus: filteredMenus,
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  ),
                  children: [
                    for (var index = 0; index < filteredMenus.length; index++)
                      Padding(
                        key: ValueKey(filteredMenus[index].id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildMenuCard(filteredMenus[index]),
                      ),
                  ],
                ),
        ),
      ],
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
      body: Stack(
        children: [
          StreamBuilder<List<MenuItem>>(
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

              return _buildFilteredList(menus);
            },
          ),
          if (_isReordering)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black45,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
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
