abstract final class Routes {
  static const home = '/';
  static const session = '/session/:id';

  /// The path to open a specific session, e.g. /session/7
  static String sessionPath(int id) => '/session/$id';
}