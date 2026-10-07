// The browser's file picker on the web; unsupported elsewhere.
export 'model_file_picker_io.dart'
    if (dart.library.js_interop) 'model_file_picker_web.dart';

/// A file read from the user's disk; it is never sent anywhere.
typedef PickedModelFile = ({String name, String text});
