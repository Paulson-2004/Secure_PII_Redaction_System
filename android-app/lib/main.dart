import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:local_auth/local_auth.dart';
import 'config.dart';

void main() {
  runApp(const SecurePIIApp());
}

const String kPasswordRulesText =
    "Minimum 8 characters, with uppercase, lowercase, number, and special character.";

String? validatePasswordStrength(String value) {
  if (value.length < 8) {
    return "Password must be at least 8 characters";
  }
  if (!RegExp(r"[A-Z]").hasMatch(value)) {
    return "Password must include an uppercase letter";
  }
  if (!RegExp(r"[a-z]").hasMatch(value)) {
    return "Password must include a lowercase letter";
  }
  if (!RegExp(r"[0-9]").hasMatch(value)) {
    return "Password must include a number";
  }
  if (!RegExp(r"[^A-Za-z0-9]").hasMatch(value)) {
    return "Password must include a special character";
  }
  return null;
}

class SecurePIIApp extends StatefulWidget {
  const SecurePIIApp({super.key});

  @override
  State<SecurePIIApp> createState() => _SecurePIIAppState();
}

class _SecurePIIAppState extends State<SecurePIIApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark(),
      theme: ThemeData.light(),
      home: HomeScreen(
        toggleTheme: () => setState(() => isDark = !isDark),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  File? selectedFile;
  String resultText = "";
  int totalPII = 0;
  List boxes = [];
  bool isLoading = false;
  bool returnPdf = false;
  String baseUrl = AppConfig.baseUrl;
  String lastAuditPath = "";
  String connectionStatus = "";
  bool isUnlocked = false;
  bool authInProgress = false;
  String apiToken = "";
  bool biometricOnLaunch = true;
  bool requireToken = true;
  String userToken = "";
  String username = "";
  bool useUserToken = true;

  late AnimationController controller;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    fadeAnimation =
        CurvedAnimation(parent: controller, curve: Curves.easeInOut);
    controller.forward();
    _ensureUnlocked();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString("base_url");
    final lastAudit = prefs.getString("last_audit_path");
    final savedStatus = prefs.getString("connection_status");
    final savedToken = prefs.getString("api_token");
    final savedUserToken = prefs.getString("user_token");
    final savedUsername = prefs.getString("username");
    final savedBiometric = prefs.getBool("biometric_on_launch");
    final savedRequireToken = prefs.getBool("require_token");
    final savedUseUserToken = prefs.getBool("use_user_token");
    if (saved != null && saved.isNotEmpty) {
      if (_isValidUrl(saved)) {
        setState(() => baseUrl = saved);
      } else {
        setState(() => baseUrl = "http://10.0.2.2:8000");
        _saveBaseUrl(baseUrl);
      }
      _validateBaseUrlOnLaunch(saved);
    }
    if (lastAudit != null && lastAudit.isNotEmpty) {
      setState(() => lastAuditPath = lastAudit);
    }
    if (savedStatus != null && savedStatus.isNotEmpty) {
      setState(() => connectionStatus = savedStatus);
    }
    if (savedToken != null) {
      setState(() => apiToken = savedToken);
    }
    if (savedUserToken != null) {
      setState(() => userToken = savedUserToken);
    }
    if (savedUsername != null) {
      setState(() => username = savedUsername);
    }
    if (savedBiometric != null) {
      setState(() => biometricOnLaunch = savedBiometric);
    }
    if (savedRequireToken != null) {
      setState(() => requireToken = savedRequireToken);
    }
    if (savedUseUserToken != null) {
      setState(() => useUserToken = savedUseUserToken);
    }
    _testConnection(baseUrl);
  }

  Future<void> _ensureUnlocked() async {
    if (authInProgress) return;
    setState(() => authInProgress = true);

    if (!biometricOnLaunch) {
      final ok = await _promptForPin();
      if (mounted) {
        setState(() {
          isUnlocked = ok;
          authInProgress = false;
        });
      }
      return;
    }

    final localAuth = LocalAuthentication();
    bool didAuthenticate = false;
    try {
      final canCheck = await localAuth.canCheckBiometrics;
      if (canCheck) {
        didAuthenticate = await localAuth.authenticate(
          localizedReason: "Unlock Secure PII App",
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
      }
    } catch (_) {
      didAuthenticate = false;
    }

    if (!didAuthenticate) {
      didAuthenticate = await _promptForPin();
    }

    if (mounted) {
      setState(() {
        isUnlocked = didAuthenticate;
        authInProgress = false;
      });
    }
  }

  Future<bool> _promptForPin({bool changePin = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final existingPin = prefs.getString("pin_code");

    final controller = TextEditingController();
    final title = existingPin == null || changePin ? "Set PIN" : "Enter PIN";
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "4-6 digit PIN"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return false;
    if (existingPin == null || changePin) {
      await prefs.setString("pin_code", result);
      return true;
    }
    return result == existingPin;
  }

  Future<void> _saveBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("base_url", value);
    setState(() => baseUrl = value);
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.hasScheme && uri.hasAuthority;
  }

  Future<void> _testConnection(String url) async {
    try {
      final base = url.endsWith("/") ? url.substring(0, url.length - 1) : url;
      final uri = Uri.parse("$base/health");
      final response = await http.get(uri);
      if (!mounted) return;
      final ok = response.statusCode == 200;
      final status = ok ? "OK" : "FAIL";
      setState(() => connectionStatus = status);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("connection_status", status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? "Connection OK" : "Connection failed")),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => connectionStatus = "FAIL");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("connection_status", "FAIL");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection failed")),
      );
    }
  }
  
  void _validateBaseUrlOnLaunch(String value) {
    if (!_isValidUrl(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved Base URL is invalid")),
      );
    }
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["png", "jpg", "jpeg", "pdf", "docx", "txt"],
    );

    if (result != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> uploadFile() async {
    if (selectedFile == null) return;

    setState(() => isLoading = true);

    final uri = AppConfig.processUriWithBase(
      baseUrl,
      returnPdf: returnPdf,
      token: requireToken ? apiToken : null,
      userToken: useUserToken ? userToken : null,
    );
    var request = http.MultipartRequest("POST", uri);

    request.files.add(
      await http.MultipartFile.fromPath("file", selectedFile!.path),
    );

    var response = await request.send();
    if (response.statusCode == 401) {
      await _logoutUser(reason: "Session expired. Please log in again.");
      setState(() => isLoading = false);
      return;
    }

    if (returnPdf) {
      final bytes = await response.stream.toBytes();
      final directory = await getApplicationDocumentsDirectory();
      final file = File("${directory.path}/redacted.pdf");
      await file.writeAsBytes(bytes);

      setState(() {
        isLoading = false;
      });

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Redacted PDF",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Redacted PDF saved to device storage")),
      );
      return;
    }

    var responseData = await response.stream.bytesToString();
    var jsonData = json.decode(responseData);

    await _saveAuditLog(jsonData);

    setState(() {
      resultText = jsonData["redacted_text"] ?? "";
      totalPII = jsonData["total_pii_detected"] ?? 0;
      boxes = jsonData["boxes"] ?? [];
      isLoading = false;
    });
  }

  Future<void> downloadText() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File("${directory.path}/redacted.txt");
    await file.writeAsString(resultText);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved to device storage")),
    );
  }

  void copyText() {
    Clipboard.setData(ClipboardData(text: resultText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard")),
    );
  }

  Future<void> _saveAuditLog(dynamic jsonData) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(":", "-");
    final file = File("${directory.path}/audit_$timestamp.json");
    await file.writeAsString(json.encode(jsonData));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("last_audit_path", file.path);
    setState(() => lastAuditPath = file.path);
  }

  Future<Map<String, String>?> _promptCredentials() async {
    final userController = TextEditingController(text: username);
    final passController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text("User Login"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userController,
                    decoration: const InputDecoration(labelText: "Username"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscure = !obscure),
                      ),
                    ),
                    obscureText: obscure,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, {
                    "username": userController.text.trim(),
                    "password": passController.text,
                  }),
                  child: const Text("Login"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>?> _promptRegistration() async {
    final userController = TextEditingController(text: username);
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text("User Registration"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userController,
                    decoration: const InputDecoration(labelText: "Username"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscure = !obscure),
                      ),
                    ),
                    obscureText: obscure,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscure = !obscure),
                      ),
                    ),
                    obscureText: obscure,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, {
                    "username": userController.text.trim(),
                    "email": emailController.text.trim(),
                    "password": passController.text,
                    "confirm": confirmController.text,
                  }),
                  child: const Text("Register"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _performLogin(
    String usernameInput,
    String passwordInput,
  ) async {
    final uri = AppConfig.authLoginUriWithBase(baseUrl);
    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({"username": usernameInput, "password": passwordInput}),
    );
    if (response.statusCode != 200) {
      throw Exception("Login failed: ${response.statusCode}");
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<void> _loginUser() async {
    final creds = await _promptCredentials();
    if (creds == null) return;
    final usernameInput = creds["username"] ?? "";
    final passwordInput = creds["password"] ?? "";
    if (usernameInput.isEmpty || passwordInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username and password required")),
      );
      return;
    }
    try {
      final data = await _performLogin(usernameInput, passwordInput);
      final token = data["token"] as String?;
      final name = data["username"] as String? ?? usernameInput;
      if (token == null || token.isEmpty) {
        throw Exception("No token returned");
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user_token", token);
      await prefs.setString("username", name);
      await prefs.setBool("use_user_token", true);
      if (!mounted) return;
      setState(() {
        userToken = token;
        username = name;
        useUserToken = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login successful")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }
  }

  Future<void> _registerUser() async {
    final creds = await _promptRegistration();
    if (creds == null) return;
    final usernameInput = creds["username"] ?? "";
    final emailInput = creds["email"] ?? "";
    final passwordInput = creds["password"] ?? "";
    final confirm = creds["confirm"] ?? "";
    if (usernameInput.isEmpty || passwordInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username and password required")),
      );
      return;
    }
    if (emailInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email is required")),
      );
      return;
    }
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(emailInput)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email address")),
      );
      return;
    }
    final strength = validatePasswordStrength(passwordInput);
    if (strength != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strength)),
      );
      return;
    }
    if (passwordInput != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }
    try {
      final uri = AppConfig.authRegisterUriWithBase(baseUrl);
      final payload = {
        "username": usernameInput,
        "password": passwordInput,
        "email": emailInput,
      };
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      if (response.statusCode != 200) {
        throw Exception("Registration failed: ${response.statusCode}");
      }
      final loginData = await _performLogin(usernameInput, passwordInput);
      final token = loginData["token"] as String?;
      final name = loginData["username"] as String? ?? usernameInput;
      if (token == null || token.isEmpty) {
        throw Exception("No token returned");
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user_token", token);
      await prefs.setString("username", name);
      await prefs.setBool("use_user_token", true);
      if (!mounted) return;
      setState(() {
        userToken = token;
        username = name;
        useUserToken = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $e")),
      );
    }
  }

  Future<Map<String, String>?> _promptChangePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text("Change Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldController,
                    decoration: InputDecoration(
                      labelText: "Old Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscure = !obscure),
                      ),
                    ),
                    obscureText: obscure,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscure = !obscure),
                      ),
                    ),
                    obscureText: obscure,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    decoration: InputDecoration(
                      labelText: "Confirm New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscure = !obscure),
                      ),
                    ),
                    obscureText: obscure,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, {
                    "old": oldController.text,
                    "new": newController.text,
                    "confirm": confirmController.text,
                  }),
                  child: const Text("Change"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changePassword() async {
    if (userToken.isEmpty || !useUserToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }
    final creds = await _promptChangePassword();
    if (creds == null) return;
    final oldPassword = creds["old"] ?? "";
    final newPassword = creds["new"] ?? "";
    final confirm = creds["confirm"] ?? "";
    if (oldPassword.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }
    if (newPassword != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }
    try {
      final uri = Uri.parse("$baseUrl/auth/change-password?user_token=$userToken");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"old_password": oldPassword, "new_password": newPassword}),
      );
      if (response.statusCode != 200) {
        throw Exception("Change failed: ${response.statusCode}");
      }
      await _logoutUser(reason: "Password changed. Please log in again.");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Change failed: $e")),
      );
    }
  }

  Future<void> _logoutUser({String? reason}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user_token");
    await prefs.remove("username");
    await prefs.setBool("use_user_token", false);
    if (!mounted) return;
    setState(() {
      userToken = "";
      username = "";
      useUserToken = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason ?? "Logged out")),
    );
  }

  Future<String?> _loginWithCredentials(String usernameInput, String passwordInput) async {
    try {
      final data = await _performLogin(usernameInput, passwordInput);
      final token = data["token"] as String?;
      final name = data["username"] as String? ?? usernameInput;
      if (token == null || token.isEmpty) {
        return "No token returned";
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user_token", token);
      await prefs.setString("username", name);
      await prefs.setBool("use_user_token", true);
      if (!mounted) return "Not mounted";
      setState(() {
        userToken = token;
        username = name;
        useUserToken = true;
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _registerWithCredentials(
    String usernameInput,
    String passwordInput,
    String emailInput,
  ) async {
    try {
      final uri = AppConfig.authRegisterUriWithBase(baseUrl);
      final payload = {
        "username": usernameInput,
        "password": passwordInput,
      };
      final email = emailInput.trim();
      if (email.isNotEmpty) {
        payload["email"] = email;
      }
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      if (response.statusCode != 200) {
        return "Registration failed: ${response.statusCode}";
      }
      return await _loginWithCredentials(usernameInput, passwordInput);
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _sendResetEmail(String email) async {
    try {
      final uri = AppConfig.authForgotPasswordUriWithBase(baseUrl);
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email.trim()}),
      );
      if (response.statusCode != 200) {
        return "Reset request failed: ${response.statusCode}";
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _resetPasswordWithToken(
    String token,
    String newPassword,
  ) async {
    try {
      final uri = AppConfig.authResetPasswordTokenUriWithBase(baseUrl);
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"token": token.trim(), "new_password": newPassword}),
      );
      if (response.statusCode != 200) {
        return "Reset failed: ${response.statusCode}";
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _changePasswordWithUser(
    String oldPassword,
    String newPassword,
  ) async {
    if (userToken.isEmpty || !useUserToken) {
      return "Login required";
    }
    try {
      final uri = AppConfig.authChangePasswordUriWithBase(
        baseUrl,
        userToken: userToken,
      );
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"old_password": oldPassword, "new_password": newPassword}),
      );
      if (response.statusCode != 200) {
        return "Change failed: ${response.statusCode}";
      }
      await _logoutUser(reason: "Password changed. Please log in again.");
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void _openAuthScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          baseUrl: baseUrl,
          currentUsername: username,
          isLoggedIn: userToken.isNotEmpty,
          onLogin: _loginWithCredentials,
          onRegister: _registerWithCredentials,
          onSendResetEmail: _sendResetEmail,
          onResetWithToken: _resetPasswordWithToken,
          onChangePassword: _changePasswordWithUser,
          onLogout: () => _logoutUser(),
        ),
      ),
    );
  }

  Future<void> openSettings() async {
    final controller = TextEditingController(text: baseUrl);
    final tokenController = TextEditingController(text: apiToken);
    bool biometricToggle = biometricOnLaunch;
    bool requireTokenToggle = requireToken;
    bool useUserTokenToggle = useUserToken;
    const defaultUrl = "http://10.0.2.2:8000";
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Backend Base URL"),
          content: StatefulBuilder(
            builder: (context, setLocalState) {
              return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "http://10.0.2.2:8000",
                  labelText: "Base URL",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  hintText: "API token (optional)",
                  labelText: "API Token",
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  userToken.isNotEmpty ? "User: $username" : "User: Not logged in",
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: useUserTokenToggle,
                onChanged: (value) =>
                    setLocalState(() => useUserTokenToggle = value),
                title: const Text("Use user token"),
                subtitle: const Text("Attach user_token to requests"),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: requireTokenToggle,
                onChanged: (value) =>
                    setLocalState(() => requireTokenToggle = value),
                title: const Text("Require API token"),
                subtitle: const Text("Send token with API requests"),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: biometricToggle,
                onChanged: (value) => setLocalState(() => biometricToggle = value),
                title: const Text("Biometric on launch"),
                subtitle: const Text("Require biometric unlock at app start"),
              ),
            ],
          );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: baseUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("URL copied")),
                );
              },
              child: const Text("Copy URL"),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: apiToken));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Token copied")),
                );
              },
              child: const Text("Copy Token"),
            ),
            TextButton(
              onPressed: () async {
                final ok = await _promptForPin(changePin: true);
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("PIN updated")),
                  );
                }
              },
              child: const Text("Change PIN"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openAuthScreen();
              },
              child: const Text("Account"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, defaultUrl),
              child: const Text("Reset"),
            ),
            TextButton(
              onPressed: () => _testConnection(controller.text.trim()),
              child: const Text("Test Connection"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      if (!_isValidUrl(result)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid URL format")),
        );
        return;
      }
      final isSecure = result.startsWith("https://");
      if (!isSecure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Warning: Base URL is not HTTPS")),
        );
      }
      await _saveBaseUrl(result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("api_token", tokenController.text.trim());
      await prefs.setBool("biometric_on_launch", biometricToggle);
      await prefs.setBool("require_token", requireTokenToggle);
      await prefs.setBool("use_user_token", useUserTokenToggle);
      setState(() => apiToken = tokenController.text.trim());
      setState(() => biometricOnLaunch = biometricToggle);
      setState(() => requireToken = requireTokenToggle);
      setState(() => useUserToken = useUserTokenToggle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Base URL updated")),
      );
    }
  }

  Widget glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget buildOverlayImage() {
    final path = selectedFile?.path.toLowerCase() ?? "";
    final isImage = path.endsWith(".png") ||
        path.endsWith(".jpg") ||
        path.endsWith(".jpeg");
    if (!isImage) {
      return glassCard(
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedFile?.path.split(Platform.pathSeparator).last ?? "",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(selectedFile!),
        ),
        ...boxes.map((box) {
          return Positioned(
            left: (box["x"] ?? 0) * 1.0,
            top: (box["y"] ?? 0) * 1.0,
            child: Container(
              width: (box["w"] ?? 0) * 1.0,
              height: (box["h"] ?? 0) * 1.0,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 2),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLockScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff6A11CB), Color(0xff2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text(
                "Locked",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _ensureUnlocked,
                child: const Text("Unlock"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isUnlocked) {
      return _buildLockScreen();
    }
    return Scaffold(
      body: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff6A11CB), Color(0xff2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Secure PII Redaction",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (!baseUrl.startsWith("https://"))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "HTTP",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: openSettings,
                      ),
                      IconButton(
                        icon: const Icon(Icons.list_alt, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LogsScreen(
                                baseUrl: baseUrl,
                                apiToken: apiToken,
                                requireToken: requireToken,
                                userToken: userToken,
                                useUserToken: useUserToken,
                                onTokenExpired: (reason) {
                                  _logoutUser(reason: reason);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.dark_mode, color: Colors.white),
                        onPressed: widget.toggleTheme,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Base URL: $baseUrl",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (username.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Logged in as $username",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  if (connectionStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: connectionStatus == "OK"
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Connection: $connectionStatus",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => _testConnection(baseUrl),
                            child: const Text(
                              "Test",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _openAuthScreen,
                      icon: const Icon(Icons.person, color: Colors.white),
                      label: const Text(
                        "Account",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  if (selectedFile != null)
                    buildOverlayImage(),

                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    onPressed: pickFile,
                    icon: const Icon(Icons.image),
                    label: const Text("Select File"),
                  ),
                  const SizedBox(height: 15),

                  ElevatedButton.icon(
                    onPressed: uploadFile,
                    icon: const Icon(Icons.upload),
                    label: const Text("Upload & Process"),
                  ),

                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: returnPdf,
                    onChanged: (value) => setState(() => returnPdf = value),
                    title: const Text("Return PDF"),
                    subtitle: const Text("Saves redacted PDF to device storage"),
                  ),

                  const SizedBox(height: 30),

                  if (isLoading)
                    const CircularProgressIndicator(color: Colors.white),

                  if (resultText.isNotEmpty && !returnPdf)
                    glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total PII: $totalPII",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            resultText,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          if (lastAuditPath.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Last audit log: $lastAuditPath",
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.white70),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: lastAuditPath),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Path copied")),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.folder_open, color: Colors.white70),
                                  onPressed: () async {
                                    await OpenFilex.open(lastAuditPath);
                                  },
                                ),
                              ],
                            ),
                          if (lastAuditPath.isNotEmpty)
                            const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy,
                                    color: Colors.white),
                                onPressed: copyText,
                              ),
                              IconButton(
                                icon: const Icon(Icons.download,
                                    color: Colors.white),
                                onPressed: downloadText,
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LogsScreen extends StatefulWidget {
  final String baseUrl;
  final String apiToken;
  final bool requireToken;
  final String userToken;
  final bool useUserToken;
  final void Function(String reason)? onTokenExpired;

  const LogsScreen({
    super.key,
    required this.baseUrl,
    required this.apiToken,
    required this.requireToken,
    required this.userToken,
    required this.useUserToken,
    this.onTokenExpired,
  });

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen>
    with SingleTickerProviderStateMixin {
  final _filenameController = TextEditingController();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  final _limitController = TextEditingController(text: "50");
  final _pageController = TextEditingController();
  final _pageFocus = FocusNode();
  String _piiType = "";
  bool _loading = false;
  List<dynamic> _logs = [];
  String _error = "";
  int _offset = 0;
  int _countTotal = 0;
  Timer? _debounce;
  bool _filtersLoaded = false;
  String _sortBy = "created_at";
  String _sortDir = "desc";
  bool _dateRangeError = false;
  late final AnimationController _shimmerController;
  bool _myLogsOnly = true;

  Future<void> _fetchLogs() async {
    setState(() {
      _loading = true;
      _error = "";
    });
    try {
      final limit = int.tryParse(_limitController.text.trim()) ?? 50;
      final uri = AppConfig.logsUriWithBase(
        widget.baseUrl,
        token: widget.requireToken ? widget.apiToken : null,
        userToken: (_myLogsOnly && widget.useUserToken) ? widget.userToken : null,
        limit: limit,
        offset: _offset,
        piiType: _piiType,
        filename: _filenameController.text.trim(),
        dateFrom: _dateFromController.text.trim(),
        dateTo: _dateToController.text.trim(),
        sortBy: _sortBy,
        sortDir: _sortDir,
      );
      final response = await http.get(uri);
      if (response.statusCode == 401) {
        widget.onTokenExpired?.call("Session expired. Please log in again.");
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      if (response.statusCode != 200) {
        throw Exception("Failed: ${response.statusCode}");
      }
      final data = json.decode(response.body);
      setState(() {
        _logs = data["logs"] ?? [];
        _countTotal = data["count_total"] ?? 0;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _shimmerController.dispose();
    _filenameController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _limitController.dispose();
    _pageController.dispose();
    _pageFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _pageFocus.addListener(() {
      if (!_pageFocus.hasFocus) {
        setState(() {});
      } else {
        _pageController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _pageController.text.length,
        );
      }
    });
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _filenameController.text = prefs.getString("logs_filter_filename") ?? "";
      _dateFromController.text = prefs.getString("logs_filter_date_from") ?? "";
      _dateToController.text = prefs.getString("logs_filter_date_to") ?? "";
      _limitController.text = prefs.getString("logs_filter_limit") ?? "50";
      _piiType = prefs.getString("logs_filter_pii_type") ?? "";
      _offset = prefs.getInt("logs_offset") ?? 0;
      _sortBy = prefs.getString("logs_sort_by") ?? "created_at";
      _sortDir = prefs.getString("logs_sort_dir") ?? "desc";
      _myLogsOnly = (prefs.getBool("logs_filter_my_logs") ??
              (widget.userToken.isNotEmpty && widget.useUserToken)) &&
          widget.userToken.isNotEmpty &&
          widget.useUserToken;
      _filtersLoaded = true;
    });
    await _fetchLogs();
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("logs_filter_filename", _filenameController.text.trim());
    await prefs.setString("logs_filter_date_from", _dateFromController.text.trim());
    await prefs.setString("logs_filter_date_to", _dateToController.text.trim());
    await prefs.setString("logs_filter_limit", _limitController.text.trim());
    await prefs.setString("logs_filter_pii_type", _piiType);
    await prefs.setInt("logs_offset", _offset);
    await prefs.setString("logs_sort_by", _sortBy);
    await prefs.setString("logs_sort_dir", _sortDir);
    await prefs.setBool("logs_filter_my_logs", _myLogsOnly);
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _offset = 0;
      _saveFilters();
      _fetchLogs();
    });
  }

  Future<void> _pickDate(TextEditingController controller, {required bool isFrom}) async {
    final initial = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final pickedStr = picked.toIso8601String().split("T").first;
      final other = DateTime.tryParse(
        (isFrom ? _dateToController : _dateFromController).text.trim(),
      );
      if (other != null) {
        final invalid = isFrom ? picked.isAfter(other) : picked.isBefore(other);
        if (invalid) {
          setState(() => _dateRangeError = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid date range")),
          );
          return;
        }
      }
      setState(() => _dateRangeError = false);
      controller.text = pickedStr;
      _scheduleFetch();
    }
  }

  void _clearDate(TextEditingController controller) {
    controller.clear();
    setState(() => _dateRangeError = false);
    _scheduleFetch();
  }

  @override
  Widget build(BuildContext context) {
    final limit = int.tryParse(_limitController.text.trim()) ?? 50;
    final canPrev = _offset > 0;
    final canNext = _offset + limit < _countTotal;
    final hasResults = _countTotal > 0;
    final currentPage = hasResults ? (_offset ~/ limit) + 1 : 0;
    final totalPages = hasResults ? ((_countTotal + limit - 1) ~/ limit) : 0;
    final showingStart = hasResults ? _offset + 1 : 0;
    final showingEnd = hasResults ? (_offset + _logs.length) : 0;
    final pageText = currentPage > 0 ? currentPage.toString() : "";
    if (_pageController.text != pageText && !_pageFocus.hasFocus) {
      final selection = _pageController.selection;
      final clampedBase =
          selection.baseOffset.clamp(0, pageText.length);
      final clampedExtent =
          selection.extentOffset.clamp(0, pageText.length);
      _pageController.value = _pageController.value.copyWith(
        text: pageText,
        selection: selection.copyWith(
          baseOffset: clampedBase,
          extentOffset: clampedExtent,
        ),
        composing: TextRange.empty,
      );
    }
    final inputPage = int.tryParse(_pageController.text.trim());
    final canGo = inputPage != null && inputPage >= 1 && inputPage <= totalPages;
    final pageError = (!hasResults)
        ? "No results to paginate"
        : (inputPage == null || inputPage < 1 || inputPage > totalPages)
            ? "Enter 1–$totalPages"
            : null;
    final goTooltip = !hasResults ? "No results to paginate" : (pageError ?? "Go to page");
    return Scaffold(
      appBar: AppBar(
        title: const Text("Redaction Logs"),
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final primary = FocusManager.instance.primaryFocus;
          if (primary?.context?.widget is EditableText) {
            return KeyEventResult.ignored;
          }
          if (!hasResults) return KeyEventResult.ignored;
          final isPrev = event.logicalKey == LogicalKeyboardKey.pageUp ||
              (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                  event.isControlPressed);
          final isNext = event.logicalKey == LogicalKeyboardKey.pageDown ||
              (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                  event.isControlPressed);
          if (isPrev && canPrev) {
            setState(() {
              _offset = (_offset - limit).clamp(0, 1 << 30);
            });
            _saveFilters();
            _fetchLogs();
            return KeyEventResult.handled;
          }
          if (isNext && canNext) {
            setState(() => _offset += limit);
            _saveFilters();
            _fetchLogs();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
            if (!_filtersLoaded)
              const LinearProgressIndicator(minHeight: 2),
            TextField(
              controller: _filenameController,
              decoration: const InputDecoration(labelText: "Filename contains"),
              onChanged: (_) => _scheduleFetch(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _piiType.isEmpty ? null : _piiType,
              decoration: const InputDecoration(labelText: "PII Type"),
              items: const [
                DropdownMenuItem(value: "", child: Text("Any")),
                DropdownMenuItem(value: "AADHAAR", child: Text("AADHAAR")),
                DropdownMenuItem(value: "PAN", child: Text("PAN")),
                DropdownMenuItem(value: "DL", child: Text("DL")),
                DropdownMenuItem(value: "VOTER_ID", child: Text("VOTER_ID")),
                DropdownMenuItem(value: "PASSPORT", child: Text("PASSPORT")),
                DropdownMenuItem(value: "PHONE", child: Text("PHONE")),
                DropdownMenuItem(value: "EMAIL", child: Text("EMAIL")),
                DropdownMenuItem(value: "ACCOUNT", child: Text("ACCOUNT")),
                DropdownMenuItem(value: "IFSC", child: Text("IFSC")),
                DropdownMenuItem(value: "DOB", child: Text("DOB")),
                DropdownMenuItem(value: "IP_ADDRESS", child: Text("IP_ADDRESS")),
                DropdownMenuItem(value: "ADDRESS", child: Text("ADDRESS")),
                DropdownMenuItem(value: "PERSON", child: Text("PERSON")),
              ],
              onChanged: (value) {
                setState(() => _piiType = value ?? "");
                _scheduleFetch();
              },
            ),
            SwitchListTile(
              value: _myLogsOnly,
              onChanged: (widget.userToken.isNotEmpty && widget.useUserToken)
                  ? (value) {
                      setState(() => _myLogsOnly = value);
                      _saveFilters();
                      _scheduleFetch();
                    }
                  : null,
              title: const Text("My logs only"),
              subtitle: Text(widget.userToken.isNotEmpty
                  ? "Filter logs for your account"
                  : "Login to enable"),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateFromController,
                    decoration: const InputDecoration(
                      labelText: "Date from (YYYY-MM-DD)",
                    ),
                    readOnly: true,
                    onTap: () => _pickDate(_dateFromController, isFrom: true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: "Clear from date",
                  onPressed: () => _clearDate(_dateFromController),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dateToController,
                    decoration: const InputDecoration(
                      labelText: "Date to (YYYY-MM-DD)",
                    ),
                    readOnly: true,
                    onTap: () => _pickDate(_dateToController, isFrom: false),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: "Clear to date",
                  onPressed: () => _clearDate(_dateToController),
                ),
              ],
            ),
            if (_dateRangeError)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Date range is invalid",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _limitController,
              decoration: const InputDecoration(labelText: "Limit"),
              keyboardType: TextInputType.number,
              onChanged: (_) => _scheduleFetch(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: const InputDecoration(labelText: "Sort by"),
                    items: const [
                      DropdownMenuItem(value: "created_at", child: Text("Created At")),
                      DropdownMenuItem(value: "size_bytes", child: Text("Size")),
                      DropdownMenuItem(value: "total_pii", child: Text("Total PII")),
                      DropdownMenuItem(value: "filename", child: Text("Filename")),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortBy = value);
                      _scheduleFetch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortDir,
                    decoration: const InputDecoration(labelText: "Sort dir"),
                    items: const [
                      DropdownMenuItem(value: "desc", child: Text("Desc")),
                      DropdownMenuItem(value: "asc", child: Text("Asc")),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortDir = value);
                      _scheduleFetch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sortBy = "created_at";
                      _sortDir = "desc";
                    });
                    _scheduleFetch();
                  },
                  child: const Text("Reset Sort"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _fetchLogs,
                  child: const Text("Fetch Logs"),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    _filenameController.clear();
                    _dateFromController.clear();
                    _dateToController.clear();
                    _limitController.text = "50";
                    setState(() {
                      _piiType = "";
                      _offset = 0;
                    });
                    _saveFilters();
                    _fetchLogs();
                  },
                  child: const Text("Clear Filters"),
                ),
                if (_loading) const CircularProgressIndicator(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text("Total: $_countTotal"),
                const Spacer(),
                Text("Page $currentPage of $totalPages"),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: hasResults && _offset > 0
                      ? () {
                          setState(() => _offset = 0);
                          _saveFilters();
                          _fetchLogs();
                        }
                      : null,
                  child: const Text("First"),
                ),
                TextButton(
                  onPressed: canPrev
                      ? () {
                          setState(() {
                            _offset = (_offset - limit).clamp(0, 1 << 30);
                          });
                          _saveFilters();
                          _fetchLogs();
                        }
                      : null,
                  child: const Text("Prev"),
                ),
                TextButton(
                  onPressed: canNext
                      ? () {
                          setState(() => _offset += limit);
                          _saveFilters();
                          _fetchLogs();
                        }
                      : null,
                  child: const Text("Next"),
                ),
                TextButton(
                  onPressed: hasResults && _offset + limit < _countTotal
                      ? () {
                          setState(() => _offset = (totalPages - 1) * limit);
                          _saveFilters();
                          _fetchLogs();
                        }
                      : null,
                  child: const Text("Last"),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text("Showing $showingStart–$showingEnd of $_countTotal"),
                const Spacer(),
                SizedBox(
                  width: 70,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        focusNode: _pageFocus,
                        controller: _pageController,
                        decoration: const InputDecoration(labelText: "Page"),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.go,
                        enabled: hasResults,
                        onSubmitted: (_) {
                          if (!canGo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Invalid page number")),
                            );
                            return;
                          }
                          final raw = int.tryParse(_pageController.text.trim());
                          if (raw == null || raw < 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Invalid page number")),
                            );
                            return;
                          }
                          final target = raw > totalPages ? totalPages : raw;
                          setState(() => _offset = (target - 1) * limit);
                          _saveFilters();
                          _fetchLogs();
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pageError ?? "Max: $totalPages",
                        style: TextStyle(
                          fontSize: 11,
                          color: pageError == null ? Colors.grey : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: canGo ? "Go to page" : goTooltip,
                  child: TextButton(
                    onPressed: canGo
                        ? () {
                            final raw = int.tryParse(_pageController.text.trim());
                            if (raw == null || raw < 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Invalid page number")),
                              );
                              return;
                            }
                            final target = raw > totalPages ? totalPages : raw;
                            setState(() => _offset = (target - 1) * limit);
                            _saveFilters();
                            _fetchLogs();
                          }
                        : null,
                    child: const Text("Go"),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: hasResults
                      ? () {
                          setState(() => _offset = 0);
                          _saveFilters();
                          _fetchLogs();
                        }
                      : null,
                  child: const Text("Reset Page"),
                ),
              ],
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      _offset = 0;
                      await _fetchLogs();
                    },
                    child: _loading && _logs.isEmpty
                        ? _buildShimmerList()
                        : ListView.separated(
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final log = _logs[index] as Map<String, dynamic>;
                              final counts =
                                  (log["pii_counts"] as Map?)
                                          ?.cast<String, dynamic>() ??
                                      {};
                              return ListTile(
                                title: Text(log["filename"] ?? ""),
                                subtitle: Text(
                                  "PII: ${log["total_pii"]} • ${log["created_at"]}",
                                ),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: counts.entries
                                      .where((entry) => (entry.value as num) > 0)
                                      .map(
                                        (entry) => Chip(
                                          label: Text("${entry.key}:${entry.value}"),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      )
                                      .toList(),
                                ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LogDetailScreen(
                                logId: log["id"] as int,
                                initialLog: log,
                                baseUrl: widget.baseUrl,
                                apiToken: widget.apiToken,
                                requireToken: widget.requireToken,
                                userToken: widget.userToken,
                                useUserToken: widget.useUserToken,
                                onTokenExpired: widget.onTokenExpired,
                              ),
                            ),
                          );
                        },
                      );
                            },
                          ),
                  ),
                  if (_loading && _logs.isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.1),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return Shimmer(
          animation: _shimmerController,
          child: ListTile(
            title: Container(
              height: 14,
              width: double.infinity,
              color: Colors.grey.shade300,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                height: 12,
                width: 180,
                color: Colors.grey.shade300,
              ),
            ),
          ),
        );
      },
    );
  }
}

