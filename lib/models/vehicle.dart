class Vehicle {
  final String vin;
  final int year;
  final String make;
  final String model;
  final String trim;
  final String engine;
  final String drivetrain;

  const Vehicle({
    required this.vin,
    required this.year,
    required this.make,
    required this.model,
    required this.trim,
    required this.engine,
    required this.drivetrain,
  });

  String get displayName => '$year $make $model $trim';
}
