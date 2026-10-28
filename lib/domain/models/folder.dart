/// A folder that can contain sessions.
class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
}
