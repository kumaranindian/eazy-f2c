# Contributing to F2C

Thank you for your interest in contributing to F2C! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what is best for the project
- Show empathy towards other contributors

## Development Setup

### Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Git
- Android Studio / VS Code
- Firebase CLI

### Getting Started

1. **Fork the repository**

```bash
git clone https://github.com/your-username/f2c.git
cd f2c
```

2. **Install dependencies**

```bash
flutter pub get
cd scripts && flutter pub get && cd ..
```

3. **Generate code**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. **Run the app**

```bash
flutter run --flavor dev -t lib/main_dev.dart
```

## Coding Standards

### Dart Style Guide

Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).

### Key Principles

1. **Use meaningful names**
   ```dart
   // Good
   final userName = 'John Doe';
   
   // Bad
   final un = 'John Doe';
   ```

2. **Keep functions small**
   ```dart
   // Good - Single responsibility
   Future<void> validateAndSaveUser() async {
     if (isValid()) {
       await saveUser();
     }
   }
   ```

3. **Use const constructors**
   ```dart
   // Good
   const Text('Hello');
   
   // Bad
   Text('Hello');
   ```

4. **Prefer final over var**
   ```dart
   // Good
   final name = 'John';
   
   // Bad
   var name = 'John';
   ```

### File Organization

```dart
// 1. Imports (grouped)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/features/authentication/models/user_model.dart';

// 2. Part statements
part 'user_model.freezed.dart';
part 'user_model.g.dart';

// 3. Class definition
class MyWidget extends StatelessWidget {
  // 4. Constructor
  const MyWidget({super.key});
  
  // 5. Fields
  final String title;
  
  // 6. Methods
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

## Git Workflow

### Branch Naming

- `feature/feature-name` - New features
- `bugfix/bug-description` - Bug fixes
- `hotfix/critical-fix` - Critical production fixes
- `refactor/what-changed` - Code refactoring
- `docs/what-changed` - Documentation updates

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

**Examples:**

```bash
feat(auth): add username-based login

Implemented username-based authentication instead of email-based.
Users can now login with their username and password.

Closes #123
```

```bash
fix(users): resolve user creation validation error

Fixed validation error when creating users with special characters
in their names.

Fixes #456
```

### Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make your changes**
   - Write clean code
   - Add tests
   - Update documentation

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat(scope): description"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/my-feature
   ```

5. **Create Pull Request**
   - Provide clear description
   - Reference related issues
   - Add screenshots if UI changes

6. **Code Review**
   - Address review comments
   - Keep PR updated with main branch

7. **Merge**
   - Squash commits if needed
   - Delete branch after merge

## Testing

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/features/authentication/models/user_model_test.dart

# With coverage
flutter test --coverage
```

### Writing Tests

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('should create valid user model', () {
      // Arrange
      final user = UserModel(...);
      
      // Act
      final result = user.canLogin;
      
      // Assert
      expect(result, true);
    });
  });
}
```

### Test Coverage

- Aim for 80%+ code coverage
- Test critical business logic
- Test edge cases
- Test error scenarios

## Code Review Guidelines

### As a Reviewer

- ✅ Be constructive and respectful
- ✅ Explain the "why" behind suggestions
- ✅ Approve when ready
- ✅ Test the changes locally if needed

### As an Author

- ✅ Respond to all comments
- ✅ Ask for clarification if needed
- ✅ Make requested changes promptly
- ✅ Thank reviewers for their time

## Documentation

### Code Documentation

```dart
/// Authenticates a user with username and password.
///
/// Returns [UserModel] on successful authentication.
/// Throws [AuthenticationException] if credentials are invalid.
/// Throws [UserInactiveException] if user account is inactive.
///
/// Example:
/// ```dart
/// final user = await authRepo.login(request);
/// ```
Future<UserModel> login(LoginRequest request);
```

### README Updates

Update README.md when:
- Adding new features
- Changing setup process
- Modifying architecture
- Adding dependencies

## Issue Reporting

### Bug Reports

Include:
- Clear description
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots/videos
- Environment details
- Error logs

### Feature Requests

Include:
- Clear description
- Use case
- Proposed solution
- Alternative solutions
- Additional context

## Release Process

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR:** Breaking changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes

### Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped
- [ ] Tag created
- [ ] Release notes written

## Questions?

- Check existing documentation
- Search closed issues
- Ask in discussions
- Contact maintainers

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

Thank you for contributing to F2C! 🎉
