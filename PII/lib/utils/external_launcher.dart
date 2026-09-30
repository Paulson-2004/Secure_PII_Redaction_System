import 'external_launcher_stub.dart'
    if (dart.library.html) 'external_launcher_web.dart';

void launchExternalUrl(String url) {
  openExternalUrl(url);
}
