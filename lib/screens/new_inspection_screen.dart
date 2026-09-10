import 'package:flutter/material.dart';

import '../widgets/session_save_boundary.dart';

import '../models/inspection_session.dart';
import '../services/inspection_repository.dart';
import '../services/mock_customer_service.dart';
import '../services/mock_vehicle_service.dart';
import '../services/mock_verification_service.dart';
import '../widgets/readiness_row.dart';
import '../widgets/step_circle.dart';
import '../widgets/verification_row.dart';
import '../widgets/session_banner.dart';
import 'guided_inspection_screen.dart';

class NewInspectionScreen extends StatefulWidget {
  final InspectionSession? session;
  final InspectionRepository? repository;
  const NewInspectionScreen({super.key, this.session, this.repository});
  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  late final repository = widget.repository ?? InMemoryInspectionRepository();
  late final session =
      widget.session ?? repository.create(technician: 'Armand');
  late final phoneController = TextEditingController(
    text: session.customer?.phone ?? '',
  );
  bool busy = false;
  String? error;

  Future<void> runIntake(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Demo data could not load. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> searchCustomer() => runIntake(() async {
    final result = await MockCustomerService().findCustomerByPhone(
      phoneController.text,
    );
    if (mounted && session.active) session.setCustomer(result);
  });
  Future<void> scanVin() => runIntake(() async {
    final vehicle = await MockVehicleService().scanVinBarcode();
    final items = await MockVerificationService().verifyVehicle();
    if (mounted && session.active) session.setVehicle(vehicle, items);
  });
  void unavailable(String action) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$action is not implemented. Use the explicitly labeled demo sample controls.',
      ),
    ),
  );
  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Widget card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SessionSaveBoundary(
    session: session,
    repository: repository,
    child: buildScreen(context),
  );

  Widget buildScreen(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Project Verify',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 18,
                      runSpacing: 12,
                      children: const [
                        StepCircle(
                          number: '1',
                          label: 'Customer',
                          active: true,
                        ),
                        StepCircle(number: '2', label: 'Vehicle', active: true),
                        StepCircle(number: '3', label: 'Inspection'),
                        StepCircle(number: '4', label: 'AI Review'),
                        StepCircle(number: '5', label: 'Report'),
                      ],
                    ),
                  ),
                ),
                SessionBanner(session: session),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 18),
                card('CUSTOMER', [
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Customer Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : searchCustomer,
                        icon: const Icon(Icons.search),
                        label: const Text('LOAD DEMO CUSTOMER'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => unavailable('New customer creation'),
                        icon: const Icon(Icons.person_add),
                        label: const Text('NEW CUSTOMER'),
                      ),
                    ],
                  ),
                  if (session.customer != null) ...[
                    const Divider(height: 30),
                    Text(
                      session.customer!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${session.customer!.phone}\n${session.customer!.email ?? ''}\nDEMO sample customer; phone is user-entered. No Square lookup.',
                    ),
                  ],
                ]),
                const SizedBox(height: 18),
                card('VEHICLE IDENTIFICATION', [
                  FilledButton.icon(
                    onPressed: busy ? null : scanVin,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('SIMULATE VIN SCAN'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => unavailable('License plate scanning'),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('SCAN LICENSE PLATE'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => unavailable('Manual VIN decoding'),
                        icon: const Icon(Icons.keyboard),
                        label: const Text('ENTER VIN MANUALLY'),
                      ),
                    ],
                  ),
                  if (session.vehicle != null) ...[
                    const Divider(height: 30),
                    Text(
                      session.vehicle!.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Sample VIN: ${session.vehicle!.vin}\n${session.vehicle!.engine} • ${session.vehicle!.drivetrain}',
                    ),
                    const Text('DEMO VIN DECODE • UNVERIFIED'),
                  ],
                ]),
                const SizedBox(height: 18),
                card('VEHICLE VERIFICATION', [
                  const Text(
                    'Future providers: AMSOIL for oil data; ShowMeTheParts for Service Champ filters only. Neither is connected.',
                  ),
                  const Divider(height: 28),
                  if (session.verificationItems.isEmpty)
                    const Text(
                      'Simulate a VIN scan to display demo placeholders.',
                    ),
                  ...session.verificationItems.map(
                    (item) => VerificationRow(item: item),
                  ),
                ]),
                const SizedBox(height: 18),
                card('SQUARE / POS', [
                  Text(
                    session.squareSimulated
                        ? 'DEMO link acknowledged. No transaction exists or was linked.'
                        : 'Square integration is not implemented.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : session.simulateSquare,
                    icon: const Icon(Icons.link),
                    label: Text(
                      session.squareSimulated
                          ? 'DEMO LINK ACKNOWLEDGED'
                          : 'SIMULATE SQUARE LINK',
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                card('DEMO INSPECTION READINESS', [
                  const Text(
                    'These checks unlock the prototype only. Real-service verification remains unavailable.',
                  ),
                  ReadinessRow(
                    label: 'Demo customer selected',
                    complete: session.customer != null,
                  ),
                  ReadinessRow(
                    label: 'Simulated VIN decode loaded',
                    complete: session.vehicle != null,
                  ),
                  ReadinessRow(
                    label:
                        'Unverified specification/filter placeholders loaded',
                    complete: session.verificationItems.isNotEmpty,
                  ),
                  ReadinessRow(
                    label: 'Simulated Square link acknowledged',
                    complete: session.squareSimulated,
                  ),
                ]),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: !busy && session.demoReady
                      ? () => saveAndProceed(
                          context,
                          session,
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GuidedInspectionScreen(
                                session: session,
                                repository: repository,
                              ),
                            ),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('START DEMO INSPECTION'),
                  ),
                ),
                if (!session.demoReady)
                  const Text(
                    'Complete the demo readiness items above.',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
