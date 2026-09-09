import '../models/verification_item.dart';

class MockVerificationService {
  Future<List<VerificationItem>> verifyVehicle() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return const [
      VerificationItem(
        label: 'Oil Viscosity',
        value: 'SAMPLE - pending live AMSOIL',
        source: 'AMSOIL',
        status: VerificationStatus.notAvailable,
      ),
      VerificationItem(
        label: 'Oil Capacity',
        value: 'SAMPLE - pending live AMSOIL',
        source: 'AMSOIL',
        status: VerificationStatus.notAvailable,
      ),
      VerificationItem(
        label: 'Oil Filter',
        value: 'Service Champ - mock data',
        source: 'ShowMeTheParts',
        status: VerificationStatus.notAvailable,
      ),
      VerificationItem(
        label: 'Air Filter',
        value: 'Service Champ - mock data',
        source: 'ShowMeTheParts',
        status: VerificationStatus.notAvailable,
      ),
      VerificationItem(
        label: 'Cabin Air Filter',
        value: 'Service Champ - mock data',
        source: 'ShowMeTheParts',
        status: VerificationStatus.notAvailable,
      ),
    ];
  }
}
