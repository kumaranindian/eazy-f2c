# F2C Architecture Documentation

## Overview

F2C (Farm2Community) is built using **Clean Architecture** principles with **Flutter** and **Firebase** backend. The application follows industry best practices for scalability, maintainability, and security.

## Architecture Layers

### 1. Presentation Layer

**Location:** `lib/features/*/presentation/`

**Responsibilities:**
- UI components (Pages, Widgets)
- State management (Riverpod)
- User interaction handling
- Navigation

**Key Components:**
- **Pages:** Full-screen views
- **Widgets:** Reusable UI components
- **Providers:** State management with Riverpod

### 2. Domain Layer

**Location:** `lib/features/*/models/`

**Responsibilities:**
- Business entities
- Business logic
- Data models with Freezed
- Enums and constants

**Key Components:**
- **Models:** Immutable data classes using Freezed
- **Enums:** Type-safe enumerations (UserRole, AuditAction)

### 3. Data Layer

**Location:** `lib/features/*/datasources/` and `lib/features/*/repositories/`

**Responsibilities:**
- Data fetching and persistence
- API communication
- Local storage
- Repository pattern implementation

**Key Components:**
- **Remote DataSources:** Firebase interactions
- **Local DataSources:** SharedPreferences, local storage
- **Repositories:** Abstract data access, combine multiple data sources

### 4. Core Layer

**Location:** `lib/core/`

**Responsibilities:**
- Shared utilities
- Configuration
- Constants
- Exception handling
- Logging

**Key Components:**
- **Config:** App configuration, environment setup
- **Constants:** App-wide constants
- **Exceptions:** Custom exception classes
- **Utils:** Validators, date utilities, formatters
- **Theme:** App theming

## Design Patterns

### Repository Pattern

Abstracts data sources from business logic:

```dart
abstract class AuthRepository {
  Future<UserModel> login(LoginRequest request);
  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SessionLocalDataSource _localDataSource;
  
  // Implementation
}
```

### Dependency Injection

Using Riverpod for DI:

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(sessionLocalDataSourceProvider),
  );
});
```

### State Management

Riverpod StateNotifier for complex state:

```dart
final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(
    authRepository: ref.watch(authRepositoryProvider),
  );
});
```

## Project Structure

```
lib/
├── core/
│   ├── config/
│   │   ├── app_config.dart
│   │   ├── app_environment.dart
│   │   └── firebase/
│   │       ├── firebase_options_dev.dart
│   │       ├── firebase_options_test.dart
│   │       ├── firebase_options_uat.dart
│   │       └── firebase_options_prod.dart
│   ├── constants/
│   │   └── app_constants.dart
│   ├── exceptions/
│   │   └── app_exception.dart
│   ├── routes/
│   │   └── app_router.dart
│   ├── shared/
│   │   ├── logger/
│   │   │   └── app_logger.dart
│   │   └── utils/
│   │       ├── validators.dart
│   │       └── date_time_utils.dart
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── authentication/
│   │   ├── datasources/
│   │   │   ├── auth_remote_datasource.dart
│   │   │   ├── session_local_datasource.dart
│   │   │   └── audit_log_datasource.dart
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── user_role.dart
│   │   │   ├── session_model.dart
│   │   │   ├── audit_log_model.dart
│   │   │   └── login_request.dart
│   │   ├── providers/
│   │   │   ├── auth_providers.dart
│   │   │   └── login_provider.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   └── user_repository.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── splash_page.dart
│   │       │   ├── login_page.dart
│   │       │   └── change_password_page.dart
│   │       └── widgets/
│   │           └── environment_badge.dart
│   ├── admin/
│   │   └── presentation/
│   │       └── pages/
│   │           ├── admin_dashboard_page.dart
│   │           └── users/
│   │               ├── users_list_page.dart
│   │               ├── user_create_page.dart
│   │               └── user_edit_page.dart
│   ├── customer/
│   ├── packaging/
│   └── delivery/
├── app.dart
├── main_dev.dart
├── main_test.dart
├── main_uat.dart
└── main_prod.dart
```

## Data Flow

### Authentication Flow

```
User Input (Login Page)
    ↓
LoginProvider (State Management)
    ↓
AuthRepository
    ↓
AuthRemoteDataSource (Firebase Auth)
    ↓
UserRemoteDataSource (Firestore)
    ↓
SessionLocalDataSource (SharedPreferences)
    ↓
AuditLogDataSource (Firestore Audit)
    ↓
Update UI State
    ↓
Navigate to Dashboard
```

### User Creation Flow

```
Admin Input (Create User Page)
    ↓
UserRepository
    ↓
UserRemoteDataSource
    ↓
Firebase Auth (Create User)
    ↓
Firestore (Create Document)
    ↓
AuditLogDataSource (Log Action)
    ↓
