import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../constants.dart';
import '../../../providers/client_auth_provider.dart';
import '../../../providers/master_auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/phone_launcher.dart';
import '../../../widgets/app_cached_image.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/project_storage_service.dart';
import '../models/service_request.dart';
import '../services/service_requests_api.dart';

enum ServiceRequestViewer { client, master }

class ServiceRequestDetailPage extends StatefulWidget {
  const ServiceRequestDetailPage({
    super.key,
    required this.request,
    required this.viewer,
  });

  final ServiceRequest request;
  final ServiceRequestViewer viewer;

  @override
  State<ServiceRequestDetailPage> createState() =>
      _ServiceRequestDetailPageState();
}

class _ServiceRequestDetailPageState extends State<ServiceRequestDetailPage> {
  late ServiceRequest _request;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  String get _token {
    if (widget.viewer == ServiceRequestViewer.master) {
      return Provider.of<MasterAuthProvider>(context, listen: false)
              .accessToken ??
          '';
    }
    return Provider.of<ClientAuthProvider>(context, listen: false)
            .accessToken ??
        '';
  }

  Future<void> _respond() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final priceCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('sr_respond')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: settings.t('sr_my_price')),
            ),
            TextField(
              controller: commentCtrl,
              decoration: InputDecoration(labelText: settings.t('sr_comment')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(settings.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(settings.t('save')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final updated = await ServiceRequestsApi.instance.respond(
        token: _token,
        id: _request.id,
        proposedPrice: double.tryParse(
          priceCtrl.text.trim().replaceAll(',', '.'),
        ),
        comment: commentCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _request = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      final updated = await ServiceRequestsApi.instance.updateStatus(
        token: _token,
        id: _request.id,
        status: status,
      );
      if (!mounted) return;
      setState(() => _request = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convertToCrm() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() => _busy = true);
    try {
      final crm = await ServiceRequestsApi.instance.convertToCrm(
        token: _token,
        id: _request.id,
      );
      final income = double.tryParse('${crm['income']}') ?? 0;
      final project = ProjectModel(
        id: const Uuid().v4(),
        title: '${crm['title'] ?? _request.title}',
        client: '${crm['client'] ?? _request.clientName}',
        phone: '${crm['phone'] ?? _request.clientPhone}',
        address: '${crm['address'] ?? _request.address}',
        income: income > 0 ? income : 1,
        receivedAmount: 0,
        date: DateTime.now(),
        note: '${crm['note'] ?? _request.description}',
        beforeImages: const [],
        afterImages: const [],
      );
      await ProjectStorageService.instance.addProject(project);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('sr_crm_added'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _whatsApp() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final msg =
        '${settings.t('sr_wa_hello')} ${_request.title}';
    launchWhatsApp(context, _request.clientPhone, message: msg);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMaster = widget.viewer == ServiceRequestViewer.master;

    return Scaffold(
      appBar: AppBar(title: Text(_request.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _request.category,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(_request.description.isEmpty
              ? settings.t('project_no_note')
              : _request.description),
          if (_request.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${settings.t('sr_address')}: ${_request.address}'),
          ],
          if (_request.budget != null) ...[
            const SizedBox(height: 8),
            Text(
              '${settings.t('sr_budget')}: ${_request.budget!.round()} ${settings.t('currency_somoni')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (_request.clientName.isNotEmpty ||
              _request.clientPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${settings.t('project_client')}: ${_request.clientName} ${_request.clientPhone}',
            ),
          ],
          if (_request.photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _request.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: AppCachedImage(
                        imagePath: _request.photos[i],
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (isMaster) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => launchPhoneCall(
                          context,
                          _request.clientPhone,
                        ),
                    icon: const Icon(Icons.phone),
                    label: Text(settings.t('call')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentContrastText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _whatsApp,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(settings.t('project_write_whatsapp')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _respond,
              child: Text(settings.t('sr_respond')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _convertToCrm,
              child: Text(settings.t('sr_add_to_crm')),
            ),
          ] else ...[
            Text(
              settings.t('sr_responses'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_request.responses.isEmpty)
              Text(settings.t('sr_no_responses'))
            else
              ..._request.responses.map(
                (r) => Card(
                  child: ListTile(
                    title: Text(r.masterName),
                    subtitle: Text(
                      [
                        if (r.proposedPrice != null)
                          '${r.proposedPrice!.round()} ${settings.t('currency_somoni')}',
                        if (r.comment.isNotEmpty) r.comment,
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.phone),
                      onPressed: () => launchPhoneCall(context, r.masterPhone),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy || !_request.isOpen
                      ? null
                      : () => _setStatus('in_progress'),
                  child: Text(settings.t('sr_status_progress')),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _setStatus('completed'),
                  child: Text(settings.t('sr_status_done')),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _setStatus('cancelled'),
                  child: Text(settings.t('sr_status_cancelled')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
