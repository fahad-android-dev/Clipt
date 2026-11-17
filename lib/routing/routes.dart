abstract final class Routes {
  static const home = '/';
  static const folder = '/folder/:id';
  static const unfiled = '/unfiled';
  static const session = '/session/:id';
  static const review = '/review/:id';
  static const clips = '/clips/:id';
  static const export = '/export/:id';

  /// The path to open a specific folder, e.g. /folder/7
  static String folderPath(int id) => '/folder/$id';

  /// The path to open a specific session, e.g. /session/7
  static String sessionPath(int id) => '/session/$id';

  /// The path to review a finished session, e.g. /review/7
  static String reviewPath(int id) => '/review/$id';

  /// The path to edit clips for a session, e.g. /clips/7
  static String clipsPath(int id) => '/clips/$id';

  /// The path to export clips for a session, e.g. /export/7
  static String exportPath(int id) => '/export/$id';

  /// Returns the review path for ended sessions, session path otherwise.
  static String openPath({required int id, required bool ended}) =>
      ended ? reviewPath(id) : sessionPath(id);
}