import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:flutter_web_version_admin/app/commons/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_version_admin/app/routes/app_pages.dart';

class _MenuItem {
  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.adminOnly = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool adminOnly;
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  static const _menuItems = <_MenuItem>[
    _MenuItem(
      title: '版本管理',
      subtitle: '管理热更新版本',
      icon: Icons.settings,
      color: Colors.blue,
      route: Routes.VERSION_MANAGEMENT,
    ),
    _MenuItem(
      title: '缓存管理',
      subtitle: '管理缓存文件',
      icon: Icons.storage,
      color: Colors.indigo,
      route: Routes.CACHE_MANAGEMENT,
    ),
    _MenuItem(
      title: '打包管理',
      subtitle: '管理打包信息',
      icon: Icons.build,
      color: Colors.teal,
      route: Routes.BUILD_MANAGEMENT,
    ),
    _MenuItem(
      title: '打包机管理',
      subtitle: '管理打包机状态',
      icon: Icons.computer,
      color: Colors.cyan,
      route: Routes.PACKAGER_MANAGEMENT,
    ),
    _MenuItem(
      title: '日志管理',
      subtitle: '查询应用日志',
      icon: Icons.assignment,
      color: Colors.red,
      route: Routes.LOG_MANAGEMENT,
    ),
    _MenuItem(
      title: '远程调试',
      subtitle: '实时日志请求流',
      icon: Icons.bug_report,
      color: Colors.deepOrange,
      route: Routes.DEVICE_DEBUG,
      adminOnly: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthSession>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter热更版本管理'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('确定要退出当前账号吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('退出'),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              // 清理本地缓存的账号信息
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('email');
              await prefs.remove('password');

              // 调用 Appwrite 退出接口
              final appwriteManager = Get.find<AppwriteManager>();
              await appwriteManager.logout();
              Get.find<AuthSession>().clear();

              // 回到登录页
              Get.offAllNamed(Routes.LOGIN);
            },
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Obx(() {
              final isAdmin = auth.isAdmin.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(),
                  const SizedBox(height: 20),
                  _buildMenuSection(isAdmin: isAdmin),
                  if (isAdmin) ...[
                    const SizedBox(height: 20),
                    _buildStatsSection(),
                  ],
                  const SizedBox(height: 20),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.rocket_launch,
              size: 28,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '欢迎使用版本管理系统',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '管理您的Flutter应用热更新版本',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({required bool isAdmin}) {
    final visibleItems = _menuItems
        .where((item) => isAdmin || !item.adminOnly)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '功能菜单',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in visibleItems)
              SizedBox(
                width: 100,
                height: 100,
                child: _buildMenuCard(
                  title: item.title,
                  subtitle: item.subtitle,
                  icon: item.icon,
                  color: item.color,
                  onTap: () => Get.toNamed(item.route),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                Icons.analytics,
                color: Colors.blue.shade600,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '系统统计',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: '总版本数',
                  value: '12',
                  icon: Icons.layers,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: '活跃版本',
                  value: '8',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: '测试用户',
                  value: '156',
                  icon: Icons.people,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
