# Test Y App

Base Flutter project theo kiến trúc [ktx-app](../ktx-app).

## Cấu trúc thư mục

```
lib/
├── app/                 # App root, theme, router
├── core/                # Constants, network, firebase, storage, theme tokens
├── data/                # API services, models, repository implementations
├── domain/              # Repository interfaces, use cases
├── features/            # Feature modules (auth, splash, home, ...)
├── shared/              # Shared widgets & services
└── assets/              # svg, json, image
```

## Thư viện chính

- **State management**: `flutter_bloc`
- **Routing**: `go_router`
- **HTTP**: `dio` + `AuthInterceptor` (Bearer token + refresh)
- **Env**: `flutter_dotenv`
- **Storage**: `flutter_secure_storage`, `shared_preferences`
- **Firebase**: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`
- **UI/UX**: `bot_toast`, `shimmer`, `flutter_svg`, `lottie`, ...

## Bắt đầu

```bash
cp .env.example .env
flutter pub get
flutter run
```

## Cấu hình Firebase

1. Tạo project trên [Firebase Console](https://console.firebase.google.com/)
2. Thêm app Android/iOS
3. Tải và đặt file cấu hình (không commit — đã có trong `.gitignore`):
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `macos/Runner/GoogleService-Info.plist` (có thể copy từ `GoogleService-Info.plist.example`)
4. (Tuỳ chọn) Chạy FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

## Cấu hình API

Chỉnh `.env`:

```env
APP_ENV=dev
API_DEV_URL=https://your-api.example.com
API_PROD_URL=https://your-api.example.com
MAPS_API_KEY=your_google_maps_api_key
GOOGLE_IOS_CLIENT_ID=....apps.googleusercontent.com
GOOGLE_SERVER_CLIENT_ID=....apps.googleusercontent.com
GOOGLE_IOS_URL_SCHEME=com.googleusercontent.apps....
```

Google Maps / Sign-In:
- Dart đọc qua `flutter_dotenv` + `EnvConfig`
- Android đọc `MAPS_API_KEY` từ `.env` trong `android/app/build.gradle.kts`
- iOS/macOS đọc từ `ios/Flutter/Secrets.xcconfig` — sau khi sửa `.env` chạy:

```bash
./tool/sync_ios_secrets.sh
```

Endpoint demo hiện dùng JSONPlaceholder (`/posts`) để kiểm tra layer API.

## Thêm feature mới

1. Tạo interface trong `lib/domain/repositories/`
2. Tạo API service kế thừa `BaseApiService` trong `lib/data/datasources/api_services/`
3. Implement repository trong `lib/data/repositories/`
4. Tạo use case trong `lib/domain/usecases/`
5. Tạo BLoC + UI trong `lib/features/<feature>/`
6. Đăng ký repository/bloc trong `lib/app/app.dart` và route trong `lib/app/router/app_router.dart`
