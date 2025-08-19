import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appwrite 登录'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 账号输入框
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '账号',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入账号';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 密码输入框
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Obx(() => Icon(
                          controller.isPasswordVisible.value
                              ? Icons.visibility
                              : Icons.visibility_off,
                        )),
                    onPressed: controller.togglePasswordVisibility,
                  ),
                ),
                obscureText: !controller.isPasswordVisible.value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  if (value.length < 6) {
                    return '密码长度不能少于6位';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      controller.login(
                        email: _emailController.text,
                        password: _passwordController.text,
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('登录'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
