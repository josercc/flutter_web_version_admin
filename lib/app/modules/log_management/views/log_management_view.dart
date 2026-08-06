import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/log_management_controller.dart';

class LogManagementView extends StatelessWidget {
  const LogManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LogManagementController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('日志管理系统'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 搜索表单
              _buildSearchForm(controller),

              // 结果展示区域
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!controller.hasSearched.value) {
                    return _buildEmptyState();
                  }

                  if (controller.appLoads.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return _buildResultsArea(controller);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchForm(LogManagementController controller) {
    return Obx(() {
      final collapsed = controller.isSearchCollapsed.value;
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '日志查询',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      controller.isSearchCollapsed.value = !collapsed,
                  icon: Icon(
                    collapsed ? Icons.unfold_more : Icons.unfold_less,
                    size: 16,
                  ),
                  label: Text(collapsed ? '展开' : '收起'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            if (!collapsed) ...[
              const SizedBox(height: 16),

              // 搜索输入框
              Row(
                children: [
                  Expanded(
                    child: _buildSearchField(
                      controller: controller.searchUserIdController,
                      label: '用户ID',
                      hint: '输入用户ID',
                      onChanged: (value) =>
                          controller.searchUserId.value = value,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSearchField(
                      controller: controller.searchDeviceIdController,
                      label: '设备ID',
                      hint: '输入设备ID',
                      onChanged: (value) =>
                          controller.searchDeviceId.value = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSearchField(
                      controller: controller.searchSentryIdController,
                      label: 'Sentry ID',
                      hint: '输入Sentry ID',
                      onChanged: (value) =>
                          controller.searchSentryId.value = value,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSearchField(
                      controller: controller.searchTitleController,
                      label: '标题',
                      hint: '输入标题关键词',
                      onChanged: (value) =>
                          controller.searchTitle.value = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSearchField(
                      controller: controller.searchDaysController,
                      label: '查询多少天之前',
                      hint: '输入天数，例如 7',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        controller.searchDaysBefore.value = parsed ?? 0;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: controller.searchAppLoads,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('搜索'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.clearSearch,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('清空'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.isCleaning.value ||
                              controller.appLoads.isEmpty
                          ? null
                          : controller.confirmAndClean,
                      icon: controller.isCleaning.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cleaning_services, size: 18),
                      label:
                          Text(controller.isCleaning.value ? '清理中...' : '一键清理'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade600),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '请输入搜索条件',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持按用户ID、设备ID、Sentry ID或标题进行查询',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '未找到相关记录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请尝试其他搜索条件',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsArea(LogManagementController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 结果统计
          Obx(() => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${controller.totalCount.value} 条记录，第 ${controller.currentPage.value} / ${controller.totalPages.value} 页',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),

          // 分页控制
          _buildPaginationControls(controller),
          const SizedBox(height: 12),

          // 启动记录列表
          Expanded(
            child: ListView.builder(
              itemCount: controller.appLoads.length,
              itemBuilder: (context, index) {
                final appLoad = controller.appLoads[index];
                return _buildAppLoadCard(controller, appLoad);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(LogManagementController controller) {
    return Obx(() {
      final currentPage = controller.currentPage.value;
      final totalPages = controller.totalPages.value;

      return Row(
        children: [
          Text(
            '每页 ${controller.pageSize} 条',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: currentPage > 1
                ? () => controller.loadAppLoadsByPage(page: currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left, size: 16),
            label: const Text('上一页'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: currentPage < totalPages
                ? () => controller.loadAppLoadsByPage(page: currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right, size: 16),
            label: const Text('下一页'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => controller.loadAppLoadsByPage(page: 1),
            child: const Text('刷新当前条件'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed:
                controller.isCleaning.value || controller.appLoads.isEmpty
                    ? null
                    : controller.confirmAndClean,
            icon: controller.isCleaning.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cleaning_services, size: 16),
            label: Text(controller.isCleaning.value ? '清理中...' : '一键清理'),
          ),
        ],
      );
    });
  }

  Widget _buildAppLoadCard(
      LogManagementController controller, dynamic appLoad) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showLogDetailsDialog(controller, appLoad),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '启动记录 ${appLoad.$id}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                      softWrap: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red.shade400,
                    tooltip: '删除该启动记录',
                    onPressed: controller.isCleaning.value
                        ? null
                        : () => controller.confirmAndCleanSingle(appLoad),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.access_time,
                    label: '时间',
                    value: controller.formatTime(appLoad.data['time'] ?? ''),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.phone_android,
                    label: '设备',
                    value: (appLoad.data['deviceId'] ?? '').toString(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.settings,
                    label: '环境',
                    value: appLoad.data['environment'] ?? '未知',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.store,
                    label: '商店版本',
                    value:
                        (appLoad.data['isStoreVersion'] ?? false) ? '是' : '否',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 12,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$label: $value',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示详细日志弹窗
  void _showLogDetailsDialog(
      LogManagementController controller, dynamic appLoad) async {
    // 先选择启动记录并获取详细信息
    await controller.selectAppLoad(appLoad);

    // 显示详细日志弹窗
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: Get.width * 0.8,
          height: Get.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '启动记录详情',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 启动记录信息
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('启动信息'),
                      _buildAppLoadInfo(controller),
                      const SizedBox(height: 16),
                      _buildSectionTitle('用户日志'),
                      _buildUserLogs(controller),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Sentry日志'),
                      _buildSentryLogs(controller),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildAppLoadInfo(LogManagementController controller) {
    if (controller.selectedAppLoad.value == null)
      return const SizedBox.shrink();

    final appLoad = controller.selectedAppLoad.value!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          _buildInfoRow('启动ID', appLoad.$id),
          _buildInfoRow(
              '时间', controller.formatTime(appLoad.data['time'] ?? '')),
          _buildInfoRow('设备ID', appLoad.data['deviceId'] ?? ''),
          _buildInfoRow('环境', appLoad.data['environment'] ?? ''),
          _buildInfoRow(
              '商店版本', (appLoad.data['isStoreVersion'] ?? false) ? '是' : '否'),
        ],
      ),
    );
  }

  Widget _buildUserLogs(LogManagementController controller) {
    if (controller.userLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '暂无用户日志',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: controller.userLogs
          .map((log) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('用户ID', log.data['userId'] ?? ''),
                    _buildInfoRow(
                        '时间', controller.formatTime(log.data['time'] ?? '')),
                    _buildInfoRow('关联启动ID', log.data['appLoadId'] ?? ''),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSentryLogs(LogManagementController controller) {
    if (controller.sentryLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '暂无Sentry日志',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: controller.sentryLogs
          .map((log) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Sentry ID', log.data['sentryId'] ?? ''),
                    _buildInfoRow('标题', log.data['title'] ?? ''),
                    _buildInfoRow(
                        '时间', controller.formatTime(log.data['time'] ?? '')),
                    _buildInfoRow('关联启动ID', log.data['appLoadId'] ?? ''),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
