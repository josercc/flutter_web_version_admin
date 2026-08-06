import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/packager_management_controller.dart';

class PackagerManagementView extends StatelessWidget {
  const PackagerManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PackagerManagementController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('打包机管理'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => controller.refreshPackagerList(),
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
              _buildStatsCard(controller),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value &&
                      controller.packagerList.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            '加载中...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  if (controller.packagerList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.computer_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无打包机数据',
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
                    onRefresh: () => controller.refreshPackagerList(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: controller.packagerList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = controller.packagerList[index];
                        return _buildPackagerCard(controller, doc, index);
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(PackagerManagementController controller) {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Obx(() => Row(
            children: [
              _buildStatItem(
                label: '总数',
                value: '${controller.packagerList.length}',
                color: Colors.blue,
                icon: Icons.dns,
              ),
              _buildStatItem(
                label: '启用',
                value: '${controller.activeCount}',
                color: Colors.green,
                icon: Icons.check_circle,
              ),
              _buildStatItem(
                label: '在线',
                value: '${controller.onlineCount}',
                color: Colors.teal,
                icon: Icons.cloud_done,
              ),
            ],
          )),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagerCard(
    PackagerManagementController controller,
    Document doc,
    int index,
  ) {
    final data = doc.data;
    final url = (data['url'] ?? '').toString();
    final userName = (data['userName'] ?? '').toString();
    final password = (data['password'] ?? '').toString();
    final tag = (data['tag'] ?? '').toString();
    final active = data['active'] == true;
    final online = data['online'] == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.teal.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.computer,
                    color: active
                        ? Colors.teal.shade700
                        : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.isNotEmpty ? tag : '未命名打包机',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusChip(
                            label: online ? '在线' : '离线',
                            color: online ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(
                            label: active ? '启用' : '停用',
                            color: active ? Colors.blue : Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  final isUpdating = controller.updatingIds.contains(doc.$id);
                  return Column(
                    children: [
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isUpdating)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          value: active,
                          onChanged: (_) => controller.toggleActive(index),
                        ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.link,
              label: 'URL',
              value: url.isNotEmpty ? url : '-',
              onCopy: url.isNotEmpty ? () => _copyText(url, 'URL') : null,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: '用户名',
              value: userName.isNotEmpty ? userName : '-',
              onCopy:
                  userName.isNotEmpty ? () => _copyText(userName, '用户名') : null,
            ),
            const SizedBox(height: 8),
            _PasswordRow(password: password),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        if (onCopy != null)
          InkWell(
            onTap: onCopy,
            child: Icon(
              Icons.copy,
              size: 16,
              color: Colors.grey.shade500,
            ),
          ),
      ],
    );
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar('已复制', '$label 已复制到剪贴板');
  }
}

class _PasswordRow extends StatefulWidget {
  final String password;

  const _PasswordRow({required this.password});

  @override
  State<_PasswordRow> createState() => _PasswordRowState();
}

class _PasswordRowState extends State<_PasswordRow> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final password = widget.password;
    final display =
        password.isEmpty ? '-' : (_visible ? password : '••••••••');

    return Row(
      children: [
        Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '密码',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            display,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              letterSpacing: _visible || password.isEmpty ? 0 : 1.5,
            ),
          ),
        ),
        if (password.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _visible = !_visible),
            child: Icon(
              _visible ? Icons.visibility_off : Icons.visibility,
              size: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: password));
              Get.snackbar('已复制', '密码已复制到剪贴板');
            },
            child: Icon(
              Icons.copy,
              size: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }
}
