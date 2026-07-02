class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String url;
  final String anonKey;

  String get normalizedUrl {
    final uri = _validatedUri();
    final port = uri.hasPort ? ':${uri.port}' : '';

    return '${uri.scheme}://${uri.host}$port';
  }

  String get normalizedAnonKey {
    validate();

    return anonKey.trim();
  }

  void validate() {
    _validatedUri();
    _validatedAnonKey();
  }

  Uri _validatedUri() {
    final trimmedUrl = url.trim();

    if (trimmedUrl.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL. Pass it with --dart-define=SUPABASE_URL=...',
      );
    }

    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL must be a valid https:// URL.');
    }

    if (uri.scheme != 'https') {
      throw StateError('SUPABASE_URL must start with https://.');
    }

    final hasPath = uri.path.isNotEmpty && uri.path != '/';
    if (hasPath) {
      throw StateError(
        'Use the Supabase project URL without /rest/v1. Example: https://project-ref.supabase.co',
      );
    }

    return uri;
  }

  void _validatedAnonKey() {
    final trimmedKey = anonKey.trim();

    if (trimmedKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_ANON_KEY. Pass it with --dart-define=SUPABASE_ANON_KEY=...',
      );
    }

    if (trimmedKey.startsWith('sb_secret_')) {
      throw StateError(
        'Do not use a Supabase secret key in Flutter. Use the publishable key instead.',
      );
    }
  }
}
