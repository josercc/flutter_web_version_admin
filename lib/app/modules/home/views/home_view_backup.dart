import 'package:darty_json_safe/darty_json_safe.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart';

import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  bool isTestEnvironment = true;
  final TextEditingController _phoneController = TextEditingController();
  final Map<int, bool> _isExpanded = {};
  final Map<int, bool> _isFullPublish = {};
  
  // 筛选相关状态
  bool _showFilters = false;
  final TextEditingController _routeNameFilter = TextEditingController();
  final TextEditingController _phoneNumberFilter = TextEditingController();
  String _onlineStatusFilter = '全部'; // 全部、已上线、未上线
  String _environmentFilter = '全部'; // 全部、测试环境、正式环境

  @override
  void dispose() {
    _phoneController.dispose();
    _routeNameFilter.dispose();
    _phoneNumberFilter.dispose();
    super.dispose();
  }

  // 筛选逻辑
  List<Document> _getFilteredVersions(List<Document> versions) {
    return versions.where((document) {
      final data = document.data;
      final routeName = data['routeName'] ?? '';
      final isEnable = data['enable'] ?? false;
      final allowPhones = (data['allow_phones'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      // 路由名称筛选
      if (_routeNameFilter.text.isNotEmpty) {
        if (!routeName.toLowerCase().contains(_routeNameFilter.text.toLowerCase())) {
          return false;
        }
      }

      // 上线状态筛选
      if (_onlineStatusFilter != '全部') {
        if (_onlineStatusFilter == '已上线' && !isEnable) return false;
        if (_onlineStatusFilter == '未上线' && isEnable) return false;
      }

      // 环境类型筛选
      if (_environmentFilter != '全部') {
        if (_environmentFilter == '测试环境' && (!isEnable || !isTestEnvironment)) return false;
        if (_environmentFilter == '正式环境' && (!isEnable || isTestEnvironment)) return false;
      }

      // 手机号筛选
      if (_phoneNumberFilter.text.isNotEmpty) {
        final phoneFilter = _phoneNumberFilter.text.toLowerCase();
        bool hasMatchingPhone = allowPhones.any((phone) => 
            phone.toLowerCase().contains(phoneFilter));
        if (!hasMatchingPhone) return false;
      }

      return true;
    }).toList();
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
        final filteredVersions = _getFilteredVersions(controller.versionList);
        
        return Column(
          children: [
            // 筛选面板
            if (_showFilters)
              Container(
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
                    const Text(
                      '筛选条件',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 第一行：路由名称和手机号
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _routeNameFilter,
                            decoration: const InputDecoration(
                              labelText: '路由名称',
                              hintText: '输入路由名称进行筛选',
                              prefixIcon: Icon(Icons.route),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) => setState(() {}),
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
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 第二行：上线状态和环境类型
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _onlineStatusFilter,
                            decoration: const InputDecoration(
                              labelText: '上线状态',
                              prefixIcon: Icon(Icons.cloud),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 操作按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _routeNameFilter.clear();
                              _phoneNumberFilter.clear();
                              _onlineStatusFilter = '全部';
                              _environmentFilter = '全部';
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('清空筛选'),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Text(
                            '共 ${filteredVersions.length} 条记录',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            // 版本列表
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 20),
                child: filteredVersions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '没有找到符合条件的版本',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredVersions.length,
                        itemBuilder: (context, index) {
                          final document = filteredVersions[index];
                          final originalIndex = controller.versionList.indexOf(document);
                          final data = document.data;
                          final routeName = data['routeName'];
                          final version = data['version'];
                          final isEnable = data['enable'] ?? false;
                          final createTime = DateTime.fromMillisecondsSinceEpoch(version);
                          final allowPhones = JSON(data)['allow_phones']
                              .listValue
                              .map((e) => e.toString())
                              .toList();

                          // 初始化全量模式状态 - 基于实际数据
                          final isStore = data['is_store'] ?? false;
                          if (!_isFullPublish.containsKey(originalIndex)) {
                            _isFullPublish[originalIndex] = isStore;
                          }

                          // 格式化发布时间
                          final formattedTime =
                              '${createTime.year}-${createTime.month.toString().padLeft(2, '0')}-${createTime.day.toString().padLeft(2, '0')} ${createTime.hour.toString().padLeft(2, '0')}:${createTime.minute.toString().padLeft(2, '0')}';

                          // 根据上线状态和环境类型设置卡片背景色
              Color cardBackgroundColor;
              if (!isEnable) {
                // 未上线：浅灰色背景
                cardBackgroundColor = Colors.grey.shade50;
              } else if (isTestEnvironment) {
                // 测试环境：浅蓝色背景
                cardBackgroundColor = Colors.blue.shade50;
              } else {
                // 正式环境：浅绿色背景
                cardBackgroundColor = Colors.green.shade50;
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(12), // 增大圆角
                child: Card(
                  elevation: 4, // 增加阴影深度
                  margin: const EdgeInsets.symmetric(vertical: 8), // 卡片外部间距
                  color: cardBackgroundColor,
                  child: Column(
                    children: [
                      // 状态指示条
                      Container(
                        width: double.infinity,
                        height: 4,
                        decoration: BoxDecoration(
                          color: !isEnable 
                              ? Colors.grey.shade400
                              : isTestEnvironment 
                                  ? Colors.blue.shade400
                                  : Colors.green.shade400,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16), // 增加内边距
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // 路由名称和状态标签
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                routeName ?? '未知路由',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87, // 加深标题颜色
                                ),
                              ),
                            ),
                            // 状态标签
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: !isEnable 
                                    ? Colors.grey.shade100
                                    : isTestEnvironment 
                                        ? Colors.blue.shade100
                                        : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: !isEnable 
                                      ? Colors.grey.shade300
                                      : isTestEnvironment 
                                          ? Colors.blue.shade300
                                          : Colors.green.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    !isEnable 
                                        ? Icons.pause_circle_outline
                                        : isTestEnvironment 
                                            ? Icons.science
                                            : Icons.rocket_launch,
                                    size: 16,
                                    color: !isEnable 
                                        ? Colors.grey.shade600
                                        : isTestEnvironment 
                                            ? Colors.blue.shade600
                                            : Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    !isEnable 
                                        ? '未上线'
                                        : isTestEnvironment 
                                            ? '测试环境'
                                            : '正式环境',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: !isEnable 
                                          ? Colors.grey.shade600
                                          : isTestEnvironment 
                                              ? Colors.blue.shade600
                                              : Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // 发布时间和手机数量
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12), // 增加垂直间距
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '发布时间: $formattedTime',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              if (!(data['is_store'] ?? false)) ...[
                                const SizedBox(height: 4), // 增加行间距
                                Text(
                                  '允许更新的手机号数量: ${allowPhones.length}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // 全量切换按钮和环境/上线按钮放在同一行
                        Row(
                          children: [
                            // 全量和指定手机号切换按钮
                            Row(
                              children: [
                                // 全量按钮
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: (_isFullPublish[originalIndex] ?? false)
                                        ? Colors.blue.shade50 
                                        : Colors.grey.shade100,
                                    border: Border.all(
                                      color: (_isFullPublish[originalIndex] ?? false)
                                          ? Colors.blue.shade300 
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      if (!(_isFullPublish[originalIndex] ?? false)) {
                                        // 显示确认对话框
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text('确认切换'),
                                              content: const Text('确定要切换到全量模式吗？\n注意：这将清空当前的手机号列表。'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(false),
                                                  child: const Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(true),
                                                  child: const Text('确定'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        // 如果用户确认，则执行切换
                                        if (confirmed == true) {
                                          // 调用控制器方法切换到全量模式并清空手机号列表
                                          controller.switchToFullMode(originalIndex);
                                          setState(() {
                                            _isFullPublish[originalIndex] = true;
                                            _isExpanded[originalIndex] = false;
                                          });
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.public,
                                            size: 16,
                                            color: (_isFullPublish[originalIndex] ?? false)
                                                ? Colors.blue.shade700 
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '全量',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: (_isFullPublish[originalIndex] ?? false)
                                                  ? Colors.blue.shade700 
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 指定手机号按钮
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: !(_isFullPublish[originalIndex] ?? false)
                                        ? Colors.green.shade50 
                                        : Colors.grey.shade100,
                                    border: Border.all(
                                      color: !(_isFullPublish[originalIndex] ?? false)
                                          ? Colors.green.shade300 
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      if (_isFullPublish[originalIndex] ?? false) {
                                        // 显示确认对话框
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text('确认切换'),
                                              content: const Text('确定要切换到指定手机号模式吗？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(false),
                                                  child: const Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(true),
                                                  child: const Text('确定'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        // 如果用户确认，则执行切换
                                        if (confirmed == true) {
                                          // 调用控制器方法切换到指定手机号模式
                                          controller.switchToTargetMode(originalIndex);
                                          setState(() {
                                            _isFullPublish[originalIndex] = false;
                                          });
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 16,
                                            color: !(_isFullPublish[originalIndex] ?? false)
                                                ? Colors.green.shade700 
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '指定用户',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: !(_isFullPublish[originalIndex] ?? false)
                                                  ? Colors.green.shade700 
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 16), // 按钮间距

                            // 环境切换按钮
                            Row(
                              children: [
                                // 测试环境按钮
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: isTestEnvironment
                                        ? Colors.orange.shade50 
                                        : Colors.grey.shade100,
                                    border: Border.all(
                                      color: isTestEnvironment
                                          ? Colors.orange.shade300 
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      if (!isTestEnvironment) {
                                        // 显示确认对话框
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text('确认切换环境'),
                                              content: const Text('确定要切换到测试环境吗？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(false),
                                                  child: const Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(true),
                                                  child: const Text('确定'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        // 如果用户确认，则执行切换
                                        if (confirmed == true) {
                                          setState(() {
                                            isTestEnvironment = true;
                                          });
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bug_report,
                                            size: 16,
                                            color: isTestEnvironment
                                                ? Colors.orange.shade700 
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '测试',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isTestEnvironment
                                                  ? Colors.orange.shade700 
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 正式环境按钮
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: !isTestEnvironment
                                        ? Colors.purple.shade50 
                                        : Colors.grey.shade100,
                                    border: Border.all(
                                      color: !isTestEnvironment
                                          ? Colors.purple.shade300 
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      if (isTestEnvironment) {
                                        // 显示确认对话框
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text('确认切换环境'),
                                              content: const Text('确定要切换到正式环境吗？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(false),
                                                  child: const Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(true),
                                                  child: const Text('确定'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        // 如果用户确认，则执行切换
                                        if (confirmed == true) {
                                          setState(() {
                                            isTestEnvironment = false;
                                          });
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified,
                                            size: 16,
                                            color: !isTestEnvironment
                                                ? Colors.purple.shade700 
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '正式',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: !isTestEnvironment
                                                  ? Colors.purple.shade700 
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 16), // 按钮间距

                            // 上线状态按钮
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isEnable 
                                    ? Colors.green.shade50 
                                    : Colors.red.shade50,
                                border: Border.all(
                                  color: isEnable 
                                      ? Colors.green.shade300 
                                      : Colors.red.shade300,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  // 显示确认对话框
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('确认状态变更'),
                                        content: Text(
                                          '确定要${!isEnable ? '启用' : '禁用'}该版本吗？',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(true),
                                            child: const Text('确定'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  // 如果用户确认，则执行状态变更
                                  if (confirmed == true && mounted) {
                                    controller.updateVersion(
                                      originalIndex,
                                      enable: !isEnable,
                                    );
                                    // 添加文本提示
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            !isEnable ? '已启用该版本' : '已禁用该版本'),
                                        duration:
                                            const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isEnable 
                                            ? Icons.cloud_done 
                                            : Icons.cloud_off,
                                        size: 16,
                                        color: isEnable 
                                            ? Colors.green.shade700 
                                            : Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isEnable ? '已上线' : '未上线',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isEnable 
                                              ? Colors.green.shade700 
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 仅在指定手机号模式下显示手机号管理区域
                        if (!(_isFullPublish[originalIndex] ?? false))
                          Column(
                            children: [
                              const SizedBox(height: 12), // 增加间距
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isExpanded[originalIndex] =
                                        !(_isExpanded[originalIndex] ?? false);
                                  });
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('允许更新的手机号',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Icon(_isExpanded[originalIndex] ?? false
                                        ? Icons.expand_less
                                        : Icons.expand_more),
                                  ],
                                ),
                              ),

                              if (_isExpanded[originalIndex] ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 12, left: 4, right: 4), // 优化内边距
                                  child: Column(
                                    children: [
                                      // 优化手机号输入框和添加按钮布局
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _phoneController,
                                              keyboardType: TextInputType.phone,
                                              decoration: const InputDecoration(
                                                hintText: '输入新手机号',
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical:
                                                            10), // 调整输入框内边距
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton(
                                            onPressed: () {
                                              if (_phoneController
                                                  .text.isNotEmpty) {
                                                setState(() {
                                                  allowPhones.add(
                                                      _phoneController.text);
                                                  controller.updateVersion(
                                                      originalIndex,
                                                      allowPhones: allowPhones);
                                                  _phoneController.clear();
                                                });
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                            ),
                                            child: const Text('添加'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // 手机号列表 - 左对齐展示
                                      SizedBox(
                                        width: double.infinity,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.start, // 左对齐
                                          children: allowPhones
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final phoneIndex = entry.key;
                                            final phone = entry.value;
                                            return Chip(
                                              label: Text(phone.toString()),
                                              onDeleted: () {
                                                setState(() {
                                                  allowPhones
                                                      .removeAt(phoneIndex);
                                                  controller.updateVersion(
                                                      originalIndex,
                                                      allowPhones: allowPhones);
                                                });
                                              },
                                              deleteIcon: const Icon(
                                                  Icons.close,
                                                  size: 18),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),


                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 16); // 增加列表项间距
                        },
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
