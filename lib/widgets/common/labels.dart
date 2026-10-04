import 'dart:async';

import '../../api/gw2_api.dart';
import '../../l10n/strings.dart';

/// crafting disciplines come from the api in english, translate the known ones
const _disciplines = {
  'Armorsmith',
  'Artificer',
  'Chef',
  'Huntsman',
  'Jeweler',
  'Leatherworker',
  'Scribe',
  'Tailor',
  'Weaponsmith',
  'Homesteader',
};

String disciplineLabel(S s, String discipline) =>
    _disciplines.contains(discipline) ? s.t('disc_${discipline.toLowerCase()}') : discipline;

/// a failure in plain words. the api's own text stays as a small detail
/// for anything that is not simply "no connection"
String friendlyError(S s, Object? error) {
  if (error is Gw2ApiException) {
    return switch (error.kind) {
      ApiErrorKind.offline => s.t('err_offline'),
      ApiErrorKind.timeout => s.t('err_timeout'),
      ApiErrorKind.unauthorized => s.t('err_unauthorized'),
      ApiErrorKind.notFound => s.t('err_not_found'),
      ApiErrorKind.rateLimited => s.t('err_rate_limited'),
      ApiErrorKind.server => s.t('err_server'),
      ApiErrorKind.noKey => s.t('err_no_key'),
      ApiErrorKind.other => s.t('err_generic'),
    };
  }
  if (error is TimeoutException) return s.t('err_timeout');
  return s.t('err_generic');
}
