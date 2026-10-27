abstract final class Routes {
  static const home = '/';
  static const session = '/session/:id';
  static const review = '/review/:id';

  /// The path to open a specific session, e.g. /session/7
  static String sessionPath(int id) => '/session/$id';

  /// The path to review a finished session, e.g. /review/7
  static String reviewPath(int id) => '/review/$id';
}