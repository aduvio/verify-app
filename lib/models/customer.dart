class Customer {
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;

  const Customer({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
  });

  String get displayName => '$firstName $lastName';
}
