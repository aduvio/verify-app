import '../models/vehicle.dart';

class MockVehicleService {
  Future<Vehicle> scanVinBarcode() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return const Vehicle(
      vin: 'SAMPLEVIN1234567',
      year: 2024,
      make: 'Toyota',
      model: 'Camry',
      trim: 'SE',
      engine: '2.5L',
      drivetrain: 'FWD',
    );
  }
}
