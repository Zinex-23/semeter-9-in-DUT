# Runs the Flutter app with DeepSeek AI dart-defines
param(
    [string]$Device
)

$ArgsList = @('--dart-define-from-file=dart-defines.local.json')
if ($Device) { $ArgsList += @('-d', $Device) }

flutter run @ArgsList
