import 'package:flutter/material.dart';

import '../models/owner_permission_member.dart';
import '../services/owner_permission_service.dart';

class OwnerPermissionManagementPage extends StatefulWidget {
  const OwnerPermissionManagementPage({super.key});

  @override
  State<OwnerPermissionManagementPage> createState() =>
      _OwnerPermissionManagementPageState();
}

class _OwnerPermissionManagementPageState
    extends State<OwnerPermissionManagementPage> {
  final OwnerPermissionService _service = OwnerPermissionService();
  final Set<String> _updatingUserIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  List<OwnerPermissionMember> _searchResults = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateRole(
    OwnerPermissionMember member,
    OwnerPermissionRole role,
  ) async {
    if (_updatingUserIds.contains(member.id)) return;
    setState(() => _updatingUserIds.add(member.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.updateRole(userId: member.id, role: role);
      if (!mounted) return;
      final successMessage = role == OwnerPermissionRole.none
          ? '${member.name} さんの権限を解除しました'
          : '${member.name} さんを${_roleLabel(role)}に更新しました';
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      _updateLocalSearchResult(member.id, role);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${member.name} さんの権限更新に失敗しました'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingUserIds.remove(member.id));
      }
    }
  }

  Future<void> _searchMembers() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー名を入力してください')),
      );
      return;
    }
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
    });
    try {
      final results = await _service.searchMembersByName(keyword);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchError = 'ユーザーの検索に失敗しました');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = const [];
      _hasSearched = false;
      _searchError = null;
    });
  }

  void _updateLocalSearchResult(String userId, OwnerPermissionRole role) {
    final index = _searchResults.indexWhere((member) => member.id == userId);
    if (index == -1) return;
    final shouldBeOwner = role == OwnerPermissionRole.owner;
    final shouldBeSubOwner = role == OwnerPermissionRole.subOwner;
    final updated = _searchResults[index].copyWith(
      isOwner: shouldBeOwner,
      isSubOwner: shouldBeSubOwner,
    );
    setState(() {
      final mutable = List<OwnerPermissionMember>.from(_searchResults);
      mutable[index] = updated;
      _searchResults = mutable;
    });
  }

  Widget _buildSearchCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ユーザーを検索',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '名前で一般ユーザーを検索して権限を付与できます。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'ユーザー名',
                hintText: '例: 田中',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchMembers(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSearching ? null : _searchMembers,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isSearching ? '検索中...' : '検索する'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed:
                      _searchController.text.isEmpty ? null : _clearSearch,
                  child: const Text('クリア'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_searchError != null)
              Text(
                _searchError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else if (_hasSearched && !_isSearching && _searchResults.isEmpty)
              Text(
                '該当するユーザーが見つかりませんでした',
                style: theme.textTheme.bodyMedium,
              )
            else if (_searchResults.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '検索結果',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._searchResults.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OwnerPermissionTile(
                        member: member,
                        isUpdating: _updatingUserIds.contains(member.id),
                        onRoleChanged: (role) => _updateRole(member, role),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(OwnerPermissionRole role) {
    switch (role) {
      case OwnerPermissionRole.owner:
        return 'オーナー';
      case OwnerPermissionRole.subOwner:
        return 'サブオーナー';
      case OwnerPermissionRole.none:
        return '解除';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('オーナー権限管理'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSearchCard(context),
          const SizedBox(height: 32),
          StreamBuilder<List<OwnerPermissionMember>>(
            stream: _service.watchPrivilegedMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '権限情報の取得に失敗しました',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }

              final members =
                  snapshot.data ?? const <OwnerPermissionMember>[];
              final owners = members
                  .where((member) => member.isOwner)
                  .toList(growable: false);
              final subOwners = members
                  .where((member) => member.isSubOwner)
                  .toList(growable: false);

              if (owners.isEmpty && subOwners.isEmpty) {
                return Center(
                  child: Text(
                    'オーナー・サブオーナーが登録されていません',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OwnerPermissionSection(
                    title: 'オーナー',
                    members: owners,
                    updatingUserIds: _updatingUserIds,
                    onRoleChanged: (member, role) => _updateRole(member, role),
                  ),
                  const SizedBox(height: 32),
                  _OwnerPermissionSection(
                    title: 'サブオーナー',
                    members: subOwners,
                    updatingUserIds: _updatingUserIds,
                    onRoleChanged: (member, role) => _updateRole(member, role),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OwnerPermissionSection extends StatelessWidget {
  const _OwnerPermissionSection({
    required this.title,
    required this.members,
    required this.updatingUserIds,
    required this.onRoleChanged,
  });

  final String title;
  final List<OwnerPermissionMember> members;
  final Set<String> updatingUserIds;
  final void Function(OwnerPermissionMember member, OwnerPermissionRole role)
      onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${title}は登録されていません',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          ...members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OwnerPermissionTile(
                member: member,
                isUpdating: updatingUserIds.contains(member.id),
                onRoleChanged: (role) => onRoleChanged(member, role),
              ),
            ),
          ),
      ],
    );
  }
}

class _OwnerPermissionTile extends StatelessWidget {
  const _OwnerPermissionTile({
    required this.member,
    required this.isUpdating,
    required this.onRoleChanged,
  });

  final OwnerPermissionMember member;
  final bool isUpdating;
  final ValueChanged<OwnerPermissionRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dropdown = DropdownButton<OwnerPermissionRole>(
      value: member.role,
      items: const [
        DropdownMenuItem(
          value: OwnerPermissionRole.owner,
          child: Text('オーナー'),
        ),
        DropdownMenuItem(
          value: OwnerPermissionRole.subOwner,
          child: Text('サブオーナー'),
        ),
        DropdownMenuItem(
          value: OwnerPermissionRole.none,
          child: Text('解除する'),
        ),
      ],
      onChanged: isUpdating ? null : (role) {
        if (role != null) onRoleChanged(role);
      },
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            member.name.isNotEmpty ? member.name.substring(0, 1) : '？',
            style: theme.textTheme.titleMedium,
          ),
        ),
        title: Text(
          member.name,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          member.email.isEmpty ? 'メールアドレス未登録' : member.email,
        ),
        trailing: isUpdating
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : dropdown,
      ),
    );
  }
}
