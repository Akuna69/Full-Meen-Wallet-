#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  NDK_DIR="$(find "$ANDROID_HOME/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1 || true)"
  if [ -n "$NDK_DIR" ]; then
    export ANDROID_NDK_HOME="$NDK_DIR"
  fi
fi

echo "Android SDK: $ANDROID_HOME"
echo "Android NDK: ${ANDROID_NDK_HOME:-no encontrado}"

command -v java >/dev/null || {
  echo "ERROR: no se encontró Java."
  exit 1
}

command -v go >/dev/null || {
  echo "ERROR: no se encontró Go."
  exit 1
}

command -v docker >/dev/null || {
  echo "ERROR: no se encontró Docker."
  exit 1
}

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker no está ejecutándose."
  exit 1
fi

if [ ! -d "$ANDROID_HOME" ]; then
  echo "ERROR: Android SDK no encontrado en: $ANDROID_HOME"
  exit 1
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -d "$ANDROID_NDK_HOME" ]; then
  echo "ERROR: Android NDK no encontrado."
  echo "Configura ANDROID_NDK_HOME, por ejemplo:"
  echo "export ANDROID_NDK_HOME=\$ANDROID_HOME/ndk/27.2.12479018"
  exit 1
fi

JAVA_MAJOR="$(
  java -version 2>&1 |
    sed -n 's/.*version "\([0-9]*\).*/\1/p' |
    head -n 1
)"

if [ "$JAVA_MAJOR" != "17" ]; then
  echo "ERROR: este proyecto necesita JDK 17."
  java -version 2>&1 | head -n 1
  exit 1
fi

if [ ! -f "$ROOT_DIR/local.properties" ]; then
  printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$ROOT_DIR/local.properties"
  echo "Creado local.properties"
fi

mkdir -p "$ROOT_DIR/android/apolloui"

if [ ! -f "$ROOT_DIR/android/apolloui/google-services.json" ]; then
  cat > "$ROOT_DIR/android/apolloui/google-services.json" <<'JSON'
{
  "project_info": {
    "project_number": "123456789012",
    "project_id": "build-only-project",
    "storage_bucket": "build-only-project.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789012:android:0000000000000001",
        "android_client_info": {
          "package_name": "io.muun.apollo"
        }
      },
      "api_key": [
        {
          "current_key": "AIzaSyDummyKeyForBuildOnly0000000000"
        }
      ]
    },
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789012:android:0000000000000002",
        "android_client_info": {
          "package_name": "io.muun.apollo.debug"
        }
      },
      "api_key": [
        {
          "current_key": "AIzaSyDummyKeyForBuildOnly0000000000"
        }
      ]
    }
  ],
  "configuration_version": "1"
}
JSON
  echo "Creado google-services.json temporal"
fi

chmod +x "$ROOT_DIR/gradlew"
chmod +x "$ROOT_DIR/libwallet/librs/makelibs.sh"
chmod +x "$ROOT_DIR/tools/bootstrap-gomobile.sh"
chmod +x "$ROOT_DIR/tools/libwallet-android.sh"

echo "Instalando gomobile..."
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest

export PATH="$(go env GOPATH)/bin:$PATH"
gomobile init

echo "Compilando librerías Rust para Android..."
export TARGETS="aarch64-linux-android x86_64-linux-android"
bash "$ROOT_DIR/libwallet/librs/makelibs.sh"

echo "Compilando APK debug..."
./gradlew \
  clean \
  :android:apolloui:assembleProdDebug \
  --no-daemon \
  --stacktrace \
  --warning-mode all

echo

echo "=========================================="
echo "COMPILACIÓN COMPLETADA"
echo "=========================================="
echo "APK generado en:"
find "$ROOT_DIR/android/apolloui/build/outputs/apk" \
  -type f \
  -name "*.apk" \
  -print
