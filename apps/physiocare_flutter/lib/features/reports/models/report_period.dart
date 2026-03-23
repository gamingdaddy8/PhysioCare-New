enum ReportPeriod { session, day, week, all }

extension ReportPeriodLabel on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.session:
        return 'Last Session';
      case ReportPeriod.day:
        return 'Today';
      case ReportPeriod.week:
        return 'This Week';
      case ReportPeriod.all:
        return 'Full Program';
    }
  }

  String get dbValue {
    switch (this) {
      case ReportPeriod.session:
        return 'session';
      case ReportPeriod.day:
        return 'day';
      case ReportPeriod.week:
        return 'week';
      case ReportPeriod.all:
        return 'all';
    }
  }
}
