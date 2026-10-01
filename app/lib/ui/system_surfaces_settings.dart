import 'package:flutter/material.dart';

import '../services/system_surfaces.dart';

/// Mounted only on Android; each opening reads native persisted state.
class SystemSurfacesSettings extends StatefulWidget {
  const SystemSurfacesSettings({super.key});

  @override
  State<SystemSurfacesSettings> createState() => _SystemSurfacesSettingsState();
}

class _SystemSurfacesSettingsState extends State<SystemSurfacesSettings>
    with WidgetsBindingObserver {
  SystemSurfacesStatus? _status;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load() => _run(() async {
    _status = await SystemSurfaces.status();
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) _message = '系统设置暂不可用，请重试';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notification(bool enabled) => _run(() async {
    if (enabled) {
      final allowed = await SystemSurfaces.requestPermission();
      if (!mounted) return;
      if (!allowed) {
        _status = await SystemSurfaces.status();
        _message = '未获通知权限，通知栏余额没有开启';
        return;
      }
    }
    if (!mounted) return;
    _status = await SystemSurfaces.setNotificationEnabled(enabled);
    if (!mounted) return;
    if (enabled && !_status!.notificationsAllowed) {
      _status = await SystemSurfaces.setNotificationEnabled(false);
      _message = '系统通知或余额通知频道已关闭，请在手机的应用通知设置中开启后重试';
    } else if (enabled && !_status!.notificationEnabled) {
      _message = '系统没有启用通知栏余额，请重试';
    } else {
      _message = enabled ? '通知栏显示上次查询结果，查询成功后更新' : '通知栏余额已关闭';
    }
  });

  Future<void> _tile(bool enabled) => _run(() async {
    _status = await SystemSurfaces.setTileEnabled(enabled);
    if (!mounted) return;
    if (_status!.tileEnabled != enabled) {
      _message = '系统没有保存快捷开关设置，请重试';
    } else if (!enabled) {
      _message = '快捷开关入口已关闭';
    } else if (_status!.tileAddSupported) {
      await _requestTile();
    } else {
      _message = '入口已启用，请下拉快捷设置，点编辑后将「流量小伙伴」拖入';
    }
  });

  Future<void> _requestTile() async {
    final outcome = await SystemSurfaces.requestAddTile();
    if (!mounted) return;
    _message = switch (outcome) {
      'added' => '已添加快捷开关，点击后打开应用查询',
      'already_added' => '系统中已有快捷开关',
      'canceled' => '已取消系统添加；入口仍启用，可以重新添加',
      'unsupported' => '请下拉快捷设置，点编辑后将「流量小伙伴」拖入',
      _ => '系统暂未添加快捷开关，请重试或下拉快捷设置手动编辑',
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('通知栏与快捷开关', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text(
          '这两项即时保存，默认关闭；展示上次查询结果。',
          style: TextStyle(fontSize: 12, color: Color(0xFF777D87)),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (status != null) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('通知栏余额'),
            subtitle: Text(
              status.notificationEnabled && !status.notificationsAllowed
                  ? '系统通知或余额频道已关闭，当前无法展示'
                  : '保留最近查询的余额和时间',
            ),
            value: status.notificationEnabled,
            onChanged: _busy ? null : _notification,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('快捷设置入口'),
            subtitle: const Text('启用后还需添加到系统快捷设置，点击打开应用查询'),
            value: status.tileEnabled,
            onChanged: _busy ? null : _tile,
          ),
          if (status.tileEnabled)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_requestTile),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(status.tileAddSupported ? '添加到系统快捷设置' : '查看手动添加说明'),
            ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_message!, style: const TextStyle(fontSize: 12)),
          ),
        if (status == null && !_busy)
          TextButton(onPressed: _load, child: const Text('重试读取系统设置')),
        const SizedBox(height: 12),
      ],
    );
  }
}
