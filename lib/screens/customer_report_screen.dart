import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/inspection_session.dart';
import '../services/mock_delivery_service.dart';
import '../widgets/reason_dialog.dart';

class CustomerReportScreen extends StatefulWidget {
  final InspectionSession session;
  final DeliveryService service;
  const CustomerReportScreen({
    super.key,
    required this.session,
    this.service = const MockDeliveryService(),
  });
  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  InspectionSession get session => widget.session;
  bool simulateFailure = false;
  @override
  void initState() {
    super.initState();
    // Defer notification until navigation has finished building its widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !session.reportCurrent) session.prepareReport();
    });
  }

  Future<void> correctContact() async {
    final channel = session.deliveryChannel;
    final result = await requestReasons(context, 'Correct session contact', [
      channel == DeliveryChannel.sms ? 'Customer phone' : 'Customer email',
    ]);
    if (!mounted || result == null || session.customer == null) return;
    final old = session.customer!;
    session.setCustomer(
      Customer(
        firstName: old.firstName,
        lastName: old.lastName,
        phone: channel == DeliveryChannel.sms ? result.first : old.phone,
        email: channel == DeliveryChannel.email ? result.first : old.email,
      ),
    );
  }

  Widget card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final data = session.reportCurrent ? session.reportSnapshot!.data : null;
      final customer = data?['customer'] as Map<String, Object?>?;
      final vehicle = data?['vehicle'] as Map<String, Object?>?;
      final recommendation = data?['recommendation'] as Map<String, Object?>?;
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Report — Demo')),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data == null)
                      card('Report needs review', [
                        ...session.reportBlockers.map((b) => Text('• $b')),
                        if (session.demoApproved)
                          FilledButton(
                            onPressed: session.prepareReport,
                            child: const Text('PREPARE UPDATED DEMO PREVIEW'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('RETURN TO SCR-003 REVIEW'),
                        ),
                      ])
                    else
                      card('CUSTOMER PREVIEW', [
                        Text(
                          '${data['product']}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text('${data['location']}'),
                        const SizedBox(height: 12),
                        Text(
                          '${data['reportStatus']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Customer: ${customer?['name'] ?? 'Unavailable'} (sample intake)',
                        ),
                        Text(
                          'Vehicle: ${vehicle?['description'] ?? 'Unavailable'} (sample VIN decoding)',
                        ),
                        Text(
                          'VIN: ${vehicle?['vin'] ?? 'Unavailable'} (sample)',
                        ),
                        Text('Inspection: ${data['inspectionId']}'),
                        Text('Created: ${data['createdAt']}'),
                        Text(
                          'Technician: ${data['technician']} (demo identity)',
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.videocam_off_outlined, size: 40),
                              Text(
                                'Watch My Inspection',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Playback unavailable. This demo contains simulated metadata, not video files.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Documented demo checks',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'These entries document prototype activity, not verified service completion.',
                        ),
                        for (final check in data['documentedChecks'] as List)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${check['label']}: ${check['result']}',
                            ),
                          ),
                        const Text(
                          'Verified specifications, oil quantity and filter part number: unavailable.',
                        ),
                        if (recommendation != null &&
                            (recommendation['text'] as String)
                                .trim()
                                .isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Technician-reviewed recommendation — demo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${recommendation['text']}'),
                          Text(
                            'By ${recommendation['author']} • ${recommendation['updatedAt']}',
                          ),
                          const Text(
                            'Recommendation only; not a completed service fact.',
                          ),
                        ],
                      ]),
                    const SizedBox(height: 16),
                    card('TECHNICIAN DELIVERY CONTROLS — DEMO', [
                      const Text(
                        'Inactive demo-link placeholder — no hosted or secured link exists.',
                      ),
                      const Text(
                        'Customers will not need an account when secure delivery is connected.',
                      ),
                      const Text(
                        'Session and delivery history are in memory and can be lost on refresh or close.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DeliveryChannel>(
                        initialValue: session.deliveryChannel,
                        decoration: const InputDecoration(
                          labelText: 'Simulated delivery channel',
                        ),
                        items: DeliveryChannel.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: session.sending
                            ? null
                            : (v) {
                                if (v != null) session.selectDeliveryChannel(v);
                              },
                      ),
                      Text(
                        'Session recipient: ${session.recipient.isEmpty ? 'Unavailable' : session.recipient}',
                      ),
                      if (session.recipientProblem != null)
                        Text(session.recipientProblem!),
                      TextButton(
                        onPressed: session.sending ? null : correctContact,
                        child: const Text('CORRECT SESSION CONTACT'),
                      ),
                      const Text(
                        'Contact changes require renewed SCR-003 approval and preview review.',
                      ),
                      for (var i = 0; i < 2; i++)
                        CheckboxListTile(
                          key: ValueKey('delivery-confirm-$i'),
                          contentPadding: EdgeInsets.zero,
                          value: session.deliveryConfirmations[i],
                          onChanged:
                              session.reportCurrent &&
                                  session.recipientProblem == null &&
                                  !session.sending
                              ? (v) => session.setDeliveryConfirmation(
                                  i,
                                  v ?? false,
                                )
                              : null,
                          title: Text(
                            i == 0
                                ? 'I reviewed this preview and the selected recipient.'
                                : 'This preview contains only the intended customer-visible information.',
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Simulate a delivery failure (demo test)',
                        ),
                        value: simulateFailure,
                        onChanged: session.sending
                            ? null
                            : (v) => setState(() => simulateFailure = v),
                      ),
                      FilledButton(
                        key: const ValueKey('simulate-send'),
                        onPressed: session.canSimulateSend
                            ? () => session.simulateDelivery(
                                simulateFailure
                                    ? const MockDeliveryService(fail: true)
                                    : widget.service,
                              )
                            : null,
                        child: Text(
                          session.sending
                              ? 'SIMULATION PENDING…'
                              : 'SIMULATE SEND — DEMO',
                        ),
                      ),
                      if (session.deliveryMessage != null)
                        Text(
                          session.deliveryMessage!,
                          key: const ValueKey('delivery-result'),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
