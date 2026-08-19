class WarehouseMapPickResult {
  const WarehouseMapPickResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}

String composeWarehouseAddress(Iterable<String?> parts) {
  return parts
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join(', ');
}
