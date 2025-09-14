import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart';
import '../controllers/cache_management_controller.dart';

class CacheManagementView extends StatefulWidget {
  const CacheManagementView({super.key});

  @override
  CacheManagementViewState createState() => CacheManagementViewState();
}

class CacheManagementViewState extends State<CacheManagementView> {
  // 页码控制器
  final TextEditingController _pageController =
      TextEditingController(text: '1');

  // 筛选相关状态
  bool _showFilters = false;
  String _branchFilter = '全部';
  String _platformFilter = '全部';
  String _typeFilter = '全部';
  String _configurationFilter = '全部';
  String _libraryFilter = '全部';

  // 当前应用的筛选条件
  Map<String, dynamic> _currentFilters = {};
  bool _isFiltering = false;

  @override
  void initState() {
    super.initState();
    _pageController.text = '1';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 页码刷新方法
  Future<void> _loadPageData(int page) async {
    setState(() {
      _isFiltering = true;
    });

    try {
      final controller = Get.find<CacheManagementController>();
      await controller.loadCacheListByPage(page, 20, _currentFilters);
      _syncPageController();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFiltering = false;
        });
      }
    }
  }

  // 同步页码输入框
  void _syncPageController() {
    final controller = Get.find<CacheManagementController>();
    final currentPage = controller.currentPage.value;
    if (_pageController.text != currentPage.toString()) {
      _pageController.text = currentPage.toString();
    }
  }

  // 跳转到指定页码
  Future<void> _goToPage() async {
    final pageText = _pageController.text.trim();
    if (pageText.isEmpty) return;

    final page = int.tryParse(pageText);
    if (page == null || page < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的页码（大于0的整数）'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final controller = Get.find<CacheManagementController>();
    final totalPages = controller.totalPages.value;

    if (totalPages > 0 && page > totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('页码超出范围，最大页码为 $totalPages'),
          backgroundColor: Colors.orange,
        ),
      );
      _pageController.text = controller.currentPage.value.toString();
      return;
    }

    await _loadPageData(page);
  }

  // 应用筛选条件
  Future<void> _applyFilters() async {
    setState(() {
      _isFiltering = true;
    });

    final filters = <String, dynamic>{};

    if (_branchFilter != '全部') {
      filters['branch'] = _branchFilter;
    }

    if (_platformFilter != '全部') {
      filters['platform'] = _platformFilter;
    }

    if (_typeFilter != '全部') {
      filters['type'] = _typeFilter;
    }

    if (_configurationFilter != '全部') {
      filters['configuration'] = _configurationFilter;
    }

    if (_libraryFilter != '全部') {
      filters['library'] = _libraryFilter;
    }

    _currentFilters = filters;

    try {
      await _loadPageData(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('筛选失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFiltering = false;
        });
      }
    }
  }

  // 清空筛选条件
  Future<void> _clearFilters() async {
    setState(() {
      _branchFilter = '全部';
      _platformFilter = '全部';
      _typeFilter = '全部';
      _configurationFilter = '全部';
      _libraryFilter = '全部';
      _currentFilters = {};
      _isFiltering = true;
    });

    try {
      await _loadPageData(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重新加载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFiltering = false;
        });
      }
    }
  }

  // 检查是否有筛选条件
  bool _hasActiveFilters() {
    return _currentFilters.isNotEmpty;
  }

  // 显示确认对话框
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 格式化时间显示
  String _formatTime(String timeString) {
    if (timeString.isEmpty) return '未知时间';

    try {
      // 尝试解析时间字符串
      DateTime? dateTime;

      // 如果是时间戳（毫秒）
      if (RegExp(r'^\d+$').hasMatch(timeString)) {
        final timestamp = int.tryParse(timeString);
        if (timestamp != null) {
          // 判断是秒还是毫秒时间戳
          if (timestamp > 1000000000000) {
            // 毫秒时间戳
            dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else {
            // 秒时间戳
            dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        }
      } else {
        // 尝试解析ISO格式时间
        dateTime = DateTime.tryParse(timeString);
      }

      if (dateTime != null) {
        // 转换为本地时间
        final localTime = dateTime.toLocal();
        return '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // 解析失败，返回原始字符串
    }

    return timeString;
  }

  // 构建筛选面板
  Widget _buildFilterPanel(int totalCount) {
    final controller = Get.find<CacheManagementController>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '筛选条件',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_hasActiveFilters())
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已筛选',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFilterDropdownRow(controller),
          const SizedBox(height: 8),
          _buildFilterActionRow(totalCount),
          // 显示筛选状态提示
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 8),
            _buildFilterStatusHint(),
          ],
          // 显示复制使用提示
          const SizedBox(height: 8),
          _buildCopyHint(),
        ],
      ),
    );
  }

  // 构建复制使用提示
  Widget _buildCopyHint() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'macOS 原生复制功能',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '双击选中文本，然后使用 Cmd+C 复制',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建筛选状态提示
  Widget _buildFilterStatusHint() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '筛选选项已根据当前条件自动更新，只显示有效的选项',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 更新筛选选项
  void _updateFilterOptions() {
    final controller = Get.find<CacheManagementController>();

    // 构建当前筛选条件
    final Map<String, dynamic> currentFilters = {};

    if (_platformFilter != '全部') {
      currentFilters['platform'] = _platformFilter;
    }
    if (_typeFilter != '全部') {
      currentFilters['type'] = _typeFilter;
    }
    if (_configurationFilter != '全部') {
      currentFilters['configuration'] = _configurationFilter;
    }
    if (_libraryFilter != '全部') {
      currentFilters['library'] = _libraryFilter;
    }
    if (_branchFilter != '全部') {
      currentFilters['branch'] = _branchFilter;
    }

    // 更新控制器的过滤选项（现在保持所有选项可见）
    controller.updateFilteredOptions(currentFilters);
  }

  // 构建筛选下拉框行
  Widget _buildFilterDropdownRow(CacheManagementController controller) {
    return Column(
      children: [
        // 第一行：平台、类型、配置、库
        Row(
          children: [
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                    value: _platformFilter,
                    decoration: const InputDecoration(
                      labelText: '平台',
                      prefixIcon: Icon(Icons.devices),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: controller.filteredPlatformOptions
                        .map((platform) => DropdownMenuItem(
                              value: platform,
                              child: Text(platform),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _platformFilter = value ?? '全部';
                      });
                      _updateFilterOptions();
                    },
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                    value: _typeFilter,
                    decoration: const InputDecoration(
                      labelText: '类型',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: controller.filteredTypeOptions
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _typeFilter = value ?? '全部';
                      });
                      _updateFilterOptions();
                    },
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                    value: _configurationFilter,
                    decoration: const InputDecoration(
                      labelText: '配置',
                      prefixIcon: Icon(Icons.settings),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: controller.filteredConfigurationOptions
                        .map((config) => DropdownMenuItem(
                              value: config,
                              child: Text(config),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _configurationFilter = value ?? '全部';
                      });
                      _updateFilterOptions();
                    },
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                    value: _libraryFilter,
                    decoration: const InputDecoration(
                      labelText: '库',
                      prefixIcon: Icon(Icons.library_books),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: controller.filteredLibraryOptions
                        .map((library) => DropdownMenuItem(
                              value: library,
                              child: Text(library),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _libraryFilter = value ?? '全部';
                      });
                      _updateFilterOptions();
                    },
                  )),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 第二行：分支
        Row(
          children: [
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                    value: _branchFilter,
                    decoration: const InputDecoration(
                      labelText: '分支',
                      prefixIcon: Icon(Icons.account_tree),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: controller.filteredBranchOptions
                        .map((branch) => DropdownMenuItem(
                              value: branch,
                              child: Text(branch),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _branchFilter = value ?? '全部';
                      });
                      _updateFilterOptions();
                    },
                  )),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // 占位符
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // 占位符
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // 占位符
          ],
        ),
      ],
    );
  }

  // 构建筛选操作按钮行
  Widget _buildFilterActionRow(int totalCount) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isFiltering ? null : _applyFilters,
          icon: _isFiltering
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search, size: 16),
          label: Text(_isFiltering ? '筛选中...' : '筛选'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 32),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _isFiltering ? null : _clearFilters,
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('清空'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 32),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hasActiveFilters()
                ? Colors.orange.shade50
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hasActiveFilters()
                  ? Colors.orange.shade300
                  : Colors.blue.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _hasActiveFilters() ? Icons.filter_alt : Icons.list,
                size: 16,
                color: _hasActiveFilters()
                    ? Colors.orange.shade700
                    : Colors.blue.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                _hasActiveFilters()
                    ? '筛选结果: $totalCount 条'
                    : '共 $totalCount 条记录',
                style: TextStyle(
                  fontSize: 12,
                  color: _hasActiveFilters()
                      ? Colors.orange.shade700
                      : Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建缓存记录卡片
  Widget _buildCacheCard(Document document, int originalIndex,
      CacheManagementController controller) {
    final data = document.data;
    final platform = data['platform'] ?? '未知';
    final type = data['type'] ?? '未知';
    final configuration = data['configuration'] ?? '未知';
    final library = data['library'] ?? '未知';
    final branch = data['branch'] ?? '未知';
    final buildId = data['build_id'] ?? 0;
    final fileId = data['file_id'] ?? '';
    final commitHash = data['commit_hash'] ?? '';
    final commitTime = data['commit_time'] ?? '';
    // 判断环境类型
    // 优先使用is_store字段，如果没有则根据其他字段判断
    bool isStore = false;
    if (data['is_store'] != null) {
      isStore = data['is_store'] == true || data['is_store'] == 'true';
    } else {
      // 如果没有is_store字段，尝试从其他字段判断
      final environment = data['environment'] ?? data['env'] ?? '';
      final branch = data['branch'] ?? '';

      // 根据分支名判断：main/master分支通常是生产环境
      if (branch.toLowerCase() == 'main' || branch.toLowerCase() == 'master') {
        isStore = true;
      }
      // 根据environment字段判断
      else if (environment.toLowerCase().contains('prod') ||
          environment.toLowerCase().contains('production')) {
        isStore = true;
      }
    }

    // 获取创建时间
    final createdAt = document.$createdAt;
    final formattedCreatedAt = _formatTime(createdAt.toString());

    return Obx(() {
      final isSelected = controller.selectedItems.contains(document.$id);

      return Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 2),
        color: isSelected ? Colors.blue.shade50 : null,
        child: InkWell(
          onTap: () {
            if (controller.isMultiSelectMode.value) {
              controller.toggleItemSelection(document.$id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 多选模式下的选择框
                if (controller.isMultiSelectMode.value) ...[
                  Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          controller.toggleItemSelection(document.$id);
                        },
                      ),
                      Expanded(
                        child: SelectableText(
                          '$platform - $type',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          enableInteractiveSelection: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ] else ...[
                  // 头部信息
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              '$platform - $type',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              enableInteractiveSelection: true,
                            ),
                            const SizedBox(height: 1),
                            SelectableText(
                              '分支: $branch | 构建ID: $buildId',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              enableInteractiveSelection: true,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isStore
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isStore
                                ? Colors.green.shade300
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: SelectableText(
                          isStore ? '生产环境' : '测试环境',
                          style: TextStyle(
                            fontSize: 8,
                            color: isStore
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          enableInteractiveSelection: true,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 2),

                // 详细信息 - 使用更紧凑的布局
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInfoItem(
                          '配置', configuration, Icons.settings),
                    ),
                    Expanded(
                      child: _buildCompactInfoItem(
                          '库', library, Icons.library_books),
                    ),
                    Expanded(
                      child: _buildCompactInfoItem(
                          '分支', branch, Icons.account_tree),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                // 第二行信息
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInfoItem(
                          '构建ID', buildId.toString(), Icons.build),
                    ),
                    Expanded(
                      child: _buildCompactInfoItem(
                          '创建时间', formattedCreatedAt, Icons.schedule),
                    ),
                    const Expanded(child: SizedBox()), // 占位符
                  ],
                ),

                // 可选信息（只在有内容时显示）
                if (commitHash.isNotEmpty ||
                    commitTime.isNotEmpty ||
                    fileId.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (commitHash.isNotEmpty)
                        Expanded(
                          child: _buildCompactInfoItem(
                              '提交哈希', commitHash, Icons.code),
                        ),
                      if (commitTime.isNotEmpty)
                        Expanded(
                          child: _buildCompactInfoItem('提交时间',
                              _formatTime(commitTime), Icons.access_time),
                        ),
                      if (fileId.isNotEmpty)
                        Expanded(
                          child: _buildCompactInfoItem(
                              '文件ID', fileId, Icons.file_copy),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 2),

                // 操作按钮（非多选模式下显示）
                if (!controller.isMultiSelectMode.value) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _handleDelete(originalIndex, controller, document),
                        icon: const Icon(Icons.delete, size: 14),
                        label: const Text('删除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 24),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  // 构建紧凑信息项
  Widget _buildCompactInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade600,
                ),
              ),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                enableInteractiveSelection: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建缓存记录卡片（保留作为备用）
  // 处理删除操作
  Future<void> _handleDelete(int originalIndex,
      CacheManagementController controller, Document document) async {
    final data = document.data;
    final platform = data['platform'] ?? '未知';
    final branch = data['branch'] ?? '未知';
    final fileId = data['file_id'] ?? '';

    final confirmed = await _showConfirmDialog(
      title: '确认删除',
      content: '确定要删除 $platform 平台的 $branch 分支缓存记录吗？\n\n这将同时删除数据库记录和关联的文件。',
    );

    if (confirmed == true) {
      try {
        await controller.deleteCacheRecord(document.$id, fileId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 处理批量删除操作
  Future<void> _handleBatchDelete(CacheManagementController controller) async {
    final selectedCount = controller.selectedCount;

    final confirmed = await _showConfirmDialog(
      title: '确认批量删除',
      content:
          '确定要删除选中的 $selectedCount 条缓存记录吗？\n\n这将同时删除数据库记录和关联的文件。\n\n此操作不可撤销！',
    );

    if (confirmed == true) {
      try {
        await controller.deleteSelectedRecords();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('批量删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 构建页码控制面板
  Widget _buildPaginationPanel(CacheManagementController controller) {
    return Obx(() {
      final currentPage = controller.currentPage.value;
      final totalPages = controller.totalPages.value;
      final totalCount = controller.totalCount.value;

      if (_pageController.text != currentPage.toString()) {
        _pageController.text = currentPage.toString();
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            Text(
              '第 $currentPage 页，共 $totalPages 页（$totalCount 条记录）',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '页码',
                  helperText: totalPages > 0 ? '1-$totalPages' : null,
                  helperStyle: const TextStyle(fontSize: 10),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onSubmitted: (_) => _goToPage(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isFiltering ? null : _goToPage,
              child: const Text('跳转'),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: (_isFiltering || currentPage <= 1)
                  ? null
                  : () {
                      _pageController.text = (currentPage - 1).toString();
                      _goToPage();
                    },
              icon: const Icon(Icons.chevron_left),
              label: const Text('上一页'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: (_isFiltering || currentPage >= totalPages)
                  ? null
                  : () {
                      _pageController.text = (currentPage + 1).toString();
                      _goToPage();
                    },
              icon: const Icon(Icons.chevron_right),
              label: const Text('下一页'),
            ),
          ],
        ),
      );
    });
  }

  // 构建空状态
  Widget _buildEmptyState() {
    if (_hasActiveFilters()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            const Text(
              '没有找到符合筛选条件的缓存记录',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '请尝试调整筛选条件或清空筛选',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('清空筛选'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无缓存数据',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '缓存记录将在这里显示',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CacheManagementController>();
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final controller = Get.find<CacheManagementController>();
          if (controller.isMultiSelectMode.value) {
            return Text('已选择 ${controller.selectedCount} 项');
          }
          return const Text('缓存管理');
        }),
        centerTitle: true,
        leading: Obx(() {
          final controller = Get.find<CacheManagementController>();
          if (controller.isMultiSelectMode.value) {
            return IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                controller.toggleMultiSelectMode();
              },
              tooltip: '退出多选模式',
            );
          }
          return IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Get.back(),
          );
        }),
        actions: [
          Obx(() {
            final controller = Get.find<CacheManagementController>();
            if (controller.isMultiSelectMode.value) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      controller.isAllSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                    ),
                    onPressed: () {
                      if (controller.isAllSelected) {
                        controller.clearSelection();
                      } else {
                        controller.selectAllCurrentPage();
                      }
                    },
                    tooltip: controller.isAllSelected ? '取消全选' : '全选',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: controller.selectedCount > 0
                        ? () => _handleBatchDelete(controller)
                        : null,
                    tooltip: '批量删除',
                  ),
                ],
              );
            } else {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    onPressed: () {
                      controller.toggleMultiSelectMode();
                    },
                    tooltip: '多选模式',
                  ),
                  IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_list_off : Icons.filter_list,
                      color: _showFilters ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    tooltip: _showFilters ? '隐藏筛选' : '显示筛选',
                  ),
                ],
              );
            }
          }),
        ],
      ),
      body: Obx(() {
        final cacheRecords = controller.cacheList;
        final isLoading = controller.isLoading.value;

        return Column(
          children: [
            // 筛选面板
            if (_showFilters) _buildFilterPanel(cacheRecords.length),

            // 缓存记录列表
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: isLoading && cacheRecords.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              '加载中...',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : cacheRecords.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            itemCount: cacheRecords.length,
                            itemBuilder: (context, index) {
                              final document = cacheRecords[index];
                              final originalIndex =
                                  controller.cacheList.indexOf(document);
                              return _buildCacheCard(
                                  document, originalIndex, controller);
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 2),
                          ),
              ),
            ),

            // 页码控制面板
            if (cacheRecords.isNotEmpty) _buildPaginationPanel(controller),
          ],
        );
      }),
    );
  }
}
