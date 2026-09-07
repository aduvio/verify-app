import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/vehicle.dart';
import '../models/verification_item.dart';
import '../services/mock_customer_service.dart';
import '../services/mock_vehicle_service.dart';
import '../services/mock_verification_service.dart';
import '../widgets/readiness_row.dart';
import '../widgets/step_circle.dart';
import '../widgets/verification_row.dart';

class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final phoneController = TextEditingController();

  final customerService = MockCustomerService();
  final vehicleService = MockVehicleService();
  final verificationService = MockVerificationService();

  Customer? customer;
  Vehicle? vehicle;
  List<VerificationItem> verificationItems = [];

  bool squareLinked = false;
  bool busy = false;

  bool get customerFound => customer != null;
  bool get vinCaptured => vehicle != null;
  bool get vehicleDecoded => vehicle != null;

  bool get oilSpecsVerified =>
      verificationItems.any((item) =>
          item.label == 'Oil Viscosity' &&
          item.status == VerificationStatus.verified) &&
      verificationItems.any((item) =>
          item.label == 'Oil Capacity' &&
          item.status == VerificationStatus.verified);

  bool get filterVerified =>
      verificationItems.any((item) =>
          item.label == 'Oil Filter' &&
          item.status == VerificationStatus.verified);

  bool get readyToStart =>
      customerFound &&
      vinCaptured &&
      vehicleDecoded &&
      oilSpecsVerified &&
      filterVerified &&
      squareLinked;

  Future<void> searchCustomer() async {
    setState(() => busy = true);
    final result =
        await customerService.findCustomerByPhone(phoneController.text);
    if (!mounted) return;
    setState(() {
      customer = result;
      busy = false;
    });
  }

  Future<void> scanVin() async {
    setState(() => busy = true);
    final vehicleResult = await vehicleService.scanVinBarcode();
    final verificationResult = await verificationService.verifyVehicle();
    if (!mounted) return;
    setState(() {
      vehicle = vehicleResult;
      verificationItems = verificationResult;
      busy = false;
    });
  }

  void linkSquare() {
    setState(() => squareLinked = true);
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue, size: 32),
            SizedBox(width: 10),
            Text(
              'Project Verify',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                'Costa Oil Change - Chalmette   |   Tech: Armand',
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildProgress(),
                    const SizedBox(height: 18),
                    _buildCustomerCard(),
                    const SizedBox(height: 18),
                    _buildVehicleCard(),
                    const SizedBox(height: 18),
                    _buildVerificationCard(),
                    const SizedBox(height: 18),
                    _buildSquareCard(),
                    const SizedBox(height: 18),
                    _buildReadinessCard(),
                    const SizedBox(height: 18),
                    _buildStartButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
          if (busy)
            const ColoredBox(
              color: Color(0x22000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            StepCircle(number: '1', label: 'Customer', active: true),
            StepCircle(number: '2', label: 'Vehicle', active: true),
            StepCircle(number: '3', label: 'Inspection'),
            StepCircle(number: '4', label: 'AI Review'),
            StepCircle(number: '5', label: 'Report'),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CUSTOMER',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Customer Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: busy ? null : searchCustomer,
                    icon: const Icon(Icons.search),
                    label: const Text('SEARCH'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : searchCustomer,
              icon: const Icon(Icons.person_add),
              label: const Text('NEW CUSTOMER'),
            ),
            if (customer != null) ...[
              const Divider(height: 30),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(
                  customer!.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${customer!.phone}\n${customer!.email ?? ''}\nExisting customer data will eventually come from Square.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'VEHICLE IDENTIFICATION',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 64,
              child: FilledButton.icon(
                onPressed: busy ? null : scanVin,
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text(
                  'SCAN VIN BARCODE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('SCAN LICENSE PLATE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : scanVin,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('ENTER VIN MANUALLY'),
                  ),
                ),
              ],
            ),
            if (vehicle != null) ...[
              const Divider(height: 30),
              ListTile(
                leading: const Icon(
                  Icons.directions_car,
                  size: 36,
                  color: Colors.blue,
                ),
                title: Text(
                  vehicle!.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  'VIN: ${vehicle!.vin}\n${vehicle!.engine}   •   ${vehicle!.drivetrain}',
                ),
                trailing: const Chip(label: Text('VIN DECODED')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.fact_check),
                SizedBox(width: 8),
                Text(
                  'VEHICLE VERIFICATION',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'AMSOIL is the primary oil source. ShowMeTheParts is restricted to Service Champ filters.',
            ),
            const Divider(height: 28),
            if (verificationItems.isEmpty)
              const Text('Scan the VIN to begin vehicle verification.')
            else
              ...verificationItems.map(
                (item) => VerificationRow(item: item),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.link, color: Colors.green, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SQUARE / POS',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    squareLinked
                        ? 'Mock Square transaction linked.'
                        : 'Square is not linked yet.',
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: linkSquare,
              icon: const Icon(Icons.link),
              label: Text(
                squareLinked ? 'LINKED' : 'LINK SQUARE TRANSACTION',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'INSPECTION READINESS',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ReadinessRow(
              label: 'Customer identified',
              complete: customerFound,
            ),
            ReadinessRow(label: 'VIN captured', complete: vinCaptured),
            ReadinessRow(
              label: 'Vehicle decoded',
              complete: vehicleDecoded,
            ),
            ReadinessRow(
              label: 'Oil specifications verified',
              complete: oilSpecsVerified,
            ),
            ReadinessRow(
              label: 'Service Champ filter verified',
              complete: filterVerified,
            ),
            ReadinessRow(
              label: 'Square/customer information linked',
              complete: squareLinked,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.icon(
            onPressed: readyToStart
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'SCR-001 complete. SCR-002 will connect here.',
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text(
              'START INSPECTION',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (!readyToStart)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Complete all required items above to start the inspection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
