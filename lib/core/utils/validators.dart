class Validators {
  Validators._();
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final r = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!r.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Password must contain an uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Password must contain a number';
    return null;
  }
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final n = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^(\+?255|0)[67]\d{8}$').hasMatch(n)) return 'Enter a valid Tanzanian phone number';
    return null;
  }
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required';
    if (value.trim().length < 3) return 'Full name must be at least 3 characters';
    if (!value.trim().contains(' ')) return 'Please enter your first and last name';
    return null;
  }
  static String? validateMinLength(String? value, int min, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    if (value.trim().length < min) return '$fieldName must be at least $min characters';
    return null;
  }
  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Price is required';
    final p = double.tryParse(value.trim());
    if (p == null) return 'Enter a valid price';
    if (p <= 0) return 'Price must be greater than 0';
    return null;
  }
  static String? validateReferenceNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Reference number is required';
    if (value.trim().length < 5) return 'Enter a valid reference number';
    return null;
  }
}