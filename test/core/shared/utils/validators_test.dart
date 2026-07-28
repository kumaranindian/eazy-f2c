import 'package:flutter_test/flutter_test.dart';
import 'package:f2c/core/shared/utils/validators.dart';

void main() {
  group('Validators', () {
    group('validateUsername', () {
      test('should return null for valid username', () {
        expect(Validators.validateUsername('admin'), null);
        expect(Validators.validateUsername('user123'), null);
        expect(Validators.validateUsername('test_user'), null);
      });

      test('should return error for empty username', () {
        expect(Validators.validateUsername(''), isNotNull);
        expect(Validators.validateUsername(null), isNotNull);
      });

      test('should return error for username with spaces', () {
        expect(Validators.validateUsername('user name'), isNotNull);
      });

      test('should return error for too short username', () {
        expect(Validators.validateUsername('user'), isNotNull);
      });

      test('should return error for too long username', () {
        expect(
          Validators.validateUsername('a' * 31),
          isNotNull,
        );
      });
    });

    group('validatePassword', () {
      test('should return null for valid password', () {
        expect(Validators.validatePassword('Admin@123'), null);
        expect(Validators.validatePassword('Test@Pass1'), null);
      });

      test('should return error for empty password', () {
        expect(Validators.validatePassword(''), isNotNull);
        expect(Validators.validatePassword(null), isNotNull);
      });

      test('should return error for password without uppercase', () {
        expect(Validators.validatePassword('admin@123'), isNotNull);
      });

      test('should return error for password without lowercase', () {
        expect(Validators.validatePassword('ADMIN@123'), isNotNull);
      });

      test('should return error for password without number', () {
        expect(Validators.validatePassword('Admin@Test'), isNotNull);
      });

      test('should return error for password without special char', () {
        expect(Validators.validatePassword('Admin123'), isNotNull);
      });

      test('should return error for too short password', () {
        expect(Validators.validatePassword('Ad@1'), isNotNull);
      });
    });

    group('validateEmail', () {
      test('should return null for valid email', () {
        expect(Validators.validateEmail('test@example.com'), null);
        expect(Validators.validateEmail('user.name@domain.co.uk'), null);
      });

      test('should return error for empty email', () {
        expect(Validators.validateEmail(''), isNotNull);
        expect(Validators.validateEmail(null), isNotNull);
      });

      test('should return error for invalid email', () {
        expect(Validators.validateEmail('invalid'), isNotNull);
        expect(Validators.validateEmail('test@'), isNotNull);
        expect(Validators.validateEmail('@example.com'), isNotNull);
      });
    });

    group('validateMobile', () {
      test('should return null for valid mobile', () {
        expect(Validators.validateMobile('1234567890'), null);
        expect(Validators.validateMobile('9876543210'), null);
      });

      test('should return error for empty mobile', () {
        expect(Validators.validateMobile(''), isNotNull);
        expect(Validators.validateMobile(null), isNotNull);
      });

      test('should return error for invalid mobile', () {
        expect(Validators.validateMobile('123'), isNotNull);
        expect(Validators.validateMobile('12345678901'), isNotNull);
        expect(Validators.validateMobile('abcdefghij'), isNotNull);
      });
    });

    group('validateConfirmPassword', () {
      test('should return null when passwords match', () {
        expect(
          Validators.validateConfirmPassword('password', 'password'),
          null,
        );
      });

      test('should return error when passwords do not match', () {
        expect(
          Validators.validateConfirmPassword('password1', 'password2'),
          isNotNull,
        );
      });

      test('should return error for empty confirm password', () {
        expect(
          Validators.validateConfirmPassword('password', ''),
          isNotNull,
        );
      });
    });
  });
}
