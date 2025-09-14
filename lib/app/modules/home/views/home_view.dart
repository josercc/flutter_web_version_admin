import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter热更版本管理'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 欢迎标题
                _buildWelcomeSection(),
                const SizedBox(height: 20),

                // 功能菜单
                _buildMenuSection(),
                const SizedBox(height: 20),

                // 统计信息
                _buildStatsSection(),
                const SizedBox(height: 20), // 底部额外间距
              ],
            ),
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

  Widget _buildMenuSection() {
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
            SizedBox(
              width: 100,
              height: 100,
              child: _buildMenuCard(
                title: '版本管理',
                subtitle: '管理热更新版本',
                icon: Icons.settings,
                color: Colors.blue,
                onTap: () => Get.toNamed('/version-management'),
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: _buildMenuCard(
                title: '缓存管理',
                subtitle: '管理缓存文件',
                icon: Icons.storage,
                color: Colors.indigo,
                onTap: () => Get.toNamed('/cache-management'),
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: _buildMenuCard(
                title: '打包管理',
                subtitle: '管理打包信息',
                icon: Icons.build,
                color: Colors.teal,
                onTap: () => Get.toNamed('/build-management'),
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: _buildMenuCard(
                title: '日志管理',
                subtitle: '查询应用日志',
                icon: Icons.assignment,
                color: Colors.red,
                onTap: () => Get.toNamed('/log-management'),
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: _buildMenuCard(
                title: '版本发布',
                subtitle: '发布新版本',
                icon: Icons.publish,
                color: Colors.green,
                onTap: () => _showComingSoon(),
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: _buildMenuCard(
                title: '用户管理',
                subtitle: '管理测试用户',
                icon: Icons.people,
                color: Colors.orange,
                onTap: () => _showComingSoon(),
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: _buildMenuCard(
                title: '系统设置',
                subtitle: '系统配置',
                icon: Icons.tune,
                color: Colors.purple,
                onTap: () => _showComingSoon(),
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

  void _showComingSoon() {
    Get.snackbar(
      '功能开发中',
      '该功能正在开发中，敬请期待！',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade100,
      colorText: Colors.orange.shade800,
      icon: Icon(
        Icons.construction,
        color: Colors.orange.shade600,
      ),
      duration: const Duration(seconds: 2),
    );
  }
}
