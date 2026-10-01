import 'package:flutter/material.dart';

import '../data/carrier_accounts.dart';

/// Owns its controllers until the dialog's closing animation is disposed.
class AccountIdentityDialog extends StatefulWidget {
  const AccountIdentityDialog({super.key, required this.account});

  final CarrierAccount account;

  @override
  State<AccountIdentityDialog> createState() => _AccountIdentityDialogState();
}

class _AccountIdentityDialogState extends State<AccountIdentityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _note = TextEditingController(text: widget.account.note ?? '');
  late final _phone = TextEditingController(
    text: widget.account.phoneNumber ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('给${widget.account.label}做个备注'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _note,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '例如：主卡、上网卡',
              ),
              validator: (value) => CarrierAccount.validateNote(value ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 16,
              decoration: const InputDecoration(labelText: '号码（选填）'),
              validator: (value) =>
                  CarrierAccount.validatePhoneNumber(value ?? ''),
            ),
            const SizedBox(height: 12),
            const Text(
              '只保存在本机，卡片默认隐藏号码中间几位。备注不改变官网登录的号码。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, (_note.text, _phone.text));
          }
        },
        child: const Text('保存'),
      ),
    ],
  );
}
