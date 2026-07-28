# F2C - Farm2Community

Enterprise-grade **Flutter Web Application** with Firebase backend for connecting farmers directly to consumers.

## Features

- ✅ **Web-Only Application** - Optimized for web browsers
- ✅ Multi-environment support (Dev/Test/UAT/Prod)
- ✅ Role-based access control (Admin/Customer/Packaging/Delivery)
- ✅ Firebase Authentication with username/password
- ✅ Clean Architecture with Repository Pattern
- ✅ Comprehensive audit logging
- ✅ Session management with auto-login
- ✅ Production-grade security
- ✅ Clean URLs (no # in routes)
- ✅ Responsive web design

## Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Firebase CLI
- VS Code or any code editor
- Modern web browser (Chrome, Firefox, Safari, Edge)

## Setup

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Generate Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Configure Firebase

Set up four Firebase projects:
- f2c-dev
- f2c-test
- f2c-uat
- f2c-prod

Download configuration files and place them appropriately.

### 4. Create First Admin User

```bash
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c.com \
  --password Admin@123 \
  --name "System Administrator" \
  --environment dev
```

## Running the Application

### Development
```bash
flutter run -d chrome -t lib/main_dev.dart
```

### Testing
```bash
flutter run -d chrome -t lib/main_test.dart
```

### UAT
```bash
flutter run -d chrome -t lib/main_uat.dart
```

### Production
```bash
flutter run -d chrome -t lib/main_prod.dart
```

## Building for Web

### Development Build
```bash
flutter build web -t lib/main_dev.dart
```

### Production Build
```bash
flutter build web -t lib/main_prod.dart --release
```

The build output will be in `build/web/` directory.

## Testing

```bash
flutter test
```

## Architecture

```
lib/
├── core/                    # Core utilities and configurations
│   ├── config/             # App configuration
│   ├── constants/          # Constants
│   ├── exceptions/         # Custom exceptions
│   ├── routes/             # Routing configuration
│   └── shared/             # Shared utilities
├── features/               # Feature modules
│   ├── authentication/     # Auth module
│   └── users/              # User management
└── main_*.dart            # Environment entry points
```

## License

Proprietary - All rights reserved
