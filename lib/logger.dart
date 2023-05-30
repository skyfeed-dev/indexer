import 'package:logger/logger.dart';

final logger = Logger(
  printer: SimplePrinter(),
  // printer: LogfmtPrinter(),
  // printer: PrettyPrinter(),

  // output: ConsoleOutput(),
  filter: MyFilter(),
);

class MyFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}
