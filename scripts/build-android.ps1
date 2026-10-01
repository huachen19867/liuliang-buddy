param(
    [ValidateSet('Release', 'Debug')][string]$Mode = 'Release',
    [switch]$UseMirrors
)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskJava = Join-Path $taskRoot '.tools/jdk/jdk-17.0.16+8'
$taskSdk = Join-Path $taskRoot '.tools/android-sdk'
$taskGradle = Join-Path $taskRoot '.tools/gradle/gradle-9.1.0/bin/gradle.bat'
if (-not (Test-Path -LiteralPath $taskGradle)) {
    throw 'Local build tools are absent. Use flutter build apk --release in app/ with an installed Android SDK and your private signing environment.'
}
$env:JAVA_HOME = $taskJava
$env:ANDROID_HOME = $taskSdk
$env:GRADLE_USER_HOME = Join-Path $taskRoot '.tools/gradle-home'
$env:PUB_CACHE = Join-Path $taskRoot '.tools/pub-cache'
if ($Mode -eq 'Release' -and -not $env:LIULIANG_KEYSTORE_FILE) {
    $taskSecretFile = Join-Path $taskRoot '.tools/signing/release-credentials.xml'
    if (-not (Test-Path -LiteralPath $taskSecretFile)) { throw 'Private release signing credentials are absent; see docs/ANDROID_RELEASE.md.' }
    $taskCredential = Import-Clixml -LiteralPath $taskSecretFile
    $env:LIULIANG_KEYSTORE_FILE = Join-Path $taskRoot '.tools/signing/liuliang-release.p12'
    $env:LIULIANG_KEYSTORE_PASSWORD = $taskCredential.GetNetworkCredential().Password
    $env:LIULIANG_KEY_ALIAS = $taskCredential.UserName
    $env:LIULIANG_KEY_PASSWORD = $env:LIULIANG_KEYSTORE_PASSWORD
}
$taskVersionText = Get-Content -LiteralPath (Join-Path $taskRoot 'app/pubspec.yaml') -Raw
$taskVersion = [regex]::Match($taskVersionText, '(?m)^version:\s*([0-9.]+)\+(\d+)\s*$')
if (-not $taskVersion.Success) { throw 'Expected versionName+versionCode in pubspec.yaml' }
$taskPropertiesPath = Join-Path $taskRoot 'app/android/local.properties'
$taskProperties = Get-Content -LiteralPath $taskPropertiesPath -Raw
$taskFlutterSdkMatch = [regex]::Match($taskProperties, '(?m)^flutter\.sdk=(.+)$')
if (-not $taskFlutterSdkMatch.Success) { throw 'Missing flutter.sdk in app/android/local.properties.' }
$taskFlutterSdkPath = $taskFlutterSdkMatch.Groups[1].Value.Trim().Replace('\\', '\')
$taskFlutterCommand = Join-Path $taskFlutterSdkPath 'bin/flutter.bat'
if (-not (Test-Path -LiteralPath $taskFlutterCommand)) { throw 'Configured Flutter SDK is unavailable.' }
# Refresh plugin metadata with the same ASCII PUB_CACHE that Gradle will use.
# A pub get from another shell can otherwise leave JNI/CMake in a Unicode path.
Push-Location (Join-Path $taskRoot 'app')
try {
    & $taskFlutterCommand pub get
    if ($LASTEXITCODE -ne 0) { throw "Flutter dependency resolution failed with exit code $LASTEXITCODE" }
} finally { Pop-Location }
$taskProperties = [regex]::Replace($taskProperties, '(?m)^flutter\.versionName=.*$', "flutter.versionName=$($taskVersion.Groups[1].Value)")
$taskProperties = [regex]::Replace($taskProperties, '(?m)^flutter\.versionCode=.*$', "flutter.versionCode=$($taskVersion.Groups[2].Value)")
Set-Content -LiteralPath $taskPropertiesPath -Value $taskProperties -Encoding utf8
if ($Mode -eq 'Release') {
    # Flutter must generate release plugin registration without dev plugins.
    # Calling assembleRelease directly after pub get can retain integration_test.
    $taskWrapperPath = Join-Path $taskRoot 'app/android/gradle/wrapper/gradle-wrapper.properties'
    $taskWrapperOriginal = [System.IO.File]::ReadAllText($taskWrapperPath)
    $taskLocalDistribution = Join-Path $taskRoot '.tools/gradle.zip'
    $taskMirrorInit = Join-Path $env:GRADLE_USER_HOME 'init.d/liuliang-release-mirrors.gradle'
    $taskMirrorCreated = $false
    try {
        if (Test-Path -LiteralPath $taskLocalDistribution) {
            $taskLocalUri = [Uri]::new($taskLocalDistribution).AbsoluteUri
            $taskWrapperLocal = [regex]::Replace($taskWrapperOriginal, '(?m)^distributionUrl=.*$', "distributionUrl=$taskLocalUri")
            [System.IO.File]::WriteAllText($taskWrapperPath, $taskWrapperLocal)
        }
        if ($UseMirrors) {
            if (Test-Path -LiteralPath $taskMirrorInit) { throw 'Task mirror init file already exists; refusing to replace it.' }
            New-Item -ItemType Directory -Path (Split-Path $taskMirrorInit) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'gradle-mirrors.init.gradle') -Destination $taskMirrorInit
            $taskMirrorCreated = $true
        }
        Push-Location (Join-Path $taskRoot 'app')
        try {
            # --no-pub also skips release plugin registration in this SDK.
            & $taskFlutterCommand build apk --release --target-platform android-arm64
            if ($LASTEXITCODE -ne 0) { throw "Android release build failed with exit code $LASTEXITCODE" }
        } finally { Pop-Location }
    } finally {
        [System.IO.File]::WriteAllText($taskWrapperPath, $taskWrapperOriginal)
        if ($taskMirrorCreated) { Remove-Item -LiteralPath $taskMirrorInit }
    }
} else {
    $taskArgs = @('-p', (Join-Path $taskRoot 'app/android'), 'assembleDebug', '-Ptarget-platform=android-arm64', '--console=plain')
    if ($UseMirrors) { $taskArgs += @('-I', (Join-Path $PSScriptRoot 'gradle-mirrors.init.gradle')) }
    & $taskGradle @taskArgs
    if ($LASTEXITCODE -ne 0) { throw "Android debug build failed with exit code $LASTEXITCODE" }
}
$taskVariant = $Mode.ToLowerInvariant()
$taskApk = Join-Path $taskRoot "app/build/app/outputs/flutter-apk/app-$taskVariant.apk"
if (-not (Test-Path -LiteralPath $taskApk)) { $taskApk = Join-Path $taskRoot "app/build/app/outputs/apk/$taskVariant/app-$taskVariant.apk" }
$taskOutput = Join-Path $taskRoot "artifacts/liuliang-buddy-$taskVariant.apk"
Copy-Item -LiteralPath $taskApk -Destination $taskOutput
Get-FileHash -LiteralPath $taskOutput -Algorithm SHA256