class Shimmer extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const Shimmer({super.key, required this.child, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (rect) {
            final dx = rect.width * 2 * animation.value - rect.width;
            return LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: GradientTranslation(Offset(dx, 0)),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}

class LogDetailScreen extends StatefulWidget {
  final int logId;
  final Map<String, dynamic>? initialLog;
  final String baseUrl;
  final String apiToken;
  final bool requireToken;
  final String userToken;
  final bool useUserToken;
  final void Function(String reason)? onTokenExpired;

  const LogDetailScreen({
    super.key,
    required this.logId,
    required this.baseUrl,
    required this.apiToken,
    required this.requireToken,
    required this.userToken,
    required this.useUserToken,
    this.onTokenExpired,
    this.initialLog,
  });

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class AuthScreen extends StatefulWidget {
  final String baseUrl;
  final String currentUsername;
  final bool isLoggedIn;
  final Future<String?> Function(String username, String password) onLogin;
  final Future<String?> Function(String username, String password, String email) onRegister;
  final Future<String?> Function(String email) onSendResetEmail;
  final Future<String?> Function(String token, String newPassword) onResetWithToken;
  final Future<String?> Function(String oldPassword, String newPassword) onChangePassword;
  final VoidCallback onLogout;

  const AuthScreen({
    super.key,
    required this.baseUrl,
    required this.currentUsername,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onRegister,
    required this.onSendResetEmail,
    required this.onResetWithToken,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginUser = TextEditingController();
  final _loginPass = TextEditingController();
  final _regUser = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  final _regConfirm = TextEditingController();
  bool _loginObscure = true;
  bool _regObscure = true;
  bool _loading = false;
  String _error = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loginUser.text = widget.currentUsername;
    _regUser.text = widget.currentUsername;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUser.dispose();
    _loginPass.dispose();
    _regUser.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    _regConfirm.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = "";
    });
    final username = _loginUser.text.trim();
    final password = _loginPass.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Username and password required";
      });
      return;
    }
    final err = await widget.onLogin(username, password);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err ?? "";
    });
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login successful")),
      );
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _loading = true;
      _error = "";
    });
    final username = _regUser.text.trim();
    final email = _regEmail.text.trim();
    final password = _regPass.text;
    final confirm = _regConfirm.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Username and password required";
      });
      return;
    }
    if (email.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Email is required";
      });
      return;
    }
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) {
      setState(() {
        _loading = false;
        _error = "Invalid email address";
      });
      return;
    }
    final strength = validatePasswordStrength(password);
    if (strength != null) {
      setState(() {
        _loading = false;
        _error = strength;
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _loading = false;
        _error = "Passwords do not match";
      });
      return;
    }
    final err = await widget.onRegister(username, password, email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err ?? "";
    });
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful")),
      );
    }
  }

  Future<void> _openForgotPassword() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          onSend: widget.onSendResetEmail,
          onReset: widget.onResetWithToken,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset successful")),
      );
    }
  }

  Future<void> _openChangePassword() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangePasswordScreen(
          onChange: widget.onChangePassword,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password changed. Please log in again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Login"),
            Tab(text: "Register"),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isLoggedIn
                        ? "Logged in as ${widget.currentUsername}"
                        : "Not logged in",
                  ),
                ),
                if (widget.isLoggedIn)
                  TextButton(
                    onPressed: () {
                      widget.onLogout();
                      Navigator.pop(context);
                    },
                    child: const Text("Logout"),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    children: [
                      TextField(
                        controller: _loginUser,
                        decoration: const InputDecoration(labelText: "Username"),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginPass,
                        decoration: InputDecoration(
                          labelText: "Password",
                          suffixIcon: IconButton(
                            icon: Icon(
                              _loginObscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _loginObscure = !_loginObscure),
                          ),
                        ),
                        obscureText: _loginObscure,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        child: const Text("Login"),
                      ),
                      TextButton(
                        onPressed: _openForgotPassword,
                        child: const Text("Forgot Password?"),
                      ),
                      if (widget.isLoggedIn)
                        TextButton(
                          onPressed: _openChangePassword,
                          child: const Text("Change Password"),
                        ),
                    ],
                  ),
                  ListView(
                    children: [
                      TextField(
                        controller: _regUser,
                        decoration: const InputDecoration(labelText: "Username"),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _regEmail,
                        decoration: const InputDecoration(labelText: "Email"),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _regPass,
                        decoration: InputDecoration(
                          labelText: "Password",
                          suffixIcon: IconButton(
                            icon: Icon(
                              _regObscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _regObscure = !_regObscure),
                          ),
                        ),
                        obscureText: _regObscure,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kPasswordRulesText,
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _regConfirm,
                        decoration: const InputDecoration(labelText: "Confirm Password"),
                        obscureText: _regObscure,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loading ? null : _handleRegister,
                        child: const Text("Register"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final Future<String?> Function(String email) onSend;
  final Future<String?> Function(String token, String newPassword) onReset;

  const ForgotPasswordScreen({
    super.key,
    required this.onSend,
    required this.onReset,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _sent = false;
  String _error = "";
  String _info = "";

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    setState(() {
      _loading = true;
      _error = "";
      _info = "";
    });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Email is required";
      });
      return;
    }
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) {
      setState(() {
        _loading = false;
        _error = "Invalid email address";
      });
      return;
    }
    final err = await widget.onSend(email);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    setState(() {
      _loading = false;
      _sent = true;
      _info = "If the account exists, a reset token was sent.";
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = "";
    });
    final token = _tokenController.text.trim();
    final password = _passController.text;
    final confirm = _confirmController.text;
    if (token.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = "All fields are required";
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _loading = false;
        _error = "Passwords do not match";
      });
      return;
    }
    final strength = validatePasswordStrength(password);
    if (strength != null) {
      setState(() {
        _loading = false;
        _error = strength;
      });
      return;
    }
    final err = await widget.onReset(token, password);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red)),
            if (_info.isNotEmpty)
              Text(_info, style: const TextStyle(color: Colors.green)),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _sendEmail,
              child: const Text("Send Reset Email"),
            ),
            const SizedBox(height: 20),
            if (_sent) ...[
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(labelText: "Reset Token"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                decoration: InputDecoration(
                  labelText: "New Password",
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
              ),
              const SizedBox(height: 12),
              Text(
                kPasswordRulesText,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: "Confirm Password"),
                obscureText: _obscure,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: const Text("Reset Password"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  final Future<String?> Function(String oldPassword, String newPassword) onChange;

  const ChangePasswordScreen({super.key, required this.onChange});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _error = "";

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = "";
    });
    final oldPass = _oldController.text;
    final newPass = _newController.text;
    final confirm = _confirmController.text;
    if (oldPass.isEmpty || newPass.isEmpty) {
      setState(() {
        _loading = false;
        _error = "All fields are required";
      });
      return;
    }
    if (newPass != confirm) {
      setState(() {
        _loading = false;
        _error = "Passwords do not match";
      });
      return;
    }
    final strength = validatePasswordStrength(newPass);
    if (strength != null) {
      setState(() {
        _loading = false;
        _error = strength;
      });
      return;
    }
    final err = await widget.onChange(oldPass, newPass);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red)),
            TextField(
              controller: _oldController,
              decoration: InputDecoration(
                labelText: "Old Password",
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              decoration: const InputDecoration(labelText: "New Password"),
              obscureText: _obscure,
            ),
            const SizedBox(height: 12),
            Text(
              kPasswordRulesText,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(labelText: "Confirm Password"),
              obscureText: _obscure,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: const Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }
}
class _LogDetailScreenState extends State<LogDetailScreen> {
  Map<String, dynamic>? _log;
  bool _loading = true;
  String _error = "";

