import 'package:flutter/material.dart';

import '../models/menu_item.dart';
import '../services/menu_service.dart';

class MenuListPage extends StatefulWidget {
  const MenuListPage({super.key});

  @override
  State<MenuListPage> createState() => _MenuListPageState();
}

class _MenuListPageState extends State<MenuListPage>
    with SingleTickerProviderStateMixin {
  final MenuService _menuService = MenuService();
  late final Stream<List<MenuItem>> _menusStream;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _menusStream = _menuService.watchMenus();
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

  Widget _buildMenuTile(BuildContext context, MenuItem menu) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _MenuImage(imageUrl: menu.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menu.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  menu.category.label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${menu.price}円',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredGrid(List<MenuItem> menus) {
    final selectedCategory = MenuCategory.values[_tabController.index];
    final filteredMenus =
        menus.where((menu) => menu.category == selectedCategory).toList()
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
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: filteredMenus.length,
                  itemBuilder: (context, index) =>
                      _buildMenuTile(context, filteredMenus[index]),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メニュー'),
      ),
      body: StreamBuilder<List<MenuItem>>(
        stream: _menusStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !(snapshot.hasData && (snapshot.data?.isNotEmpty ?? false))) {
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
                  const Text('メニューがまだ登録されていません'),
                ],
              ),
            );
          }

          return _buildFilteredGrid(menus);
        },
      ),
    );
  }
}

class _MenuImage extends StatelessWidget {
  const _MenuImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey.shade500,
          size: 36,
        ),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade500,
          size: 36,
        ),
      ),
    );
  }
}
