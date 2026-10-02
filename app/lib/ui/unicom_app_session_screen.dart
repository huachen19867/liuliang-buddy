import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/carrier_accounts.dart';
import '../services/unicom_app_client.dart';

Future<UnicomAppSession?> showUnicomAppSessionScreen(
  BuildContext context, {
  required CarrierAccount account,
  bool hasSession = false,
}) => Navigator.of(context).push<UnicomAppSession>(
  MaterialPageRoute(
    builder: (_) =>
        UnicomAppSessionScreen(account: account, hasSession: hasSession),
  ),
);

/// Collects and validates a locally supplied Unicom App session.
/// Storage and network verification belong to the caller.
class UnicomAppSessionScreen extends StatefulWidget {
  const UnicomAppSessionScreen({
    super.key,
    required this.account,
    this.hasSession = false,
  });

  final CarrierAccount account;
  final bool hasSession;

  @override
  State<UnicomAppSessionScreen> createState() => _UnicomAppSessionScreenState();
}

class _UnicomAppSessionScreenState extends State<UnicomAppSessionScreen> {
  static final _mainlandPhone = RegExp(r'^1[3-9]\d{9}$');

  final _formKey = GlobalKey<FormState>();
  late final _phoneController = TextEditingController(
    text: _initialPhone(widget.account.phoneNumber),
  );
  final _sessionController = TextEditingController();
  bool _showSession = false;
  bool _confirmedCookieOwner = false;
  bool _cookieConfirmationRequired = false;
  String? _safeError;

  static String _initialPhone(String? value) =>
      value != null && _mainlandPhone.hasMatch(value.trim())
      ? value.trim()
      : '';

  @override
  void dispose() {
    _phoneController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  void _updateSessionInput(String value) {
    final needsConfirmation = _mayContainCookie(value);
    setState(() {
      // Confirmation belongs to these exact input contents and this phone.
      _confirmedCookieOwner = false;
      _cookieConfirmationRequired = needsConfirmation;
      _safeError = null;
    });
  }

  /// Treat raw input and malformed JSON as Cookie material until parsed.
  /// The service remains the authority for the accepted credential format.
  static bool _mayContainCookie(String input) {
    final value = input.trim();
    if (value.isEmpty) return false;
    if (!value.startsWith('{')) return true;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return true;
      final cookie = decoded['cookie'] ?? decoded['Cookie'];
      return cookie is String && cookie.trim().isNotEmpty;
    } on FormatException {
      return true;
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _safeError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_cookieConfirmationRequired && !_confirmedCookieOwner) {
      setState(() => _safeError = '请先确认 Cookie 与上方号码对应。');
      return;
    }

    try {
      final session = UnicomAppSession.import(
        _sessionController.text,
        phoneNumber: _phoneController.text.trim(),
        confirmedCookieOwner: _confirmedCookieOwner,
      );
      Navigator.of(context).pop(session);
    } on FormatException {
      setState(() => _safeError = '会话资料格式或号码无法确认，请检查后重试。');
    } on ArgumentError {
      setState(() => _safeError = '会话资料格式或号码无法确认，请检查后重试。');
    } catch (_) {
      // Keep service exceptions and imported credential material off screen.
      setState(() => _safeError = '暂时无法识别这份会话资料，请检查后重试。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('联通 App 会话（高级）')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NoticeCard(
                      icon: Icons.tips_and_updates_outlined,
                      color: colors.secondaryContainer,
                      child: const Text(
                        '官网网页登录遇到问题时，可手动导入本人联通 App 的会话资料。这不是一键登录，也不会自动读取联通 App；没有会话资料时，可返回继续使用官网网页登录。',
                      ),
                    ),
                    if (widget.hasSession) ...[
                      const SizedBox(height: 12),
                      _NoticeCard(
                        icon: Icons.lock_outline_rounded,
                        color: colors.surfaceContainerHighest,
                        child: const Text('本机已保存此号码的会话。新资料验证成功后，才会替换当前会话。'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      widget.account.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('unicom-app-phone'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 11,
                      onChanged: (_) {
                        if (_confirmedCookieOwner) {
                          setState(() => _confirmedCookieOwner = false);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: '联通手机号',
                        hintText: '11 位大陆手机号',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (value) =>
                          _mainlandPhone.hasMatch(value?.trim() ?? '')
                          ? null
                          : '请输入 11 位大陆手机号',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('unicom-app-session'),
                      controller: _sessionController,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: 1,
                      obscureText: !_showSession,
                      onChanged: _updateSessionInput,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '联通 App 会话资料',
                        hintText: '粘贴 Cookie 或 JSON 会话信息',
                        helperText: '本机输入，不要把验证码或服务密码填在这里。',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _showSession ? '隐藏会话资料' : '显示会话资料',
                          onPressed: () =>
                              setState(() => _showSession = !_showSession),
                          icon: Icon(
                            _showSession
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value?.trim().isNotEmpty == true ? null : '请输入会话资料',
                    ),
                    if (_cookieConfirmationRequired) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        key: const ValueKey('unicom-app-cookie-owner'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _confirmedCookieOwner,
                        onChanged: (value) => setState(() {
                          _confirmedCookieOwner = value ?? false;
                          _safeError = null;
                        }),
                        title: const Text(
                          '我确认 Cookie 来自此手机号对应的联通账号',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _NoticeCard(
                      icon: Icons.shield_outlined,
                      color: colors.surfaceContainerHighest,
                      child: const Text(
                        '验证成功后，会话保存在本机系统安全存储。验证和查询时，必要信息会发送至联通接口，不会转交给其他服务。请勿截图或转发。',
                      ),
                    ),
                    if (_safeError != null) ...[
                      const SizedBox(height: 10),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _safeError!,
                          key: const ValueKey('unicom-app-session-error'),
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('unicom-app-submit'),
                      onPressed: _submit,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('验证并连接'),
                    ),
                    TextButton(
                      key: const ValueKey('unicom-app-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消，返回连接方式'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .52),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: .72)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 12, height: 1.45),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}
