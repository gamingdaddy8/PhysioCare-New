/// Generates spoken milestone messages based on rep progress.
class FeedbackEngine {
  FeedbackEngine._();

  /// Returns a milestone announcement if [current] hits a notable point,
  /// or null if this rep needs no extra announcement.
  static String? repMilestoneMessage(int current, int total) {
    if (total <= 0) return null;
    if (current == total) return 'Session complete! Great work!';
    final halfway = (total / 2).ceil();
    if (current == halfway) return 'Halfway there, keep pushing!';
    if (current == total - 1) return 'Last rep, give it your all!';
    return null;
  }

  /// Plain rep announcement: "Rep 3".
  static String repAnnouncement(int current) => 'Rep $current';
}