  @override
  void initState() {
    super.initState();
    _log = widget.initialLog;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final uri = AppConfig.logByIdUriWithBase(
        widget.baseUrl,
        widget.logId,
        token: widget.requireToken ? widget.apiToken : null,
        userToken: widget.useUserToken ? widget.userToken : null,
      );
      final response = await http.get(uri);
      if (response.statusCode == 401) {
        widget.onTokenExpired?.call("Session expired. Please log in again.");
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = "Session expired";
        });
        return;
      }
      if (response.statusCode != 200) {
        throw Exception("Failed: ${response.statusCode}");
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _log = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    final counts =
        (log?["pii_counts"] as Map?)?.cast<String, dynamic>() ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text("Log Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading && log == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error, style: const TextStyle(color: Colors.red)),
                    ),
                  Text("Filename: ${log?["filename"] ?? ""}"),
                  const SizedBox(height: 8),
                  Text("Content-Type: ${log?["content_type"] ?? ""}"),
                  const SizedBox(height: 8),
                  Text("Size: ${log?["size_bytes"] ?? 0} bytes"),
                  const SizedBox(height: 8),
                  Text("Total PII: ${log?["total_pii"] ?? 0}"),
                  const SizedBox(height: 8),
                  Text("Created: ${log?["created_at"] ?? ""}"),
                  const SizedBox(height: 16),
                  const Text("PII Counts"),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: counts.entries
                        .where((entry) => (entry.value as num) > 0)
                        .map(
                          (entry) => Chip(
                            label: Text("${entry.key}:${entry.value}"),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
      ),
    );
  }
}
