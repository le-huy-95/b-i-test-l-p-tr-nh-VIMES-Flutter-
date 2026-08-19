({String? email, String? phone}) splitCredentials(String raw) {
  final v = raw.trim();
  if (v.contains('@')) {
    return (email: v, phone: null);
  }
  return (email: null, phone: v);
}
