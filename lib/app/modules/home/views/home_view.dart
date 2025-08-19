import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter热更版本管理'),
        centerTitle: true,
      ),
      body: Obx(() {
        return Container(
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: controller.versionList.length,
            itemBuilder: (context, index) {
              final document = controller.versionList[index];
              final data = document.data;
              final routeName = data['routeName'];
              final version = data['version'];
              final isEnable = data['enable'] ?? false;
              final createTime = DateTime.fromMillisecondsSinceEpoch(version);
              final allowPhones = data['allow_phones'] as List<dynamic>? ?? [];

              // 格式化发布时间
              final formattedTime = '${createTime.year}-${createTime.month.toString().padLeft(2, '0')}-${createTime.day.toString().padLeft(2, '0')} ${createTime.hour.toString().padLeft(2, '0')}:${createTime.minute.toString().padLeft(2, '0')}';

              // 获取发布环境信息
              final environmentType = controller.getEnvironmentType(document);
              final environmentColor = controller.getEnvironmentColor(document);
              final cardBackgroundColor = controller.getCardBackgroundColor(document);

              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Card(
                  elevation: 2,
                  color: cardBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 路由名称和发布环境
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              routeName ?? '未知路由',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Chip(
                              label: Text(environmentType),
                              backgroundColor: environmentColor,
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),

                        // 发布时间和手机数量
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
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
                              if (!data['is_store'] ?? false) ...[
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

                        // 操作按钮区域
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 发布按钮组
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    // 测试环境发布 - 针对特定手机号
                                    const targetPhones = ['13800138000', '13900139000'];
                                    controller.publishToTestEnvironment(routeName, targetPhones);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: const Text('发布到测试环境'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    // 正式环境发布 - 全量发布
                                    controller.publishToProductionEnvironment(routeName);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text('发布到正式环境'),
                                ),
                              ],
                            ),

                            // 启用状态开关
                            CupertinoSwitch(
                              value: isEnable,
                              onChanged: (value) {
                                controller.updateEnable(index, value);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) {
              return const SizedBox(height: 12);
            },
          ),
        );
      }),
    );
  }
}
