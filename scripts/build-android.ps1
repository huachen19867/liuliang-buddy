param([switch]$UseMirrors)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskJava = Join-Path $taskRoot '.tools/jdk/jdk-17.0.16+8'
$taskSdk = Join-Path $taskRoot '.tools/android-sdk'
$taskGradle = Join-Path $taskRoot '.tools/gradle/gradle-9.1.0/bin/gradle.bat'
if (-not (Test-Path -LiteralPath $taskGradle)) {
    throw 'Local build tools are absent. Use flutter build apk --debug in app/ with an installed Android SDK.'
}
$env:JAVA_HOME = $taskJava
$env:ANDROID_HOME = $taskSdk
$env:GRADLE_USER_HOME = Join-Path $taskRoot '.tools/gradle-home'
$env:PUB_CACHE = Join-Path $taskRoot '.tools/pub-cache'
$taskVersionText = Get-Content -LiteralPath (Join-Path $taskRoot 'app/pubspec.yaml') -Raw
$taskVersion = [regex]::Match($taskVersionText, '(?m)^version:\s*([0-9.]+)\+(\d+)\s*$')
if (-not $taskVersion.Success) { throw 'Expected versionName+versionCode in pubspec.yaml' }
$taskPropertiesPath = Join-Path $taskRoot 'app/android/local.properties'
$taskProperties = Get-Content -LiteralPath $taskPropertiesPath -Raw
$taskProperties = [regex]::Replace($taskProperties, '(?m)^flutter\.versionName=.*$', "flutter.versionName=$($taskVersion.Groups[1].Value)")
$taskProperties = [regex]::Replace($taskProperties, '(?m)^flutter\.versionCode=.*$', "flutter.versionCode=$($taskVersion.Groups[2].Value)")
Set-Content -LiteralPath $taskPropertiesPath -Value $taskProperties -Encoding utf8
$taskArgs = @('-p', (Join-Path $taskRoot 'app/android'), 'assembleDebug', '-Ptarget-platform=android-arm64', '--console=plain')
if ($UseMirrors) { $taskArgs += @('-I', (Join-Path $PSScriptRoot 'gradle-mirrors.init.gradle')) }
& $taskGradle @taskArgs
if ($LASTEXITCODE -ne 0) { throw "Android build failed with exit code $LASTEXITCODE" }
$taskApk = Join-Path $taskRoot 'app/build/app/outputs/flutter-apk/app-debug.apk'
if (-not (Test-Path -LiteralPath $taskApk)) { $taskApk = Join-Path $taskRoot 'app/build/app/outputs/apk/debug/app-debug.apk' }
Copy-Item -LiteralPath $taskApk -Destination (Join-Path $taskRoot 'artifacts/liuliang-buddy-debug.apk')
Get-FileHash -LiteralPath (Join-Path $taskRoot 'artifacts/liuliang-buddy-debug.apk') -Algorithm SHA256
