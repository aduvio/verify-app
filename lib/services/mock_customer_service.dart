import '../models/customer.dart';

class MockCustomerService {
  Future<Customer> findCustomerByPhone(String phone) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return Customer(
      firstName: 'Sample',
      lastName: 'Customer',
      phone: phone.isEmpty ? '504-555-1212' : phone,
      email: 'sample@example.com',
    );
  }
}
