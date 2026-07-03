import 'dart:js_interop';

@JS('window.isPwaInstalled')
external JSBoolean _isPwaInstalled();

@JS('window.hasDeferredPrompt')
external JSBoolean _hasDeferredPrompt();

@JS('window.promptInstall')
external JSPromise<JSBoolean> _promptInstall();

bool get isPwaInstalled => _isPwaInstalled().toDart;
bool get hasDeferredPrompt => _hasDeferredPrompt().toDart;

Future<bool> promptInstall() async {
  final promise = _promptInstall();
  final result = await promise.toDart;
  return result.toDart;
}
