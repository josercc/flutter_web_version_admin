import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/build_management_controller.dart';

class BuildManagementView extends StatelessWidget {
  const BuildManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BuildManagementController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('打包管理'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBuildDialog(context, controller),
            tooltip: '添加打包信息',
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
            mainAxisSize: MainAxisSize.max,
            children: [
              // 搜索和筛选区域
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200, // 限制筛选区域最大高度
                  ),
                  child: _buildSearchAndFilterSection(controller),
                ),
              ),

              // 数据表格
              Expanded(
                child: _buildDataTable(controller),
              ),

              // 分页控件
              Flexible(
                flex: 0,
                child: _buildPaginationSection(controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection(BuildManagementController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 批量操作按钮
                Obx(() => Row(
                      children: [
                        if (controller.selectedItems.isNotEmpty) ...[
                          Text(
                            '已选择 ${controller.selectedItems.length} 项',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: controller.deleteSelectedItems,
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('批量删除'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    )),
                // 右侧操作按钮
                Row(
                  children: [
                    // 清除筛选按钮
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: controller.clearAllFilters,
                      tooltip: '清除所有筛选',
                    ),
                    const SizedBox(width: 12),
                    // 刷新按钮
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: controller.refresh,
                      tooltip: '刷新',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 筛选下拉框
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // 平台筛选
                Obx(() => _buildFilterDropdown(
                      label: '平台',
                      value: controller.selectedPlatform.value,
                      options: controller.platformOptions,
                      onChanged: controller.filterByPlatform,
                      width: 120,
                    )),
                // 打包名称筛选
                Obx(() => _buildFilterDropdown(
                      label: '打包名称',
                      value: controller.selectedBuildName.value,
                      options: controller.buildNameOptions,
                      onChanged: controller.filterByBuildName,
                      width: 150,
                    )),
                // Melos分支筛选
                Obx(() => _buildFilterDropdown(
                      label: 'Melos分支',
                      value: controller.selectedMelosBranch.value,
                      options: controller.melosBranchOptions,
                      onChanged: controller.filterByMelosBranch,
                      width: 150,
                    )),
                // Unity分支筛选
                Obx(() => _buildFilterDropdown(
                      label: 'Unity分支',
                      value: controller.selectedUnityBranch.value,
                      options: controller.unityBranchOptions,
                      onChanged: controller.filterByUnityBranch,
                      width: 150,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required RxList<String> options,
    required Function(String) onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: options.contains(value) ? value : options.first,
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
              underline: const SizedBox(),
              isExpanded: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(BuildManagementController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (controller.buildList.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                '暂无打包信息',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 800, // 设置最小宽度
          ),
          child: DataTable(
            columns: [
              // 全选列
              DataColumn(
                label: Obx(() => Checkbox(
                      value: controller.isAllSelected.value,
                      onChanged: (bool? value) => controller.toggleSelectAll(),
                    )),
              ),
              const DataColumn(label: Text('平台')),
              const DataColumn(label: Text('打包名称')),
              const DataColumn(label: Text('打包号')),
              const DataColumn(label: Text('Melos分支')),
              const DataColumn(label: Text('Unity分支')),
              const DataColumn(label: Text('Unity提交ID')),
              const DataColumn(label: Text('Unity版本')),
              const DataColumn(label: Text('创建时间')),
              const DataColumn(label: Text('操作')),
            ],
            rows: controller.buildList.map((build) {
              return DataRow(
                cells: [
                  // 选择复选框
                  DataCell(
                    Obx(() => Checkbox(
                          value: controller.selectedItems.contains(build.$id),
                          onChanged: (bool? value) =>
                              controller.toggleItemSelection(build.$id),
                        )),
                  ),
                  // 平台
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPlatformColor(build.data['platform'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        build.data['platform'] ?? '',
                        style: TextStyle(
                          color: _getPlatformColor(build.data['platform']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(build.data['build_name'] ?? '')),
                  DataCell(Text(build.data['build_number'] ?? '')),
                  DataCell(Text(build.data['melos_branch'] ?? '')),
                  DataCell(Text(build.data['unity_branch'] ?? '')),
                  DataCell(
                    Text(
                      build.data['unity_commit_id'] ?? '',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(Text(build.data['unity_build_version'] ?? '')),
                  DataCell(
                    Text(
                      _formatDateTime(build.$createdAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showEditBuildDialog(
                            Get.context!,
                            controller,
                            build,
                          ),
                          tooltip: '编辑',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.red),
                          onPressed: () => _showDeleteConfirmDialog(
                            Get.context!,
                            controller,
                            build,
                          ),
                          tooltip: '删除',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    });
  }

  Widget _buildPaginationSection(BuildManagementController controller) {
    return Obx(() {
      if (controller.totalPages.value <= 1) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '共 ${controller.totalCount.value} 条记录，第 ${controller.currentPage.value} / ${controller.totalPages.value} 页',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: controller.currentPage.value > 1
                      ? controller.previousPage
                      : null,
                ),
                ...List.generate(
                  controller.totalPages.value,
                  (index) {
                    final page = index + 1;
                    final isCurrentPage = page == controller.currentPage.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => controller.goToPage(page),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCurrentPage
                                ? Colors.blue.shade600
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '$page',
                              style: TextStyle(
                                color: isCurrentPage
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: isCurrentPage
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      controller.currentPage.value < controller.totalPages.value
                          ? controller.nextPage
                          : null,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Color _getPlatformColor(String? platform) {
    switch (platform) {
      case 'iOS':
        return Colors.grey;
      case 'Android':
        return Colors.green;
      case 'Web':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final date = DateTime.parse(dateTime);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  void _showAddBuildDialog(
      BuildContext context, BuildManagementController controller) {
    final formKey = GlobalKey<FormState>();
    final platformController = TextEditingController();
    final buildNameController = TextEditingController();
    final buildNumberController = TextEditingController();
    final melosBranchController = TextEditingController();
    final unityBranchController = TextEditingController();
    final unityCommitIdController = TextEditingController();
    final unityBuildVersionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加打包信息'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: '平台',
                      border: OutlineInputBorder(),
                    ),
                    items: ['iOS', 'Android', 'Web'].map((String platform) {
                      return DropdownMenuItem<String>(
                        value: platform,
                        child: Text(platform),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      platformController.text = value ?? '';
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请选择平台';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: buildNameController,
                    decoration: const InputDecoration(
                      labelText: '打包名称',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入打包名称';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: buildNumberController,
                    decoration: const InputDecoration(
                      labelText: '打包号',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入打包号';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: melosBranchController,
                    decoration: const InputDecoration(
                      labelText: 'Melos分支',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Melos分支';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unityBranchController,
                    decoration: const InputDecoration(
                      labelText: 'Unity分支',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Unity分支';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unityCommitIdController,
                    decoration: const InputDecoration(
                      labelText: 'Unity提交ID',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Unity提交ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unityBuildVersionController,
                    decoration: const InputDecoration(
                      labelText: 'Unity版本',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Unity版本';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await controller.addBuildInfo(
                  platform: platformController.text,
                  buildName: buildNameController.text,
                  buildNumber: buildNumberController.text,
                  melosBranch: melosBranchController.text,
                  unityBranch: unityBranchController.text,
                  unityCommitId: unityCommitIdController.text,
                  unityBuildVersion: unityBuildVersionController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditBuildDialog(BuildContext context,
      BuildManagementController controller, dynamic build) {
    final formKey = GlobalKey<FormState>();
    final platformController =
        TextEditingController(text: build.data['platform'] ?? '');
    final buildNameController =
        TextEditingController(text: build.data['build_name'] ?? '');
    final buildNumberController =
        TextEditingController(text: build.data['build_number'] ?? '');
    final melosBranchController =
        TextEditingController(text: build.data['melos_branch'] ?? '');
    final unityBranchController =
        TextEditingController(text: build.data['unity_branch'] ?? '');
    final unityCommitIdController =
        TextEditingController(text: build.data['unity_commit_id'] ?? '');
    final unityBuildVersionController =
        TextEditingController(text: build.data['unity_build_version'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑打包信息'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: build.data['platform'],
                    decoration: const InputDecoration(
                      labelText: '平台',
                      border: OutlineInputBorder(),
                    ),
                    items: ['iOS', 'Android', 'Web'].map((String platform) {
                      return DropdownMenuItem<String>(
                        value: platform,
                        child: Text(platform),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      platformController.text = value ?? '';
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请选择平台';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: buildNameController,
                    decoration: const InputDecoration(
                      labelText: '打包名称',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入打包名称';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: buildNumberController,
                    decoration: const InputDecoration(
                      labelText: '打包号',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入打包号';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: melosBranchController,
                    decoration: const InputDecoration(
                      labelText: 'Melos分支',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Melos分支';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unityBranchController,
                    decoration: const InputDecoration(
                      labelText: 'Unity分支',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Unity分支';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unityCommitIdController,
                    decoration: const InputDecoration(
                      labelText: 'Unity提交ID',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Unity提交ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unityBuildVersionController,
                    decoration: const InputDecoration(
                      labelText: 'Unity版本',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入Unity版本';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await controller.updateBuildInfo(
                  documentId: build.$id,
                  platform: platformController.text,
                  buildName: buildNameController.text,
                  buildNumber: buildNumberController.text,
                  melosBranch: melosBranchController.text,
                  unityBranch: unityBranchController.text,
                  unityCommitId: unityCommitIdController.text,
                  unityBuildVersion: unityBuildVersionController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context,
      BuildManagementController controller, dynamic build) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除打包信息 "${build.data['build_name']}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await controller.deleteBuildInfo(build.$id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
