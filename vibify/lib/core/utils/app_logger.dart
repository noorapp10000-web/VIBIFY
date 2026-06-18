import 'package:logger/logger.dart';

final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 100,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
  level: Level.debug,
);

extension LoggerExtension on Object {
  void logD(String msg) => appLogger.d('[$runtimeType] $msg');
  void logI(String msg) => appLogger.i('[$runtimeType] $msg');
  void logW(String msg) => appLogger.w('[$runtimeType] $msg');
  void logE(String msg, [dynamic error, StackTrace? stack]) =>
      appLogger.e('[$runtimeType] $msg', error: error, stackTrace: stack);
}
