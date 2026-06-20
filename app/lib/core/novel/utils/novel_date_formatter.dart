import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

String formatNovelDate(DateTime? date, BuildContext context) {
  if (date == null) {
    return AppLocalizations.of(context)?.novelDateUnknown ?? '不明';
  }

  final String locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(date.toLocal());
}
