import 'package:flutter/material.dart';

void main() {
  runApp(const ProjectVerifyApp());
}

class ProjectVerifyApp extends StatelessWidget {
  const ProjectVerifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Project Verify',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const NewInspectionScreen(),
    );
  }
}

class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final TextEditingController phoneController = TextEditingController();

  bool customerFound = false;
  bool vinCaptured = false;
  bool vehicleDecoded = false;
  bool oilSpecsVerified = false;
  bool filterVerified = false;
  bool squareLinked = false;

  bool get readyToStart =>
      customerFound &&
      vinCaptured &&
      vehicleDecoded &&
      oilSpecsVerified &&
      filterVerified &&
      squareLinked;

  void searchCustomer() {
    setState(() {
      customerFound = true;
    });
  }

  void scanVin() {
    setState(() {
      vinCaptured = true;
      vehicleDecoded = true;
      oilSpecsVerified = true;
      filterVerified = true;
    });
  }

  void linkSquare() {
    setState(() {
      squareLinked = true;
    });
  }

  Widget statusRow(String label, bool complete) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: complete ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  Widget verificationRow(
    String item,
    String value,
    String source,
    String status,
    Color statusColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
          Expanded(
            flex: 2,
            child: Text(
              source,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
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
            Icon(
              Icons.verified_user,
              color: Colors.blue,
              size: 32,
            ),
            SizedBox(width: 10),
            Text(
              'Project Verify',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _StepCircle(
                          number: '1',
                          label: 'Customer',
                          active: true,
                        ),
                        _StepCircle(
                          number: '2',
                          label: 'Vehicle',
                          active: true,
                        ),
                        _StepCircle(
                          number: '3',
                          label: 'Inspection',
                        ),
                        _StepCircle(
                          number: '4',
                          label: 'AI Review',
                        ),
                        _StepCircle(
                          number: '5',
                          label: 'Report',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'CUSTOMER',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                                onPressed: searchCustomer,
                                icon: const Icon(Icons.search),
                                label: const Text('SEARCH'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: searchCustomer,
                          icon: const Icon(Icons.person_add),
                          label: const Text('NEW CUSTOMER'),
                        ),
                        if (customerFound) ...[
                          const Divider(height: 30),
                          const ListTile(
                            leading: CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(
                              'Sample Customer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '504-555-1212\nExisting customer data will eventually come from Square.',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'VEHICLE IDENTIFICATION',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 64,
                          child: FilledButton.icon(
                            onPressed: scanVin,
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              size: 28,
                            ),
                            label: const Text(
                              'SCAN VIN BARCODE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
                                label: const Text(
                                  'SCAN LICENSE PLATE',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: scanVin,
                                icon: const Icon(Icons.keyboard),
                                label: const Text(
                                  'ENTER VIN MANUALLY',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (vehicleDecoded) ...[
                          const Divider(height: 30),
                          const ListTile(
                            leading: Icon(
                              Icons.directions_car,
                              size: 36,
                              color: Colors.blue,
                            ),
                            title: Text(
                              '2024 Toyota Camry SE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              'VIN: SAMPLEVIN1234567\n2.5L Engine   •   FWD',
                            ),
                            trailing: Chip(
                              label: Text('VIN DECODED'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Card(
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
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'AMSOIL is the primary oil source. ShowMeTheParts is restricted to Service Champ filters.',
                        ),
                        const Divider(height: 28),

                        verificationRow(
                          'Oil Viscosity',
                          vehicleDecoded
                              ? 'SAMPLE - pending live AMSOIL'
                              : 'Not checked',
                          'AMSOIL',
                          oilSpecsVerified
                              ? 'VERIFIED'
                              : 'WAITING',
                          oilSpecsVerified
                              ? Colors.green
                              : Colors.grey,
                        ),
                        verificationRow(
                          'Oil Capacity',
                          vehicleDecoded
                              ? 'SAMPLE - pending live AMSOIL'
                              : 'Not checked',
                          'AMSOIL',
                          oilSpecsVerified
                              ? 'VERIFIED'
                              : 'WAITING',
                          oilSpecsVerified
                              ? Colors.green
                              : Colors.grey,
                        ),
                        verificationRow(
                          'Oil Filter',
                          vehicleDecoded
                              ? 'Service Champ - mock data'
                              : 'Not checked',
                          'ShowMeTheParts',
                          filterVerified
                              ? 'VERIFIED'
                              : 'WAITING',
                          filterVerified
                              ? Colors.green
                              : Colors.grey,
                        ),
                        verificationRow(
                          'Air Filter',
                          vehicleDecoded
                              ? 'Service Champ - mock data'
                              : 'Not checked',
                          'ShowMeTheParts',
                          filterVerified
                              ? 'VERIFIED'
                              : 'WAITING',
                          filterVerified
                              ? Colors.green
                              : Colors.grey,
                        ),
                        verificationRow(
                          'Cabin Air Filter',
                          vehicleDecoded
                              ? 'Service Champ - mock data'
                              : 'Not checked',
                          'ShowMeTheParts',
                          filterVerified
                              ? 'VERIFIED'
                              : 'WAITING',
                          filterVerified
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link,
                          color: Colors.green,
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SQUARE / POS',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
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
                            squareLinked
                                ? 'LINKED'
                                : 'LINK SQUARE TRANSACTION',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'INSPECTION READINESS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        statusRow(
                          'Customer identified',
                          customerFound,
                        ),
                        statusRow(
                          'VIN captured',
                          vinCaptured,
                        ),
                        statusRow(
                          'Vehicle decoded',
                          vehicleDecoded,
                        ),
                        statusRow(
                          'Oil specifications verified',
                          oilSpecsVerified,
                        ),
                        statusRow(
                          'Service Champ filter verified',
                          filterVerified,
                        ),
                        statusRow(
                          'Square/customer information linked',
                          squareLinked,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: readyToStart
                        ? () {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final String number;
  final String label;
  final bool active;

  const _StepCircle({
    required this.number,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor:
              active ? Colors.blue : Colors.grey.shade300,
          foregroundColor:
              active ? Colors.white : Colors.black54,
          child: Text(number),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.blue : Colors.grey,
            fontWeight:
                active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}