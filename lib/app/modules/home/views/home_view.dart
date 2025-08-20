import 'package:darty_json_safe/darty_json_safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/models.dart';

import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  final TextEditingController _phoneController = TextEditingController();
  final Map<int, bool> _isExpanded = {}; // 重新添加展开状态管理
  final Map<int, bool> _isFullPublish = {};
  final Map<int, bool> _isTestEnvironment = {}; // 每个版本独立的环境状态

  // 滚动控制器，用于监听滚动事件
  final ScrollController _scrollController = ScrollController();

  // 筛选相关状态
  bool _showFilters = false;
  final TextEditingController _routeNameFilter = TextEditingController();
  final TextEditingController _phoneNumberFilter = TextEditingController();
  String _onlineStatusFilter = '全部'; // 全部、已上线、未上线
  String _environmentFilter = '全部'; // 全部、测试环境、正式环境

  // 当前应用的筛选条件
  Map<String, dynamic> _currentFilters = {};
  bool _isFiltering = false;

  @override
  void initState() {
    super.initState();
    // 添加滚动监听器
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _routeNameFilter.dispose();
    _phoneNumberFilter.dispose();
    _scrollController.dispose(); // 释放滚动控制器
    super.dispose();
  }

  // 滚动监听方法
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // 距离底部200像素时开始加载更多
      final controller = Get.find<HomeController>();
      controller.loadMoreVersions();
    }
  }

  // 应用筛选条件
  Future<void> _applyFilters() async {
    setState(() {
      _isFiltering = true;
    });

    // 构建筛选条件
    final filters = <String, dynamic>{};

    if (_routeNameFilter.text.isNotEmpty) {
      filters['routeName'] = _routeNameFilter.text.trim();
    }

    if (_phoneNumberFilter.text.isNotEmpty) {
      filters['phoneNumber'] = _phoneNumberFilter.text.trim();
    }

    if (_onlineStatusFilter != '全部') {
      filters['onlineStatus'] = _onlineStatusFilter;
    }

    if (_environmentFilter != '全部') {
      filters['environment'] = _environmentFilter;
    }

    // 保存当前筛选条件
    _currentFilters = filters;

    try {
      // 调用控制器进行筛选
      final controller = Get.find<HomeController>();
      await controller.filterVersions(filters);
    } catch (e) {
      // 处理错误
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
      _routeNameFilter.clear();
      _phoneNumberFilter.clear();
      _onlineStatusFilter = '全部';
      _environmentFilter = '全部';
      _currentFilters = {};
      _isFiltering = true;
    });

    try {
      // 清空筛选条件并重新加载数据
      final controller = Get.find<HomeController>();
      await controller.clearFilters();
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

  // 获取版本的环境状态
  bool _getVersionEnvironment(int originalIndex, Map<String, dynamic> data) {
    // 如果本地状态存在，使用本地状态
    if (_isTestEnvironment.containsKey(originalIndex)) {
      return _isTestEnvironment[originalIndex]!;
    }

    // 直接根据 is_store 判断环境
    // is_store = true 表示正式环境（全量）
    // is_store = false 表示测试环境（指定用户）
    final isStore = data['is_store'] ?? false;
    final isTestEnv = !isStore; // is_store 的反值
    _isTestEnvironment[originalIndex] = isTestEnv;
    return isTestEnv;
  }

  // 判断版本是否为全量模式
  bool _isVersionFullMode(Map<String, dynamic> data) {
    final allowPhones = (data['allow_phones'] as List<dynamic>? ?? []);

    // 如果手机号数组为空，则为全量模式
    if (allowPhones.isEmpty) {
      return true;
    }

    // 如果手机号数组不为空，检查 is_store 字段
    final isStore = data['is_store'] ?? false;
    return isStore;
  }

  // 显示确认对话框的通用方法
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

  // 创建状态标签的通用方法
  Widget _buildStatusChip({
    required bool isEnable,
    required bool versionIsTestEnvironment,
  }) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String text;

    if (!isEnable) {
      backgroundColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      textColor = Colors.grey.shade600;
      icon = Icons.pause_circle_outline;
      text = '未上线';
    } else if (versionIsTestEnvironment) {
      backgroundColor = Colors.blue.shade100;
      borderColor = Colors.blue.shade300;
      textColor = Colors.blue.shade600;
      icon = Icons.science;
      text = '测试环境';
    } else {
      backgroundColor = Colors.green.shade100;
      borderColor = Colors.green.shade300;
      textColor = Colors.green.shade600;
      icon = Icons.rocket_launch;
      text = '正式环境';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // 创建单个切换按钮的通用方法
  Widget _buildSingleToggleButton({
    required String activeLabel,
    required String inactiveLabel,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isActive
            ? activeColor.withOpacity(0.1)
            : inactiveColor.withOpacity(0.1),
        border: Border.all(
          color: isActive
              ? activeColor.withOpacity(0.3)
              : inactiveColor.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : inactiveIcon,
                size: 16,
                color: isActive ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 4),
              Text(
                isActive ? activeLabel : inactiveLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 获取卡片背景色的方法
  Color _getCardBackgroundColor(bool isEnable, bool versionIsTestEnvironment) {
    if (!isEnable) {
      return Colors.grey.shade50;
    } else if (versionIsTestEnvironment) {
      return Colors.blue.shade50;
    } else {
      return Colors.green.shade50;
    }
  }

  // 获取状态指示条颜色的方法
  Color _getStatusIndicatorColor(bool isEnable, bool versionIsTestEnvironment) {
    if (!isEnable) {
      return Colors.grey.shade400;
    } else if (versionIsTestEnvironment) {
      return Colors.blue.shade400;
    } else {
      return Colors.green.shade400;
    }
  }

  // 格式化时间的方法
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 构建筛选面板
  Widget _buildFilterPanel(int totalCount) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
          _buildFilterInputRow(),
          const SizedBox(height: 12),
          _buildFilterDropdownRow(),
          const SizedBox(height: 12),
          _buildFilterActionRow(totalCount),
        ],
      ),
    );
  }

  // 构建筛选输入框行
  Widget _buildFilterInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _routeNameFilter,
            decoration: const InputDecoration(
              labelText: '路由名称',
              hintText: '输入路由名称进行筛选',
              prefixIcon: Icon(Icons.route),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            // 移除 onChanged 实时筛选
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _phoneNumberFilter,
            decoration: const InputDecoration(
              labelText: '手机号',
              hintText: '输入手机号进行筛选',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            // 移除 onChanged 实时筛选
          ),
        ),
      ],
    );
  }

  // 构建筛选下拉框行
  Widget _buildFilterDropdownRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _onlineStatusFilter,
            decoration: const InputDecoration(
              labelText: '上线状态',
              prefixIcon: Icon(Icons.cloud),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ['全部', '已上线', '未上线']
                .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _onlineStatusFilter = value ?? '全部';
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _environmentFilter,
            decoration: const InputDecoration(
              labelText: '环境类型',
              prefixIcon: Icon(Icons.settings),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ['全部', '测试环境', '正式环境']
                .map((env) => DropdownMenuItem(
                      value: env,
                      child: Text(env),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _environmentFilter = value ?? '全部';
              });
            },
          ),
        ),
      ],
    );
  }

  // 构建筛选操作按钮行
  Widget _buildFilterActionRow(int totalCount) {
    return Row(
      children: [
        // 筛选按钮
        ElevatedButton.icon(
          onPressed: _isFiltering ? null : _applyFilters,
          icon: _isFiltering
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(_isFiltering ? '筛选中...' : '筛选'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),

        // 清空按钮
        OutlinedButton.icon(
          onPressed: _isFiltering ? null : _clearFilters,
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        const Spacer(),

        // 结果统计
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

  // 构建版本卡片
  Widget _buildVersionCard(
      Document document, int originalIndex, HomeController controller) {
    final data = document.data;
    final routeName = data['routeName'];
    final version = data['version'];
    final isEnable = data['enable'] ?? false;
    final createTime = DateTime.fromMillisecondsSinceEpoch(version);
    final allowPhones =
        JSON(data)['allow_phones'].listValue.map((e) => e.toString()).toList();

    // 每次构建时重新计算全量模式状态，确保与数据同步
    final isFullModeFromData = _isVersionFullMode(data);
    _isFullPublish[originalIndex] = isFullModeFromData;

    // 获取版本的环境状态
    final versionIsTestEnvironment =
        _getVersionEnvironment(originalIndex, data);

    final formattedTime = _formatDateTime(createTime);
    final cardBackgroundColor =
        _getCardBackgroundColor(isEnable, versionIsTestEnvironment);
    final statusIndicatorColor =
        _getStatusIndicatorColor(isEnable, versionIsTestEnvironment);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: cardBackgroundColor,
        child: Column(
          children: [
            // 状态指示条
            Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                color: statusIndicatorColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(
                      routeName, isEnable, versionIsTestEnvironment),
                  _buildCardInfo(formattedTime, allowPhones, data),
                  _buildCardActions(
                      originalIndex, controller, isEnable, allowPhones),
                  // 始终显示手机号管理区域，让内部逻辑决定是否显示
                  _buildPhoneManagement(originalIndex, controller, allowPhones),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建卡片头部
  Widget _buildCardHeader(
      String? routeName, bool isEnable, bool versionIsTestEnvironment) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            routeName ?? '未知路由',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        _buildStatusChip(
            isEnable: isEnable,
            versionIsTestEnvironment: versionIsTestEnvironment),
      ],
    );
  }

  // 构建卡片信息
  Widget _buildCardInfo(String formattedTime, List<String> allowPhones,
      Map<String, dynamic> data) {
    final isFullMode = _isVersionFullMode(data);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '发布时间: $formattedTime',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          if (!isFullMode) ...[
            const SizedBox(height: 4),
            Text(
              '允许更新的手机号数量: ${allowPhones.length}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              '发布模式: 全量发布',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // 构建卡片操作按钮
  Widget _buildCardActions(int originalIndex, HomeController controller,
      bool isEnable, List<String> allowPhones) {
    return Row(
      children: [
        _buildPublishModeButton(originalIndex, controller),
        const SizedBox(width: 16),
        _buildEnvironmentButton(originalIndex),
        const SizedBox(width: 16),
        _buildOnlineStatusButton(originalIndex, controller, isEnable),
      ],
    );
  }

  // 构建发布模式按钮（单个切换）
  Widget _buildPublishModeButton(int originalIndex, HomeController controller) {
    // 从当前版本数据重新获取全量模式状态
    final document = controller.versionList[originalIndex];
    final data = document.data;
    final isFullModeFromData = _isVersionFullMode(data);

    // 如果本地状态不存在，使用数据状态初始化
    if (!_isFullPublish.containsKey(originalIndex)) {
      _isFullPublish[originalIndex] = isFullModeFromData;
    }

    // 使用本地状态，这样切换后能立即反映
    final isFullMode = _isFullPublish[originalIndex] ?? isFullModeFromData;

    return _buildSingleToggleButton(
      activeLabel: '全量',
      inactiveLabel: '指定用户',
      activeIcon: Icons.public,
      inactiveIcon: Icons.people,
      isActive: isFullMode,
      activeColor: Colors.blue.shade700,
      inactiveColor: Colors.green.shade700,
      onTap: () {
        // 当前是全量模式，点击切换到指定用户模式
        if (isFullMode) {
          _handleTargetModeSwitch(originalIndex, controller);
        } else {
          // 当前是指定用户模式，点击切换到全量模式
          _handleFullModeSwitch(originalIndex, controller);
        }
      },
    );
  }

  // 构建环境切换按钮（单个切换）
  Widget _buildEnvironmentButton(int originalIndex) {
    final versionIsTestEnvironment = _isTestEnvironment[originalIndex] ?? true;
    return _buildSingleToggleButton(
      activeLabel: '测试',
      inactiveLabel: '正式',
      activeIcon: Icons.bug_report,
      inactiveIcon: Icons.verified,
      isActive: versionIsTestEnvironment,
      activeColor: Colors.orange.shade700,
      inactiveColor: Colors.purple.shade700,
      onTap: () =>
          _handleEnvironmentSwitch(originalIndex, !versionIsTestEnvironment),
    );
  }

  // 构建上线状态按钮（单个切换）
  Widget _buildOnlineStatusButton(
      int originalIndex, HomeController controller, bool isEnable) {
    return _buildSingleToggleButton(
      activeLabel: '已上线',
      inactiveLabel: '未上线',
      activeIcon: Icons.cloud_done,
      inactiveIcon: Icons.cloud_off,
      isActive: isEnable,
      activeColor: Colors.green.shade700,
      inactiveColor: Colors.red.shade700,
      onTap: () =>
          _handleOnlineStatusSwitch(originalIndex, controller, isEnable),
    );
  }

  // 构建手机号管理区域
  Widget _buildPhoneManagement(
      int originalIndex, HomeController controller, List<String> allowPhones) {
    // 获取当前的全量模式状态
    final document = controller.versionList[originalIndex];
    final data = document.data;
    final dataIsFullMode = _isVersionFullMode(data);
    final localIsFullMode = _isFullPublish[originalIndex];

    // 使用本地状态优先，如果本地状态不存在则使用数据状态
    final isFullMode = localIsFullMode ?? dataIsFullMode;

    // 如果是全量模式，不显示手机号管理
    if (isFullMode) {
      return const SizedBox.shrink();
    }

    // 获取展开状态，默认为收缩（false）
    final isExpanded = _isExpanded[originalIndex] ?? false;

    return Column(
      children: [
        const SizedBox(height: 12),
        // 可点击的标题栏，用于展开/收缩
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded[originalIndex] = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '允许更新的手机号',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 显示手机号数量
                    if (allowPhones.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${allowPhones.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // 展开/收缩图标
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 根据展开状态显示内容
        if (isExpanded) ...[
          const SizedBox(height: 8),
          _buildPhoneManagementContent(originalIndex, controller, allowPhones),
        ],
      ],
    );
  }

  // 构建手机号管理内容
  Widget _buildPhoneManagementContent(
      int originalIndex, HomeController controller, List<String> allowPhones) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    hintText: '请输入11位手机号',
                    helperText: '支持中国大陆手机号（如：138 0013 8000）',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: Icon(Icons.phone_android),
                    counterText: '', // 隐藏字符计数器
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // 只允许数字
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () =>
                    _addPhoneNumber(originalIndex, controller, allowPhones),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPhoneNumberList(originalIndex, controller, allowPhones),
        ],
      ),
    );
  }

  // 构建手机号列表
  Widget _buildPhoneNumberList(
      int originalIndex, HomeController controller, List<String> allowPhones) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        children: allowPhones.asMap().entries.map((entry) {
          final phoneIndex = entry.key;
          final phone = entry.value;
          final formattedPhone = _formatPhoneNumber(phone);
          return Chip(
            label: Text(formattedPhone),
            onDeleted: () => _removePhoneNumber(
                originalIndex, controller, allowPhones, phoneIndex),
            deleteIcon: const Icon(Icons.close, size: 18),
            backgroundColor: Colors.blue.shade50,
            side: BorderSide(color: Colors.blue.shade200),
          );
        }).toList(),
      ),
    );
  }

  // 处理全量模式切换
  Future<void> _handleFullModeSwitch(
      int originalIndex, HomeController controller) async {
    final confirmed = await _showConfirmDialog(
      title: '确认切换',
      content: '确定要切换到全量模式吗？\n注意：这将清空当前的手机号列表。',
    );

    if (confirmed == true) {
      // 先更新本地状态
      setState(() {
        _isFullPublish[originalIndex] = true;
        // 移除展开状态设置，因为现在始终展开
      });

      // 然后调用控制器更新服务器
      controller.switchToFullMode(originalIndex);
    }
  }

  // 处理指定用户模式切换
  Future<void> _handleTargetModeSwitch(
      int originalIndex, HomeController controller) async {
    final confirmed = await _showConfirmDialog(
      title: '确认切换',
      content: '确定要切换到指定手机号模式吗？\n切换后需要添加至少一个手机号才能生效。',
    );

    if (confirmed == true) {
      // 先更新本地状态
      setState(() {
        _isFullPublish[originalIndex] = false;
        // 切换到指定用户模式时，自动展开手机号管理区域方便用户操作
        _isExpanded[originalIndex] = true;
      });

      // 然后调用控制器更新服务器
      controller.switchToTargetMode(originalIndex);

      // 提示用户
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已切换到指定用户模式，请在下方添加手机号'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 处理环境切换
  Future<void> _handleEnvironmentSwitch(
      int originalIndex, bool toTestEnvironment) async {
    final confirmed = await _showConfirmDialog(
      title: '确认切换环境',
      content: '确定要将此版本切换到${toTestEnvironment ? '测试' : '正式'}环境吗？',
    );

    if (confirmed == true) {
      try {
        final controller = Get.find<HomeController>();

        // 更新环境状态到服务器
        await controller.updateVersionEnvironment(
          originalIndex,
          isTestEnvironment: toTestEnvironment,
        );

        // 更新本地状态
        setState(() {
          _isTestEnvironment[originalIndex] = toTestEnvironment;
        });

        // 显示成功提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已切换到${toTestEnvironment ? '测试' : '正式'}环境'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // 显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('环境切换失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 处理上线状态切换
  Future<void> _handleOnlineStatusSwitch(
      int originalIndex, HomeController controller, bool isEnable) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await _showConfirmDialog(
      title: '确认状态变更',
      content: '确定要${!isEnable ? '启用' : '禁用'}该版本吗？',
    );

    if (confirmed == true && mounted) {
      controller.updateVersion(originalIndex, enable: !isEnable);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(!isEnable ? '已启用该版本' : '已禁用该版本'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 构建加载更多指示器
  Widget _buildLoadMoreIndicator(HomeController controller) {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text(
                  '加载更多...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      } else if (!controller.hasMore.value) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              '没有更多数据了',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    });
  }

  // 校验中国手机号格式
  bool _isValidChinesePhoneNumber(String phone) {
    // 移除所有空格和特殊字符
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // 中国手机号正则表达式
    // 支持 11 位数字，以 1 开头，第二位为 3-9
    final RegExp phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    
    return phoneRegex.hasMatch(cleanPhone);
  }

  // 格式化手机号显示（添加空格分隔）
  String _formatPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.length == 11) {
      return '${cleanPhone.substring(0, 3)} ${cleanPhone.substring(3, 7)} ${cleanPhone.substring(7)}';
    }
    return phone;
  }

  // 清理手机号（移除格式化字符，只保留数字）
  String _cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  // 添加手机号
  void _addPhoneNumber(
      int originalIndex, HomeController controller, List<String> allowPhones) {
    if (_phoneController.text.isNotEmpty) {
      final inputPhone = _phoneController.text.trim();
      
      // 校验手机号格式
      if (!_isValidChinesePhoneNumber(inputPhone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请输入正确的中国大陆手机号格式（11位数字，以1开头）'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // 清理手机号，统一格式
      final cleanPhone = _cleanPhoneNumber(inputPhone);
      
      // 检查是否重复（使用清理后的手机号进行比较）
      final cleanAllowPhones = allowPhones.map((phone) => _cleanPhoneNumber(phone)).toList();
      if (cleanAllowPhones.contains(cleanPhone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('该手机号已存在'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 格式化手机号用于显示
      final formattedPhone = _formatPhoneNumber(cleanPhone);

      setState(() {
        allowPhones.add(cleanPhone); // 存储清理后的手机号
        controller.updateVersion(originalIndex, allowPhones: allowPhones);
        _phoneController.clear();

        // 如果之前是全量模式（手机号数组为空），现在添加了手机号，自动切换到指定用户模式
        if (allowPhones.length == 1) {
          _isFullPublish[originalIndex] = false;
          // 同时更新后端的 is_store 状态
          controller.updateVersion(originalIndex, isStore: false);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加手机号: $formattedPhone'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // 删除手机号
  void _removePhoneNumber(int originalIndex, HomeController controller,
      List<String> allowPhones, int phoneIndex) {
    final removedPhone = allowPhones[phoneIndex];
    final formattedRemovedPhone = _formatPhoneNumber(removedPhone);

    setState(() {
      allowPhones.removeAt(phoneIndex);
      controller.updateVersion(originalIndex, allowPhones: allowPhones);

      // 如果删除后手机号数组为空，自动切换到全量模式
      if (allowPhones.isEmpty) {
        _isFullPublish[originalIndex] = true;
        // 同时更新后端的 is_store 状态
        controller.updateVersion(originalIndex, isStore: true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('手机号列表已清空，自动切换到全量模式'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除手机号: $formattedRemovedPhone'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  // 构建空状态
  Widget _buildEmptyState() {
    if (_hasActiveFilters()) {
      // 筛选结果为空
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            const Text(
              '没有找到符合筛选条件的版本',
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
      // 数据为空
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无版本数据',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '请联系管理员添加版本数据',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter热更版本管理'),
        centerTitle: true,
        actions: [
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
      ),
      body: Obx(() {
        final versions = controller.versionList;
        final isLoading = controller.isLoading.value;

        return Column(
          children: [
            // 筛选面板
            if (_showFilters) _buildFilterPanel(versions.length),

            // 版本列表
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: isLoading && versions.isEmpty
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
                    : versions.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => controller.refreshVersions(),
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount: versions.length + (controller.hasMore.value ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == versions.length) {
                                  // 加载更多指示器
                                  return _buildLoadMoreIndicator(controller);
                                }
                                
                                final document = versions[index];
                                final originalIndex =
                                    controller.versionList.indexOf(document);
                                return _buildVersionCard(
                                    document, originalIndex, controller);
                              },
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                            ),
                          ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
