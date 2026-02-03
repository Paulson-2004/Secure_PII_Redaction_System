class AppConfig {
  static const String environment = String.fromEnvironment(
    "ENV",
    defaultValue: "dev",
  );

  static const String _baseUrlOverride = String.fromEnvironment(
    "BASE_URL",
    defaultValue: "",
  );

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }
    if (environment == "prod") {
      return "https://api.example.com";
    }
    return "http://10.0.2.2:8000";
  }

  static const String processPath = "/process/";
  static const String logsPath = "/logs";
  static const String logByIdPath = "/logs/";
  static const String authLoginPath = "/auth/login";
  static const String authRegisterPath = "/auth/register";
  static const String authResetPasswordPath = "/auth/reset-password";
  static const String authForgotPasswordPath = "/auth/forgot-password";
  static const String authResetPasswordTokenPath = "/auth/reset-password-token";
  static const String authChangePasswordPath = "/auth/change-password";

  static Uri processUri({bool returnPdf = false, String? token, String? userToken}) {
    final uri = Uri.parse("$baseUrl$processPath");
    final params = <String, String>{};
    if (returnPdf) {
      params["return_pdf"] = "true";
    }
    if (token != null && token.isNotEmpty) {
      params["token"] = token;
    }
    if (userToken != null && userToken.isNotEmpty) {
      params["user_token"] = userToken;
    }
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  static Uri processUriWithBase(
    String base, {
    bool returnPdf = false,
    String? token,
    String? userToken,
  }) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    final uri = Uri.parse("$normalized$processPath");
    final params = <String, String>{};
    if (returnPdf) {
      params["return_pdf"] = "true";
    }
    if (token != null && token.isNotEmpty) {
      params["token"] = token;
    }
    if (userToken != null && userToken.isNotEmpty) {
      params["user_token"] = userToken;
    }
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  static Uri logsUriWithBase(
    String base, {
    String? token,
    String? userToken,
    int limit = 50,
    int offset = 0,
    String? piiType,
    String? filename,
    String? dateFrom,
    String? dateTo,
    String? sortBy,
    String? sortDir,
  }) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    final uri = Uri.parse("$normalized$logsPath");
    final params = <String, String>{
      "limit": limit.toString(),
      "offset": offset.toString(),
    };
    if (token != null && token.isNotEmpty) {
      params["token"] = token;
    }
    if (userToken != null && userToken.isNotEmpty) {
      params["user_token"] = userToken;
    }
    if (piiType != null && piiType.isNotEmpty) {
      params["pii_type"] = piiType;
    }
    if (filename != null && filename.isNotEmpty) {
      params["filename"] = filename;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      params["date_from"] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      params["date_to"] = dateTo;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      params["sort_by"] = sortBy;
    }
    if (sortDir != null && sortDir.isNotEmpty) {
      params["sort_dir"] = sortDir;
    }
    return uri.replace(queryParameters: params);
  }

  static Uri logByIdUriWithBase(String base, int id, {String? token, String? userToken}) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    final uri = Uri.parse("$normalized$logByIdPath$id");
    final params = <String, String>{};
    if (token != null && token.isNotEmpty) {
      params["token"] = token;
    }
    if (userToken != null && userToken.isNotEmpty) {
      params["user_token"] = userToken;
    }
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  static Uri authLoginUriWithBase(String base) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    return Uri.parse("$normalized$authLoginPath");
  }

  static Uri authRegisterUriWithBase(String base) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    return Uri.parse("$normalized$authRegisterPath");
  }

  static Uri authResetPasswordUriWithBase(String base, {String? adminToken}) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    final uri = Uri.parse("$normalized$authResetPasswordPath");
    if (adminToken == null || adminToken.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {"token": adminToken});
  }

  static Uri authChangePasswordUriWithBase(String base, {String? userToken}) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    final uri = Uri.parse("$normalized$authChangePasswordPath");
    if (userToken == null || userToken.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {"user_token": userToken});
  }

  static Uri authForgotPasswordUriWithBase(String base) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    return Uri.parse("$normalized$authForgotPasswordPath");
  }

  static Uri authResetPasswordTokenUriWithBase(String base) {
    final normalized = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    return Uri.parse("$normalized$authResetPasswordTokenPath");
  }
}
