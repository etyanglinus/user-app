import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fasta_deliveries/api/api_client.dart';

class OrderSupportDialog extends StatefulWidget {
  const OrderSupportDialog({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderSupportDialog> createState() => _OrderSupportDialogState();
}

class _OrderSupportDialogState extends State<OrderSupportDialog> {
  final _api = Get.find<ApiClient>();
  final _description = TextEditingController();
  final _random = Random.secure();
  List<dynamic> _cases = [];
  int _page = 1;
  int? _caseId;
  bool _hasMore = false;
  bool _busy = false;
  String _kind = 'support';
  String? _feedback;
  String? _submissionId;
  (int?, String, String)? _lastSubmission;

  String get _endpoint => '/api/v1/customer/orders/' + widget.orderId.toString() + '/cases';

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  String _newSubmissionId() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return [
      hex.substring(0, 8), hex.substring(8, 12), hex.substring(12, 16),
      hex.substring(16, 20), hex.substring(20),
    ].join('-');
  }

  Future<void> _load(int page) async {
    setState(() => _busy = true);
    try {
      final response = await _api.getData(_endpoint, query: {'page': page}, handleError: false);
      final body = response.body;
      if (response.statusCode != 200 || body is! Map || body['data'] is! List) {
        throw StateError('Order cases could not be loaded');
      }
      if (!mounted) return;
      setState(() {
        _cases = body['data'] as List;
        _page = page;
        _hasMore = body['next_page_url'] != null;
      });
    } catch (_) {
      if (mounted) setState(() => _feedback = 'Could not load support cases.'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final description = _description.text.trim();
    if (_busy || description.isEmpty) return;

    final target = _caseId;
    final fingerprint = (target, _kind, description);
    if (_lastSubmission != fingerprint) {
      _lastSubmission = fingerprint;
      _submissionId = _newSubmissionId();
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final response = await _api.postData(
        target == null ? _endpoint : '$_endpoint/$target/evidence',
        {
          'submission_id': _submissionId,
          if (target == null) 'kind': _kind,
          'description': description,
        },
        handleError: false,
      );
      if (response.statusCode != 202) throw StateError('Order case submission failed');
      if (!mounted) return;
      _description.clear();
      _lastSubmission = null;
      _submissionId = null;
      setState(() {
        _caseId = null;
        _feedback = 'Submission recorded.'.tr;
      });
      await _load(target == null ? 1 : _page);
    } catch (_) {
      if (mounted) setState(() => _feedback = 'Could not submit. Check the case or retry.'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const statuses = {'open': 'Open', 'in_review': 'In review', 'closed': 'Closed'};

    return AlertDialog(
      title: Text('Order support'.tr),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_feedback != null) Text(_feedback!),
            if (_busy) const LinearProgressIndicator(),
            if (_caseId == null)
              DropdownButton<String>(
                value: _kind,
                onChanged: _busy ? null : (value) => setState(() => _kind = value!),
                items: [
                  DropdownMenuItem(value: 'support', child: Text('Support request'.tr)),
                  DropdownMenuItem(value: 'dispute', child: Text('Order dispute'.tr)),
                ],
              )
            else
              TextButton(
                onPressed: _busy ? null : () => setState(() => _caseId = null),
                child: Text('Back to new case'.tr),
              ),
            TextField(
              controller: _description,
              enabled: !_busy,
              maxLength: 3000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: (_caseId == null ? 'Describe the issue' : 'Add evidence or details').tr,
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text((_caseId == null ? 'Submit case' : 'Submit evidence').tr),
            ),
            for (final item in _cases.whereType<Map>())
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#' + item['id'].toString() + ' · ' + (statuses[item['status']] ?? '').tr),
                      Text(item['description']?.toString() ?? ''),
                      for (final evidence in (item['evidence'] as List? ?? []).whereType<Map>())
                        Text(evidence['description']?.toString() ?? ''),
                      if (item['decision'] != null)
                        Text('Decision'.tr + ' · ' + item['decision'].toString()),
                      if (item['status'] != 'closed' && item['id'] is int)
                        TextButton(
                          onPressed: _busy ? null : () => setState(() => _caseId = item['id'] as int),
                          child: Text('Add evidence'.tr),
                        ),
                    ],
                  ),
                ),
              ),
            Wrap(children: [
              if (_page > 1)
                TextButton(onPressed: _busy ? null : () => _load(_page - 1), child: Text('Previous'.tr)),
              if (_hasMore)
                TextButton(onPressed: _busy ? null : () => _load(_page + 1), child: Text('Next'.tr)),
              TextButton(onPressed: _busy ? null : () => _load(_page), child: Text('Refresh'.tr)),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close'.tr)),
      ],
    );
  }
}
