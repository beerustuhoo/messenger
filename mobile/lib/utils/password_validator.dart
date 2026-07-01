class PasswordValidation {
  final List<String> errors;
  PasswordValidation(this.errors);
  bool get isValid => errors.isEmpty;
}

PasswordValidation validatePassword(String password) {
  final errors = <String>[];
  if (password.length < 8) errors.add('At least 8 characters');
  if (!RegExp(r'[a-z]').hasMatch(password)) errors.add('At least 1 lowercase letter');
  if (!RegExp(r'[A-Z]').hasMatch(password)) errors.add('At least 1 uppercase letter');
  if (!RegExp(r'\d').hasMatch(password)) errors.add('At least 1 digit');
  if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>/?`~]').hasMatch(password)) {
    errors.add('At least 1 special character');
  }
  return PasswordValidation(errors);
}
