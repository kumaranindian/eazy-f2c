import 'package:email_validator/email_validator.dart';
import 'package:f2c/core/constants/app_constants.dart';

class Validators {
  Validators._();

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationMessages.usernameRequired;
    }

    final trimmed = value.trim();

    if (trimmed.length < AppConstants.usernameMinLength ||
        trimmed.length > AppConstants.usernameMaxLength) {
      return ValidationMessages.usernameInvalid;
    }

    if (trimmed.contains(' ')) {
      return ValidationMessages.usernameInvalid;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(trimmed)) {
      return ValidationMessages.usernameInvalid;
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationMessages.passwordRequired;
    }

    if (value.length < AppConstants.passwordMinLength) {
      return ValidationMessages.passwordWeak;
    }

    final hasUppercase = value.contains(RegExp(r'[A-Z]'));
    final hasLowercase = value.contains(RegExp(r'[a-z]'));
    final hasDigit = value.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (!hasUppercase || !hasLowercase || !hasDigit || !hasSpecialChar) {
      return ValidationMessages.passwordWeak;
    }

    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationMessages.emailRequired;
    }

    if (!EmailValidator.validate(value.trim())) {
      return ValidationMessages.emailInvalid;
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationMessages.nameRequired;
    }

    final trimmed = value.trim();

    if (trimmed.length < AppConstants.nameMinLength ||
        trimmed.length > AppConstants.nameMaxLength) {
      return 'Name must be ${AppConstants.nameMinLength}-${AppConstants.nameMaxLength} characters';
    }

    return null;
  }

  static String? validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationMessages.mobileRequired;
    }

    final mobileRegex = RegExp(r'^[0-9]{10}$');
    if (!mobileRegex.hasMatch(value.trim())) {
      return ValidationMessages.mobileInvalid;
    }

    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Confirm password is required';
    }

    if (password != confirmPassword) {
      return ValidationMessages.passwordMismatch;
    }

    return null;
  }
}
