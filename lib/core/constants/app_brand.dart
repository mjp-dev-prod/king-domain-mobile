/// The product's name, in one place. "King Domain" is a working name and is
/// expected to change (Victor, 2026-10-02), so user-facing copy reads it from
/// here instead of repeating it.
class AppBrand {
  AppBrand._();

  static const String name = 'King Domain';
  static const String mark = 'KD';

  /// Public pages on the website (king-domain-web, public/privacy and public/delete-account). They
  /// move with the website's address, so they live here and not in the screens.
  static const String privacyUrl = 'https://king-domain.vercel.app/privacy/';
  static const String deleteAccountUrl = 'https://king-domain.vercel.app/delete-account/';
}
