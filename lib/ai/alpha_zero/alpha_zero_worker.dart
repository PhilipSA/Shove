// A dedicated web worker in the browser; an isolate per search elsewhere.
export 'alpha_zero_worker_io.dart'
    if (dart.library.js_interop) 'alpha_zero_worker_web.dart';
