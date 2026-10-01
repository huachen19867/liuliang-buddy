import 'package:flutter/material.dart';

import 'resort_theme.dart';

/// Keeps app controls outside the official page's touch area.
class CarrierBrowserShell extends StatelessWidget {
  const CarrierBrowserShell({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
    required this.onQuery,
    required this.onReload,
    required this.onDismissKeyboard,
    required this.keyboardVisible,
    required this.child,
    this.onHelp,
  });

  final String title;
  final String message;
  final VoidCallback onClose;
  final VoidCallback onQuery;
  final VoidCallback onReload;
  final VoidCallback onDismissKeyboard;
  // Read this above Scaffold, which consumes viewInsets when resizing its body.
  final bool keyboardVisible;
  final VoidCallback? onHelp;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Material(
            color: ResortPalette.canvas,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '返回首页',
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (keyboardVisible)
                        IconButton(
                          tooltip: '收起键盘',
                          onPressed: onDismissKeyboard,
                          icon: const Icon(Icons.keyboard_hide_rounded),
                        ),
                      IconButton(
                        tooltip: '查询流量',
                        onPressed: onQuery,
                        icon: const Icon(Icons.search_rounded),
                      ),
                      IconButton(
                        tooltip: '重新加载官方页面',
                        onPressed: onReload,
                        icon: const Icon(Icons.refresh),
                      ),
                      if (onHelp != null)
                        IconButton(
                          tooltip: '登录遇到问题？',
                          onPressed: onHelp,
                          icon: const Icon(Icons.help_outline_rounded),
                        ),
                    ],
                  ),
                  // The keyboard already reduces Scaffold's available height.
                  // Give that space to the official form and its own dialogs.
                  if (!keyboardVisible && constraints.maxHeight >= 240)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ResortPalette.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: SafeArea(top: false, child: child)),
        ],
      ),
    );
  }
}
