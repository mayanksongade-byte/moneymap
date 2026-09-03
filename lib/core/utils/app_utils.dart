import 'package:intl/intl.dart';

class AppDateFormats {
  static final DateFormat relativeDate = DateFormat('MMM dd');
  static final DateFormat timeOnly = DateFormat('h:mm a');
  static final DateFormat dayOfWeek = DateFormat('EEEE');
  static final DateFormat dateKey = DateFormat('yyyy-MM-dd');
  static final DateFormat fullDate = DateFormat('dd MMM yyyy');
}