Return to Users List
```

## Security Architecture

### Authentication

- **Firebase Authentication** for user management
- **Username-based login** (not email-based for users)
- **Password policy enforcement**
- **First-time password change requirement**

### Authorization

- **Role-Based Access Control (RBAC)**
- **Firestore Security Rules** for data access
- **Route guards** for navigation protection
- **Function-level permissions**

### Session Management

- **Token-based authentication**
- **Automatic token refresh**
- **Session timeout handling**
- **Remember me functionality**

### Audit Logging

- **Comprehensive action logging**
- **User activity tracking**
- **Device and environment information**
- **Immutable audit trail**

## Multi-Environment Support

### Environments

1. **Development** (`dev`)
   - For active development
   - Debug logging enabled
   - Environment badge visible

2. **Testing** (`test`)
   - For QA testing
   - Test data
   - Environment badge visible

3. **UAT** (`uat`)
   - User acceptance testing
   - Production-like data
   - Environment badge visible

4. **Production** (`prod`)
   - Live environment
   - No debug logging
   - No environment badge

### Configuration

Each environment has:
- Separate Firebase project
- Separate configuration files
- Separate entry points (`main_*.dart`)
- Separate build flavors

## State Management Strategy

### Riverpod Providers

**Provider Types:**
- **Provider:** For immutable dependencies
- **StateNotifierProvider:** For mutable state
- **FutureProvider:** For async data
- **StreamProvider:** For real-time data

**Example:**

```dart
// Dependency
final authRepositoryProvider = Provider<AuthRepository>(...);

// State
final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>(...);

// Async Data
final currentUserProvider = FutureProvider<UserModel?>(...);
```

## Error Handling

### Exception Hierarchy

```dart
AppException
├── NetworkException
├── AuthenticationException
├── AuthorizationException
├── ValidationException
├── NotFoundException
├── ServerException
├── UnknownException
├── UserInactiveException
├── UserDeletedException
└── PasswordChangeRequiredException
```

### Error Propagation

1. DataSource throws specific exception
2. Repository catches and re-throws or transforms
3. Provider catches and updates state
4. UI displays user-friendly message

## Testing Strategy

### Unit Tests

- Model serialization/deserialization
- Validators
- Business logic
- Utilities

### Widget Tests

- UI components
- User interactions
- State changes

### Integration Tests

- End-to-end flows
- Firebase integration
- Navigation

## Performance Considerations

### Optimization Techniques

1. **Lazy Loading:** Load data on demand
2. **Caching:** Cache frequently accessed data
3. **Pagination:** Limit query results
4. **Indexing:** Firestore composite indexes
5. **Code Splitting:** Separate build flavors

### Firebase Optimization

- **Firestore Indexes:** For complex queries
- **Security Rules:** Efficient rule evaluation
- **Batch Operations:** Reduce write operations
- **Offline Persistence:** Enable offline support

## Scalability

### Horizontal Scalability

- **Stateless architecture**
- **Firebase auto-scaling**
- **CDN for static assets**

### Vertical Scalability

- **Efficient queries**
- **Proper indexing**
- **Resource optimization**

## Monitoring and Logging

### Application Logging

- **AppLogger:** Centralized logging
- **Log Levels:** Debug, Info, Warning, Error, Fatal
- **Contextual Logging:** Include relevant metadata

### Firebase Monitoring

- **Firebase Analytics**
- **Crashlytics** (recommended)
- **Performance Monitoring**

### Audit Trail

- **All user actions logged**
- **Immutable audit logs**
- **Compliance-ready**

## Future Enhancements

### Planned Features

1. **Offline Support:** Full offline functionality
2. **Push Notifications:** Real-time updates
3. **Analytics Dashboard:** Business intelligence
4. **Advanced Reporting:** Custom reports
5. **Multi-language Support:** Internationalization
6. **Dark Mode:** Theme switching
7. **Biometric Authentication:** Fingerprint/Face ID

### Architectural Improvements

1. **GraphQL Integration:** For complex queries
2. **Microservices:** Backend service separation
3. **Event Sourcing:** For audit and replay
4. **CQRS Pattern:** Separate read/write models

## Best Practices

### Code Quality

- ✅ Follow Dart/Flutter style guide
- ✅ Use linting rules
- ✅ Write meaningful comments
- ✅ Keep functions small and focused
- ✅ Use const constructors
- ✅ Prefer composition over inheritance

### Security

- ✅ Never hardcode credentials
- ✅ Use environment variables
- ✅ Validate all inputs
- ✅ Sanitize user data
- ✅ Follow principle of least privilege
- ✅ Regular security audits

### Performance

- ✅ Minimize rebuilds
- ✅ Use const widgets
- ✅ Optimize images
- ✅ Lazy load data
- ✅ Profile regularly

## Conclusion

The F2C architecture is designed for:
- **Scalability:** Handle growing user base
- **Maintainability:** Easy to update and extend
- **Security:** Enterprise-grade security
- **Testability:** Comprehensive test coverage
- **Performance:** Optimized for speed

This architecture provides a solid foundation for building a production-grade enterprise application.
