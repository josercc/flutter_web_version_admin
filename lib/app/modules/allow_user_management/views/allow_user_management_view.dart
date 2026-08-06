import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/allow_user_management_controller.dart';

class AllowUserManagementView extends StatelessWidget {
  const AllowUserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AllowUserManagementController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('允许用户管理'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => controller.refreshAllowUserIds(),
          ),
        ],
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
              _buildAddCard(controller),
              _buildSearchBar(controller),
              Expanded(child: _buildUserList(controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddCard(AllowUserManagementController controller) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                '新增用户 ID',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Obx(() => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '共 ${controller.allowUserIds.length} 人',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.userIdController,
                  decoration: const InputDecoration(
                    hintText: '请输入用户 ID',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => controller.addUserId(),
                ),
              ),
              const SizedBox(width: 12),
              Obx(() => ElevatedButton(
                    onPressed: controller.isSaving.value
                        ? null
                        : () => controller.addUserId(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('添加'),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AllowUserManagementController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索用户 ID',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (value) => controller.searchKeyword.value = value,
      ),
    );
  }

  Widget _buildUserList(AllowUserManagementController controller) {
    return Obx(() {
      if (controller.isLoading.value && controller.allowUserIds.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('加载中...', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        );
      }

      final ids = controller.filteredUserIds;
      if (ids.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                controller.allowUserIds.isEmpty ? '暂无允许用户' : '未找到匹配的用户 ID',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => controller.refreshAllowUserIds(),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: ids.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final userId = ids[index];
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.person, color: Colors.blue.shade600),
                ),
                title: SelectableText(
                  userId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '复制',
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: userId));
                        Get.snackbar('成功', '已复制用户 ID');
                      },
                    ),
                    IconButton(
                      tooltip: '删除',
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red.shade400),
                      onPressed: controller.isSaving.value
                          ? null
                          : () => controller.removeUserId(userId),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
