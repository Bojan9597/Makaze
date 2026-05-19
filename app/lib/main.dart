import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MakazeApp());
}

enum AppRole { customer, salon }

enum AuthMode { login, register }

class MakazeApp extends StatelessWidget {
  const MakazeApp({super.key, this.authClient});

  final AuthClient? authClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makaze',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.ink,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
      home: AuthGate(authClient: authClient ?? const FlaskAuthClient()),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.authClient});

  final AuthClient authClient;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthSession? _session;

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return AuthScreen(
        authClient: widget.authClient,
        onAuthenticated: (authenticatedSession) {
          setState(() => _session = authenticatedSession);
        },
      );
    }

    return MakazeShell(
      session: session,
      initialRole: session.role,
      onLogout: () {
        setState(() => _session = null);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authClient,
    required this.onAuthenticated,
  });

  final AuthClient authClient;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerFullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerSalonNameController = TextEditingController();
  final _registerSalonAddressController = TextEditingController();
  final _registerCityController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  AuthMode _mode = AuthMode.login;
  AppRole _role = AppRole.customer;
  LatLng? _registerSalonPoint;
  LatLng? _registerSalonMapCenter;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isLogin => _mode == AuthMode.login;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerFullNameController.dispose();
    _registerEmailController.dispose();
    _registerPhoneController.dispose();
    _registerSalonNameController.dispose();
    _registerSalonAddressController.dispose();
    _registerCityController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Logovanje' : 'Registracija';
    final action = _isLogin ? 'Prijavi se' : 'Kreiraj nalog';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandHeader(),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isLogin
                                    ? 'Nastavi kao korisnik ili salon.'
                                    : 'Napravi nalog za rezervacije ili upravljanje salonom.',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 18),
                              SegmentedButton<AppRole>(
                                segments: const [
                                  ButtonSegment(
                                    value: AppRole.customer,
                                    icon: Icon(Icons.person_search_outlined),
                                    label: Text('Korisnik'),
                                  ),
                                  ButtonSegment(
                                    value: AppRole.salon,
                                    icon: Icon(Icons.business_center_outlined),
                                    label: Text('Salon'),
                                  ),
                                ],
                                selected: {_role},
                                showSelectedIcon: false,
                                onSelectionChanged: (selection) {
                                  setState(() => _role = selection.first);
                                },
                              ),
                              const SizedBox(height: 18),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _isLogin
                                    ? LoginFields(
                                        key: ValueKey(_role),
                                        emailController: _loginEmailController,
                                        passwordController:
                                            _loginPasswordController,
                                      )
                                    : RegisterFields(
                                        key: ValueKey('register-${_role.name}'),
                                        role: _role,
                                        fullNameController:
                                            _registerFullNameController,
                                        emailController:
                                            _registerEmailController,
                                        phoneController:
                                            _registerPhoneController,
                                        salonNameController:
                                            _registerSalonNameController,
                                        salonAddressController:
                                            _registerSalonAddressController,
                                        cityController: _registerCityController,
                                        selectedSalonPoint: _registerSalonPoint,
                                        mapCenter: _registerSalonMapCenter,
                                        onFindSalonLocation:
                                            _findRegisterSalonLocation,
                                        onSalonLocationSelected: (point) {
                                          setState(() {
                                            _registerSalonPoint = point;
                                          });
                                        },
                                        passwordController:
                                            _registerPasswordController,
                                        confirmPasswordController:
                                            _registerConfirmPasswordController,
                                      ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                WarningBox(text: _errorMessage!),
                              ],
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _isSubmitting ? null : _submit,
                                icon: Icon(
                                  _isSubmitting
                                      ? Icons.hourglass_top
                                      : _isLogin
                                      ? Icons.login
                                      : Icons.person_add_alt_1_outlined,
                                ),
                                label: Text(
                                  _isSubmitting ? 'Molimo sacekaj' : action,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _mode = _isLogin
                                              ? AuthMode.register
                                              : AuthMode.login;
                                          _errorMessage = null;
                                        });
                                      },
                                child: Text(
                                  _isLogin
                                      ? 'Nemam nalog - registracija'
                                      : 'Imam nalog - logovanje',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (!_isLogin && _role == AppRole.salon && _registerSalonPoint == null) {
      setState(
        () => _errorMessage =
            'Oznaci lokaciju salona na mapi prije kreiranja naloga.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = _isLogin
          ? await widget.authClient.login(
              email: _loginEmailController.text.trim(),
              password: _loginPasswordController.text,
            )
          : await widget.authClient.register(
              role: _role,
              fullName: _registerFullNameController.text.trim(),
              email: _registerEmailController.text.trim(),
              phoneNumber: _registerPhoneController.text.trim(),
              password: _registerPasswordController.text,
              salonName: _registerSalonNameController.text.trim(),
              salonAddress: _registerSalonAddressController.text.trim(),
              city: _registerCityController.text.trim(),
              latitude: _registerSalonPoint?.latitude,
              longitude: _registerSalonPoint?.longitude,
            );

      if (!mounted) return;
      widget.onAuthenticated(session);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'API nije dostupan. Provjeri da Flask radi na ${ApiConfig.baseUrl}.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _findRegisterSalonLocation() async {
    final query = [
      _registerSalonAddressController.text.trim(),
      _registerCityController.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    try {
      final point = await geocodePlaceQuery(query);
      if (!mounted) return;
      if (point == null) {
        setState(
          () =>
              _errorMessage = 'Ne mogu pronaci lokaciju. Klikni na mapu rucno.',
        );
        return;
      }
      setState(() {
        _registerSalonPoint = point;
        _registerSalonMapCenter = point;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Pretraga lokacije nije dostupna. Klikni na mapu rucno.',
      );
    }
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(31),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.content_cut,
            color: AppColors.primary,
            size: 34,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Makaze',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Rezervacije termina za frizerske salone',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class LoginFields extends StatelessWidget {
  const LoginFields({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: [
        AuthTextField(
          label: 'Email',
          icon: Icons.mail_outline,
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          label: 'Lozinka',
          icon: Icons.lock_outline,
          controller: passwordController,
          obscureText: true,
        ),
      ],
    );
  }
}

class RegisterFields extends StatelessWidget {
  const RegisterFields({
    super.key,
    required this.role,
    required this.fullNameController,
    required this.emailController,
    required this.phoneController,
    required this.salonNameController,
    required this.salonAddressController,
    required this.cityController,
    required this.selectedSalonPoint,
    required this.mapCenter,
    required this.onFindSalonLocation,
    required this.onSalonLocationSelected,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  final AppRole role;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController salonNameController;
  final TextEditingController salonAddressController;
  final TextEditingController cityController;
  final LatLng? selectedSalonPoint;
  final LatLng? mapCenter;
  final VoidCallback onFindSalonLocation;
  final ValueChanged<LatLng> onSalonLocationSelected;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: [
        AuthTextField(
          label: 'Ime i prezime',
          icon: Icons.badge_outlined,
          controller: fullNameController,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          label: 'Email',
          icon: Icons.mail_outline,
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          label: 'Broj telefona',
          icon: Icons.phone_outlined,
          controller: phoneController,
          keyboardType: TextInputType.phone,
          required: false,
        ),
        if (role == AppRole.salon) ...[
          const SizedBox(height: 12),
          AuthTextField(
            label: 'Naziv salona',
            icon: Icons.storefront_outlined,
            controller: salonNameController,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            label: 'Adresa salona',
            icon: Icons.place_outlined,
            controller: salonAddressController,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            label: 'Grad',
            icon: Icons.location_city_outlined,
            controller: cityController,
            required: false,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onFindSalonLocation,
            icon: const Icon(Icons.search),
            label: const Text('Pronadji adresu na mapi'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: MapPanel(
              salons: const [],
              center:
                  mapCenter ??
                  selectedSalonPoint ??
                  cityFallbackCoordinates(cityController.text),
              selectedPoint: selectedSalonPoint,
              onLocationSelected: onSalonLocationSelected,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedSalonPoint == null
                ? 'Klikni na mapu da oznacis gdje je salon.'
                : 'Lokacija izabrana: ${selectedSalonPoint!.latitude.toStringAsFixed(5)}, ${selectedSalonPoint!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        AuthTextField(
          label: 'Lozinka',
          icon: Icons.lock_outline,
          controller: passwordController,
          obscureText: true,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          label: 'Ponovi lozinku',
          icon: Icons.lock_reset_outlined,
          controller: confirmPasswordController,
          obscureText: true,
          extraValidator: (value) {
            if (value != passwordController.text) {
              return 'Lozinke se ne poklapaju';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.required = true,
    this.extraValidator,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool required;
  final String? Function(String value)? extraValidator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (required && trimmed.isEmpty) return 'Obavezno polje';
        if (!required && trimmed.isEmpty) return null;
        if (label == 'Email' && !trimmed.contains('@')) {
          return 'Unesi ispravan email';
        }
        if (obscureText && trimmed.length < 6) {
          return 'Najmanje 6 karaktera';
        }
        return extraValidator?.call(value ?? '');
      },
    );
  }
}

abstract class AuthClient {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> register({
    required AppRole role,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String salonName,
    required String salonAddress,
    required String city,
    double? latitude,
    double? longitude,
  });
}

class FlaskAuthClient implements AuthClient {
  const FlaskAuthClient();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    return _parseAuthResponse(response);
  }

  @override
  Future<AuthSession> register({
    required AppRole role,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String salonName,
    required String salonAddress,
    required String city,
    double? latitude,
    double? longitude,
  }) async {
    final body = {
      'role': role == AppRole.salon ? 'Salon' : 'Customer',
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
      if (role == AppRole.salon) ...{
        'salonName': salonName,
        'salonAddress': salonAddress,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
      },
    };

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    return _parseAuthResponse(response);
  }

  AuthSession _parseAuthResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        decoded['message'] as String? ?? 'Neuspjesan zahtjev prema API-ju.',
      );
    }

    final user = decoded['user'] as Map<String, dynamic>?;
    if (user == null) {
      throw const AuthException('API nije vratio korisnika.');
    }

    final salon = decoded['salon'] as Map<String, dynamic>?;

    return AuthSession(
      token: decoded['token'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      fullName: user['fullName'] as String? ?? '',
      email: user['email'] as String? ?? '',
      role: appRoleFromApi(user['role'] as String?),
      profileImageUrl: user['profileImageUrl'] as String?,
      salonId: salon?['id'] as String?,
      salonName: salon?['name'] as String?,
    );
  }
}

class AppApiClient {
  const AppApiClient(this.session);

  final AuthSession session;

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${session.token}',
  };

  Future<List<SalonInfo>> listSalons() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salons'),
    );
    final decoded = _decode(response);
    final salons = decoded['salons'] as List<dynamic>? ?? [];
    return salons
        .map((item) => SalonInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> listFavoriteSalonIds() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites'),
      headers: _authHeaders,
    );
    final decoded = _decode(response);
    final salons = decoded['salons'] as List<dynamic>? ?? [];
    return salons
        .map((item) => SalonInfo.fromJson(item as Map<String, dynamic>).id)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> addFavorite(String salonId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/$salonId'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<void> removeFavorite(String salonId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/$salonId'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<LatLng?> geocodePlace(String query) async {
    return geocodePlaceQuery(query);
  }

  Future<SalonDetails> getSalonDetails(String salonId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId'),
    );
    final decoded = _decode(response);
    return SalonDetails.fromJson(decoded);
  }

  Future<SalonInfo> updateSalon({
    required String salonId,
    required String name,
    required String description,
    required String address,
    required String city,
    required String country,
    required String phoneNumber,
    required int capacity,
    double? latitude,
    double? longitude,
    bool isActive = true,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId'),
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'description': description,
        'address': address,
        'city': city,
        'country': country,
        'phoneNumber': phoneNumber,
        'capacity': capacity,
        'latitude': latitude,
        'longitude': longitude,
        'isActive': isActive,
      }),
    );
    final decoded = _decode(response);
    return SalonInfo.fromJson(decoded['salon'] as Map<String, dynamic>);
  }

  Future<List<SalonImageInfo>> listSalonImages(String salonId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/images'),
    );
    final decoded = _decode(response);
    final images = decoded['images'] as List<dynamic>? ?? [];
    return images
        .map((item) => SalonImageInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createSalonImage({
    required String salonId,
    required String imageUrl,
    required bool isMain,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/images'),
      headers: _authHeaders,
      body: jsonEncode({'imageUrl': imageUrl, 'isMain': isMain}),
    );
    _decode(response);
  }

  Future<SalonImageInfo> uploadSalonImage({
    required String salonId,
    required PlatformFile file,
    required bool isMain,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw const AuthException('Nije moguce procitati izabranu sliku.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/images/upload'),
    );
    request.headers['Authorization'] = 'Bearer ${session.token}';
    request.fields['isMain'] = isMain.toString();
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: file.name),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    return SalonImageInfo.fromJson(decoded['image'] as Map<String, dynamic>);
  }

  Future<void> deleteSalonImage({
    required String salonId,
    required String imageId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/images/$imageId'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<void> setMainSalonImage({
    required String salonId,
    required String imageId,
  }) async {
    final response = await http.put(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/salons/$salonId/images/$imageId/main',
      ),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<List<ApiServiceInfo>> listServices(String salonId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/services'),
    );
    final decoded = _decode(response);
    final services = decoded['services'] as List<dynamic>? ?? [];
    return services
        .map((item) => ApiServiceInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createService({
    required String salonId,
    required String name,
    required int durationMinutes,
    required double price,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/services'),
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'durationMinutes': durationMinutes,
        'price': price,
        'isActive': true,
      }),
    );
    _decode(response);
  }

  Future<List<WorkingHourInfo>> listWorkingHours(String salonId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/working-hours'),
    );
    final decoded = _decode(response);
    final rows = decoded['workingHours'] as List<dynamic>? ?? [];
    return rows
        .map((item) => WorkingHourInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkingHourInfo>> updateWorkingHours({
    required String salonId,
    required List<WorkingHourInfo> workingHours,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/working-hours'),
      headers: _authHeaders,
      body: jsonEncode({
        'workingHours': workingHours.map((item) => item.toJson()).toList(),
      }),
    );
    final decoded = _decode(response);
    final rows = decoded['workingHours'] as List<dynamic>? ?? [];
    return rows
        .map((item) => WorkingHourInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<SalonBreakInfo>> listBreaks(String salonId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/breaks'),
    );
    final decoded = _decode(response);
    final rows = decoded['breaks'] as List<dynamic>? ?? [];
    return rows
        .map((item) => SalonBreakInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createBreak({
    required String salonId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/breaks'),
      headers: _authHeaders,
      body: jsonEncode({
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'reason': reason,
      }),
    );
    _decode(response);
  }

  Future<void> deleteBreak({
    required String salonId,
    required String breakId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/breaks/$breakId'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<List<ApiSlotInfo>> availableSlots({
    required String salonId,
    required String serviceId,
    required DateTime date,
  }) async {
    final dateText = date.toIso8601String().substring(0, 10);
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/salons/$salonId/available-slots?serviceId=$serviceId&date=$dateText',
      ),
    );
    final decoded = _decode(response);
    final slots = decoded['slots'] as List<dynamic>? ?? [];
    return slots
        .map((item) => ApiSlotInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createReservation({
    required String salonId,
    required String serviceId,
    required String startTime,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reservations'),
      headers: _authHeaders,
      body: jsonEncode({
        'salonId': salonId,
        'serviceId': serviceId,
        'startTime': startTime,
      }),
    );
    _decode(response);
  }

  Future<List<BookingInfo>> myReservations() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/reservations/my'),
      headers: _authHeaders,
    );
    final decoded = _decode(response);
    final reservations = decoded['reservations'] as List<dynamic>? ?? [];
    return reservations
        .map((item) => BookingInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RequestInfo>> salonReservations({String? status}) async {
    final salonId = session.salonId;
    if (salonId == null || salonId.isEmpty) return [];

    final query = status == null || status.isEmpty ? '' : '?status=$status';
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salons/$salonId/reservations$query'),
      headers: _authHeaders,
    );
    final decoded = _decode(response);
    final reservations = decoded['reservations'] as List<dynamic>? ?? [];
    return reservations
        .map((item) => RequestInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RequestInfo>> salonRequests() {
    return salonReservations(status: 'Pending');
  }

  Future<void> acceptReservation(String reservationId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reservations/$reservationId/accept'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<void> rejectReservation(String reservationId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reservations/$reservationId/reject'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<void> completeReservation(String reservationId) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/reservations/$reservationId/complete',
      ),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<void> noShowReservation(String reservationId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reservations/$reservationId/no-show'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<void> cancelReservation(String reservationId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reservations/$reservationId/cancel'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<String?> uploadProfileImage(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw const AuthException('Nije moguce procitati izabranu sliku.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/users/me/profile-image'),
    );
    request.headers['Authorization'] = 'Bearer ${session.token}';
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: file.name),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    final user = decoded['user'] as Map<String, dynamic>?;
    return user?['profileImageUrl'] as String?;
  }

  Future<List<NotificationInfo>> listNotifications() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications'),
      headers: _authHeaders,
    );
    final decoded = _decode(response);
    final notifications = decoded['notifications'] as List<dynamic>? ?? [];
    return notifications
        .map((item) => NotificationInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAllNotificationsRead() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/read-all'),
      headers: _authHeaders,
    );
    _decode(response);
  }

  Future<void> createReview({
    required String reservationId,
    required int rating,
    required String comment,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reviews'),
      headers: _authHeaders,
      body: jsonEncode({
        'reservationId': reservationId,
        'rating': rating,
        'comment': comment,
      }),
    );
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        decoded['message'] as String? ?? 'API zahtjev nije uspio.',
      );
    }
    return decoded;
  }
}

class ApiConfig {
  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:5001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5001';
    }
    return 'http://127.0.0.1:5001';
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.profileImageUrl,
    this.salonId,
    this.salonName,
  });

  final String token;
  final String userId;
  final String fullName;
  final String email;
  final AppRole role;
  final String? profileImageUrl;
  final String? salonId;
  final String? salonName;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

AppRole appRoleFromApi(String? role) {
  final normalized = (role ?? '').toLowerCase();
  if (normalized == 'barber' || normalized == 'salon') {
    return AppRole.salon;
  }
  return AppRole.customer;
}

class MakazeShell extends StatefulWidget {
  const MakazeShell({
    super.key,
    required this.session,
    required this.initialRole,
    required this.onLogout,
  });

  final AuthSession session;
  final AppRole initialRole;
  final VoidCallback onLogout;

  @override
  State<MakazeShell> createState() => _MakazeShellState();
}

class _MakazeShellState extends State<MakazeShell> {
  int _selectedIndex = 0;

  List<_Destination> get _destinations {
    if (widget.session.role == AppRole.customer) {
      return const [
        _Destination('Saloni', Icons.storefront_outlined, Icons.storefront),
        _Destination('Mapa', Icons.map_outlined, Icons.map),
        _Destination('Termini', Icons.event_note_outlined, Icons.event_note),
        _Destination('Profil', Icons.person_outline, Icons.person),
      ];
    }

    return const [
      _Destination('Danas', Icons.today_outlined, Icons.today),
      _Destination('Zahtjevi', Icons.inbox_outlined, Icons.inbox),
      _Destination(
        'Kalendar',
        Icons.calendar_month_outlined,
        Icons.calendar_month,
      ),
      _Destination('Salon', Icons.business_outlined, Icons.business),
      _Destination('Profil', Icons.person_outline, Icons.person),
    ];
  }

  List<Widget> get _screens {
    if (widget.session.role == AppRole.customer) {
      return [
        CustomerSalonsScreen(session: widget.session),
        CustomerMapScreen(session: widget.session),
        CustomerBookingsScreen(session: widget.session),
        CustomerProfileScreen(session: widget.session),
      ];
    }

    return [
      SalonTodayScreen(session: widget.session),
      SalonRequestsScreen(session: widget.session),
      SalonCalendarScreen(session: widget.session),
      SalonProfileScreen(session: widget.session),
      OwnerProfileScreen(session: widget.session),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final screens = _screens;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.content_cut, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Makaze',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.session.role == AppRole.customer
                      ? 'Korisnicki dio'
                      : 'Salon dio',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Obavjestenja',
            onPressed: () => _showNotifications(context),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Odjava',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey('${widget.session.role.name}-$_selectedIndex'),
          child: screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final api = AppApiClient(widget.session);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: FutureBuilder<List<NotificationInfo>>(
              future: api.listNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return WarningBox(
                    text: 'Ne mogu ucitati obavjestenja: ${snapshot.error}',
                  );
                }
                final notifications = snapshot.data ?? [];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Obavjestenja',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: notifications.isEmpty
                              ? null
                              : () async {
                                  await api.markAllNotificationsRead();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          child: const Text('Procitaj sve'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (notifications.isEmpty)
                      const EmptyStateCard(
                        icon: Icons.notifications_none_outlined,
                        title: 'Nema obavjestenja',
                        message: 'Nove poruke o terminima ce biti ovdje.',
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = notifications[index];
                            return NotificationItem(
                              title: item.title,
                              message: item.message,
                              icon: item.icon,
                              color: item.color,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class CustomerSalonsScreen extends StatefulWidget {
  const CustomerSalonsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<CustomerSalonsScreen> createState() => _CustomerSalonsScreenState();
}

class _CustomerSalonsScreenState extends State<CustomerSalonsScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<SalonInfo>> _salonsFuture = _api.listSalons();
  final _searchController = TextEditingController();
  final Set<String> _favoriteSalonIds = {};
  String _filter = 'Svi';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _api.listFavoriteSalonIds();
      if (mounted) {
        setState(() {
          _favoriteSalonIds
            ..clear()
            ..addAll(favorites);
        });
      }
    } catch (_) {
      // The salon list still works if favorites cannot load.
    }
  }

  void _reload() {
    _loadFavorites();
    setState(() => _salonsFuture = _api.listSalons());
  }

  Future<void> _toggleFavorite(SalonInfo salon) async {
    final wasFavorite = _favoriteSalonIds.contains(salon.id);
    setState(() {
      if (wasFavorite) {
        _favoriteSalonIds.remove(salon.id);
      } else {
        _favoriteSalonIds.add(salon.id);
      }
    });
    try {
      if (wasFavorite) {
        await _api.removeFavorite(salon.id);
      } else {
        await _api.addFavorite(salon.id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteSalonIds.add(salon.id);
        } else {
          _favoriteSalonIds.remove(salon.id);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SalonInfo> _filterSalons(List<SalonInfo> salons) {
    final query = _searchController.text.trim().toLowerCase();
    var result = salons.where((salon) {
      if (query.isEmpty) return true;
      return salon.name.toLowerCase().contains(query) ||
          salon.city.toLowerCase().contains(query) ||
          salon.address.toLowerCase().contains(query) ||
          salon.services.any(
            (service) => service.toLowerCase().contains(query),
          );
    }).toList();

    switch (_filter) {
      case 'Ocjena 4+':
        result = result.where((salon) => salon.rating >= 4).toList();
      case 'Najjeftiniji':
        result.sort((a, b) {
          final aPrice = a.minPrice ?? double.maxFinite;
          final bPrice = b.minPrice ?? double.maxFinite;
          return aPrice.compareTo(bPrice);
        });
      case 'Kapacitet':
        result.sort((a, b) => b.capacity.compareTo(a.capacity));
      case 'Favoriti':
        result = result
            .where((salon) => _favoriteSalonIds.contains(salon.id))
            .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Pretrazi salon, grad ili uslugu',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Ocisti',
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SelectableFilterRow(
          labels: const [
            'Svi',
            'Ocjena 4+',
            'Najjeftiniji',
            'Kapacitet',
            'Favoriti',
          ],
          selected: _filter,
          onSelected: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Saloni',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<SalonInfo>>(
          future: _salonsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return WarningBox(
                text: 'Ne mogu ucitati salone: ${snapshot.error}',
              );
            }
            final salons = _filterSalons(snapshot.data ?? []);
            if (salons.isEmpty) {
              return const EmptyStateCard(
                icon: Icons.storefront_outlined,
                title: 'Nema rezultata',
                message: 'Promijeni pretragu ili filter.',
              );
            }
            return Column(
              children: [
                for (final salon in salons) ...[
                  SalonCard(
                    salon: salon,
                    isFavorite: _favoriteSalonIds.contains(salon.id),
                    onToggleFavorite: () => _toggleFavorite(salon),
                    onViewServices: () => _showServicesSheet(context, salon),
                    onViewSlots: () => _showReservationSheet(context, salon),
                    onViewImages: () => _showImagesSheet(context, salon),
                    onReserve: salon.id.isEmpty
                        ? null
                        : () => _showReservationSheet(context, salon),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _showImagesSheet(BuildContext context, SalonInfo salon) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _SalonImagesSheet(api: _api, salon: salon),
    );
  }

  void _showServicesSheet(BuildContext context, SalonInfo salon) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: FutureBuilder<List<ApiServiceInfo>>(
              future: _api.listServices(salon.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return WarningBox(
                    text: 'Ne mogu ucitati usluge: ${snapshot.error}',
                  );
                }
                final services = snapshot.data ?? [];
                if (services.isEmpty) {
                  return const EmptyStateCard(
                    icon: Icons.content_cut,
                    title: 'Nema usluga',
                    message: 'Salon jos nije dodao aktivne usluge.',
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      salon.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final service in services) ...[
                      ListTile(
                        leading: const Icon(
                          Icons.content_cut,
                          color: AppColors.primary,
                        ),
                        title: Text(service.name),
                        subtitle: Text(
                          '${service.durationMinutes} min - ${service.priceLabel}',
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showReservationSheet(BuildContext context, SalonInfo salon) {
    final date = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: FutureBuilder<List<ApiServiceInfo>>(
                future: _api.listServices(salon.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return WarningBox(
                      text: 'Ne mogu ucitati usluge: ${snapshot.error}',
                    );
                  }
                  final services = snapshot.data ?? [];
                  if (services.isEmpty) {
                    return const EmptyStateCard(
                      icon: Icons.content_cut,
                      title: 'Salon nema usluge',
                      message: 'Frizer prvo treba dodati usluge u salonu.',
                    );
                  }
                  return ListView(
                    children: [
                      Text(
                        salon.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Izaberi uslugu i termin za sutra.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final service in services) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${service.durationMinutes} min - ${service.priceLabel}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<List<ApiSlotInfo>>(
                                  future: _api.availableSlots(
                                    salonId: salon.id,
                                    serviceId: service.id,
                                    date: date,
                                  ),
                                  builder: (context, slotSnapshot) {
                                    if (slotSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator();
                                    }
                                    if (slotSnapshot.hasError) {
                                      return Text(
                                        'Slotovi nisu dostupni.',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      );
                                    }
                                    final slots = (slotSnapshot.data ?? [])
                                        .where((slot) => slot.available > 0)
                                        .take(8)
                                        .toList();
                                    if (slots.isEmpty) {
                                      return const Text(
                                        'Nema slobodnih termina za ovu uslugu.',
                                      );
                                    }
                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final slot in slots)
                                          ActionChip(
                                            avatar: const Icon(
                                              Icons.schedule,
                                              size: 16,
                                            ),
                                            label: Text(slot.startLabel),
                                            onPressed: () async {
                                              try {
                                                await _api.createReservation(
                                                  salonId: salon.id,
                                                  serviceId: service.id,
                                                  startTime: slot.startTime,
                                                );
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Zahtjev za termin je poslan.',
                                                    ),
                                                  ),
                                                );
                                              } catch (error) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text('$error'),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomerMapScreen extends StatefulWidget {
  const CustomerMapScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class _CustomerMapScreenState extends State<CustomerMapScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<SalonInfo>> _salonsFuture = _api.listSalons();
  final _mapSearchController = TextEditingController();
  LatLng? _mapCenter;
  String? _focusedSalonId;

  void _reload() {
    setState(() => _salonsFuture = _api.listSalons());
  }

  @override
  void dispose() {
    _mapSearchController.dispose();
    super.dispose();
  }

  Future<void> _goToPlace() async {
    try {
      final point = await _api.geocodePlace(_mapSearchController.text);
      if (point == null) {
        _showMessage('Grad nije pronadjen.');
        return;
      }
      setState(() {
        _mapCenter = point;
        _focusedSalonId = null;
      });
    } catch (error) {
      _showMessage('$error');
    }
  }

  void _focusSalon(SalonInfo salon) {
    setState(() {
      _mapCenter = LatLng(salon.latitude, salon.longitude);
      _focusedSalonId = salon.id;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        SectionHeader(
          title: 'Mapa salona',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mapSearchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _goToPlace(),
          decoration: InputDecoration(
            hintText: 'Unesi grad ili adresu',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Idi na lokaciju',
              onPressed: _goToPlace,
              icon: const Icon(Icons.my_location_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<SalonInfo>>(
          future: _salonsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return WarningBox(
                text: 'Ne mogu ucitati mapu: ${snapshot.error}',
              );
            }
            final salons = snapshot.data ?? [];
            if (salons.isEmpty) {
              return const EmptyStateCard(
                icon: Icons.map_outlined,
                title: 'Nema salona na mapi',
                message: 'Kada salon postoji u bazi, marker ce se pojaviti.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MapPanel(salons: salons, center: _mapCenter),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Saloni oko tebe'),
                const SizedBox(height: 10),
                for (final salon in salons) ...[
                  CompactSalonTile(
                    salon: salon,
                    selected: salon.id == _focusedSalonId,
                    onTap: () => _focusSalon(salon),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<BookingInfo>> _bookingsFuture = _api.myReservations();
  String _bookingFilter = 'Aktivni';
  final Set<String> _cancelling = {};

  void _reload() {
    setState(() {
      _bookingsFuture = _api.myReservations();
      _cancelling.clear();
    });
  }

  Future<void> _cancel(String id) async {
    if (_cancelling.contains(id)) return;
    setState(() => _cancelling.add(id));
    try {
      await _api.cancelReservation(id);
      _reload();
    } catch (error) {
      setState(() => _cancelling.remove(id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  List<BookingInfo> _filterBookings(List<BookingInfo> bookings) {
    return bookings.where((booking) {
      return switch (_bookingFilter) {
        'Aktivni' =>
          booking.status == 'Pending' || booking.status == 'Accepted',
        'Cekaju' => booking.status == 'Pending',
        'Prosli' => booking.status == 'Completed' || booking.status == 'NoShow',
        'Otkazani' =>
          booking.status == 'Rejected' ||
              booking.status == 'CancelledByUser' ||
              booking.status == 'CancelledByBarber' ||
              booking.status == 'CancelledLate' ||
              booking.status == 'Expired',
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        SectionHeader(
          title: 'Moji termini',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        SelectableFilterRow(
          labels: const ['Aktivni', 'Cekaju', 'Prosli', 'Otkazani'],
          selected: _bookingFilter,
          onSelected: (value) => setState(() => _bookingFilter = value),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<BookingInfo>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return WarningBox(
                text: 'Ne mogu ucitati termine: ${snapshot.error}',
              );
            }
            final bookings = _filterBookings(snapshot.data ?? []);
            if (bookings.isEmpty) {
              return EmptyStateCard(
                icon: Icons.event_note_outlined,
                title: 'Nema termina',
                message: 'Nema termina za filter $_bookingFilter.',
              );
            }
            return Column(
              children: [
                for (final booking in bookings) ...[
                  BookingCard(
                    booking: booking,
                    onCancel: booking.canCancel && !_cancelling.contains(booking.id)
                        ? () => _cancel(booking.id)
                        : null,
                    onReview: booking.canReview
                        ? () => _showReviewSheet(context, booking)
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _showReviewSheet(BuildContext context, BookingInfo booking) {
    var rating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      booking.salon,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var value = 1; value <= 5; value++)
                          ChoiceChip(
                            label: Text('$value'),
                            selected: rating == value,
                            avatar: const Icon(Icons.star, size: 16),
                            onSelected: (_) =>
                                setSheetState(() => rating = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Komentar',
                        prefixIcon: Icon(Icons.rate_review_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          await _api.createReview(
                            reservationId: booking.id,
                            rating: rating,
                            comment: commentController.text.trim(),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ocjena je sacuvana.'),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$error')));
                        }
                      },
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Ocijeni salon'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(commentController.dispose);
  }
}

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late String? _profileImageUrl = widget.session.profileImageUrl;
  bool _isUploading = false;

  Future<void> _uploadProfileImage() async {
    final file = await pickImageFile();
    if (file == null) return;
    setState(() => _isUploading = true);
    try {
      final url = await _api.uploadProfileImage(file);
      setState(() => _profileImageUrl = url);
      _showMessage('Profilna slika je sacuvana.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        ProfileHeader(
          name: widget.session.fullName,
          subtitle: widget.session.email,
          badge: widget.session.role == AppRole.customer ? 'Customer' : 'Salon',
          profileImageUrl: _profileImageUrl,
          onUploadImage: _isUploading ? null : _uploadProfileImage,
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Licni podaci'),
        const SizedBox(height: 10),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.badge_outlined,
              title: 'Ime i prezime',
              value: widget.session.fullName,
            ),
            SettingsRow(
              icon: Icons.mail_outline,
              title: 'Email',
              value: widget.session.email,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Podesavanja'),
        const SizedBox(height: 10),
        const SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.lock_outline,
              title: 'Lozinka',
              value: 'Promijeni',
            ),
          ],
        ),
      ],
    );
  }
}

class SalonTodayScreen extends StatefulWidget {
  const SalonTodayScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<SalonTodayScreen> createState() => _SalonTodayScreenState();
}

class _SalonTodayScreenState extends State<SalonTodayScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<RequestInfo>> _reservationsFuture = _api.salonReservations();

  void _reload() {
    setState(() => _reservationsFuture = _api.salonReservations());
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        SectionHeader(
          title: 'Danas',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        if (widget.session.salonId == null)
          const EmptyStateCard(
            icon: Icons.storefront_outlined,
            title: 'Salon nije povezan',
            message: 'Danas se puni kada se ulogujes kao vlasnik salona.',
          )
        else
          FutureBuilder<List<RequestInfo>>(
            future: _reservationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return WarningBox(
                  text: 'Ne mogu ucitati danasnje termine: ${snapshot.error}',
                );
              }
              final reservations = snapshot.data ?? [];
              final today = DateTime.now();
              final todayReservations =
                  reservations.where((reservation) {
                    final start = reservation.start?.toLocal();
                    return start != null && sameCalendarDay(start, today);
                  }).toList()..sort(
                    (a, b) => (a.start ?? DateTime(1900)).compareTo(
                      b.start ?? DateTime(1900),
                    ),
                  );
              final pendingCount = reservations
                  .where((reservation) => reservation.status == 'Pending')
                  .length;
              final acceptedToday = todayReservations
                  .where((reservation) => reservation.status == 'Accepted')
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MetricsGrid(
                    metrics: [
                      MetricData(
                        'Danas',
                        '${todayReservations.length}',
                        Icons.event_available_outlined,
                        AppColors.primary,
                      ),
                      MetricData(
                        'Zahtjevi',
                        '$pendingCount',
                        Icons.inbox_outlined,
                        AppColors.warning,
                      ),
                      MetricData(
                        'Prihvaceno',
                        '$acceptedToday',
                        Icons.check_circle_outline,
                        AppColors.success,
                      ),
                      MetricData(
                        'Ukupno',
                        '${reservations.length}',
                        Icons.groups_outlined,
                        AppColors.ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Raspored'),
                  const SizedBox(height: 10),
                  if (todayReservations.isEmpty)
                    const EmptyStateCard(
                      icon: Icons.event_available_outlined,
                      title: 'Nema termina danas',
                      message:
                          'Novi zahtjevi i prihvaceni termini ce se pojaviti ovdje.',
                    )
                  else
                    for (final reservation in todayReservations) ...[
                      SalonReservationCard(reservation: reservation),
                      const SizedBox(height: 10),
                    ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class SalonRequestsScreen extends StatefulWidget {
  const SalonRequestsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<SalonRequestsScreen> createState() => _SalonRequestsScreenState();
}

class _SalonRequestsScreenState extends State<SalonRequestsScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<RequestInfo>> _requestsFuture = _api.salonRequests();
  final Set<String> _processing = {};

  void _reload() {
    setState(() {
      _requestsFuture = _api.salonRequests();
      _processing.clear();
    });
  }

  Future<void> _act(String id, Future<void> Function() action) async {
    if (_processing.contains(id)) return;
    setState(() => _processing.add(id));
    try {
      await action();
      _reload();
    } catch (error) {
      setState(() => _processing.remove(id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        SectionHeader(
          title: 'Zahtjevi za termin',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        if (widget.session.salonId == null)
          const EmptyStateCard(
            icon: Icons.storefront_outlined,
            title: 'Salon nije povezan',
            message: 'Registruj salon ili se uloguj kao vlasnik salona.',
          )
        else
          FutureBuilder<List<RequestInfo>>(
            future: _requestsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return WarningBox(
                  text: 'Ne mogu ucitati zahtjeve: ${snapshot.error}',
                );
              }
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return const EmptyStateCard(
                  icon: Icons.inbox_outlined,
                  title: 'Nema novih zahtjeva',
                  message: 'Pending rezervacije ce se pojaviti ovdje.',
                );
              }
              return Column(
                children: [
                  for (final request in requests) ...[
                    RequestCard(
                      request: request,
                      onAccept: _processing.contains(request.id)
                          ? null
                          : () => _act(request.id, () => _api.acceptReservation(request.id)),
                      onReject: _processing.contains(request.id)
                          ? null
                          : () => _act(request.id, () => _api.rejectReservation(request.id)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class SalonCalendarScreen extends StatefulWidget {
  const SalonCalendarScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<SalonCalendarScreen> createState() => _SalonCalendarScreenState();
}

class _SalonCalendarScreenState extends State<SalonCalendarScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<RequestInfo>> _reservationsFuture = _api.salonReservations();
  String _calendarView = 'Dan';
  DateTime _selectedDate = DateTime.now();

  void _reload() {
    setState(() => _reservationsFuture = _api.salonReservations());
  }

  Future<void> _complete(RequestInfo reservation) async {
    try {
      await _api.completeReservation(reservation.id);
      _reload();
    } catch (error) {
      _showMessage('$error');
    }
  }

  Future<void> _noShow(RequestInfo reservation) async {
    try {
      await _api.noShowReservation(reservation.id);
      _reload();
    } catch (error) {
      _showMessage('$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<RequestInfo> _visibleReservations(List<RequestInfo> reservations) {
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return reservations.where((reservation) {
      final start = reservation.start;
      if (start == null) return false;
      final local = start.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      return switch (_calendarView) {
        'Dan' => day == selected,
        'Sedmica' =>
          !day.isBefore(selected) &&
              day.isBefore(selected.add(const Duration(days: 7))),
        'Mjesec' => day.year == selected.year && day.month == selected.month,
        _ => true,
      };
    }).toList()..sort(
      (a, b) =>
          (a.start ?? DateTime(1900)).compareTo(b.start ?? DateTime(1900)),
    );
  }

  String get _periodTitle {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    return switch (_calendarView) {
      'Dan' => '$day.$month.',
      'Sedmica' => 'Od $day.$month. narednih 7 dana',
      'Mjesec' => '${_selectedDate.month}.${_selectedDate.year}.',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        SectionHeader(
          title: 'Kalendar',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        SelectableFilterRow(
          labels: const ['Dan', 'Sedmica', 'Mjesec'],
          selected: _calendarView,
          onSelected: (value) => setState(() => _calendarView = value),
        ),
        const SizedBox(height: 16),
        CalendarDayStrip(
          selectedDate: _selectedDate,
          onSelected: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: 18),
        SectionHeader(title: _periodTitle),
        const SizedBox(height: 10),
        if (widget.session.salonId == null)
          const EmptyStateCard(
            icon: Icons.calendar_month_outlined,
            title: 'Salon nije povezan',
            message: 'Kalendar se puni kada se ulogujes kao vlasnik salona.',
          )
        else
          FutureBuilder<List<RequestInfo>>(
            future: _reservationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return WarningBox(
                  text: 'Ne mogu ucitati kalendar: ${snapshot.error}',
                );
              }
              final reservations = _visibleReservations(snapshot.data ?? []);
              if (reservations.isEmpty) {
                return EmptyStateCard(
                  icon: Icons.event_busy_outlined,
                  title: 'Nema rezervacija',
                  message: 'Nema termina za odabrani period.',
                );
              }
              return Column(
                children: [
                  for (final reservation in reservations) ...[
                    SalonReservationCard(
                      reservation: reservation,
                      onComplete: reservation.status == 'Accepted'
                          ? () => _complete(reservation)
                          : null,
                      onNoShow: reservation.status == 'Accepted'
                          ? () => _noShow(reservation)
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class SalonProfileScreen extends StatefulWidget {
  const SalonProfileScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<SalonProfileScreen> createState() => _SalonProfileScreenState();
}

class _SalonProfileScreenState extends State<SalonProfileScreen> {
  int _selectedSection = 0;

  static const _sections = [
    'Podaci',
    'Slike',
    'Usluge',
    'Radno vrijeme',
    'Kapacitet',
    'Lokacija',
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        SectionHeader(title: widget.session.salonName ?? 'Salon'),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _sections.length; i++) ...[
                ChoiceChip(
                  label: Text(_sections[i]),
                  selected: _selectedSection == i,
                  onSelected: (_) => setState(() => _selectedSection = i),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SalonSectionBody(section: _selectedSection, session: widget.session),
      ],
    );
  }
}

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late String? _profileImageUrl = widget.session.profileImageUrl;
  bool _isUploading = false;

  Future<void> _uploadProfileImage() async {
    final file = await pickImageFile();
    if (file == null) return;
    setState(() => _isUploading = true);
    try {
      final url = await _api.uploadProfileImage(file);
      setState(() => _profileImageUrl = url);
      _showMessage('Profilna slika je sacuvana.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        ProfileHeader(
          name: widget.session.fullName,
          subtitle: widget.session.salonName ?? widget.session.email,
          badge: widget.session.salonId == null
              ? 'Salon nije kreiran'
              : 'Salon aktivan',
          profileImageUrl: _profileImageUrl,
          onUploadImage: _isUploading ? null : _uploadProfileImage,
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Nalog'),
        const SizedBox(height: 10),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.badge_outlined,
              title: 'Ime i prezime',
              value: widget.session.fullName,
            ),
            SettingsRow(
              icon: Icons.mail_outline,
              title: 'Email',
              value: widget.session.email,
            ),
            const SettingsRow(icon: Icons.logout, title: 'Odjava', value: ''),
          ],
        ),
      ],
    );
  }
}

class _SalonSectionBody extends StatelessWidget {
  const _SalonSectionBody({required this.section, required this.session});

  final int section;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      0 => SalonBasicsPanel(session: session),
      1 => SalonImagesPanel(session: session),
      2 => ApiServicesPanel(session: session),
      3 => WorkingHoursPanel(session: session),
      4 => CapacityPanel(session: session),
      _ => LocationPanel(session: session),
    };
  }
}

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class FilterRow extends StatelessWidget {
  const FilterRow({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            FilterChip(
              label: Text(labels[i]),
              selected: i == 0,
              onSelected: (_) {},
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class SelectableFilterRow extends StatelessWidget {
  const SelectableFilterRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final label in labels) ...[
            FilterChip(
              label: Text(label),
              selected: selected == label,
              onSelected: (_) => onSelected(label),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class QuickBookingStrip extends StatelessWidget {
  const QuickBookingStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 166,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sampleSalons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final salon = sampleSalons[index];
          return SizedBox(
            width: 245,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SalonAvatar(color: salon.color, icon: salon.icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            salon.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      salon.nextSlot,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Izaberi salon iz liste za rezervaciju.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.event_available_outlined,
                        size: 18,
                      ),
                      label: const Text('Rezervisi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SalonImagesSheet extends StatefulWidget {
  const _SalonImagesSheet({required this.api, required this.salon});
  final AppApiClient api;
  final SalonInfo salon;

  @override
  State<_SalonImagesSheet> createState() => _SalonImagesSheetState();
}

class _SalonImagesSheetState extends State<_SalonImagesSheet> {
  late Future<List<SalonImageInfo>> _imagesFuture;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _imagesFuture = widget.api.listSalonImages(widget.salon.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.salon.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<SalonImageInfo>>(
                future: _imagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  final images = snapshot.data ?? [];
                  if (images.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nema slika za ovaj salon.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _current = i),
                        itemBuilder: (_, i) => Image.network(
                          images[i].imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, e, s) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
                          ),
                          loadingBuilder: (_, child, progress) => progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                      ),
                      if (images.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _current == i ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _current == i ? Colors.white : Colors.white38,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SalonCard extends StatelessWidget {
  const SalonCard({
    super.key,
    required this.salon,
    this.onReserve,
    this.onViewServices,
    this.onViewSlots,
    this.onViewImages,
    this.onToggleFavorite,
    this.isFavorite = false,
  });

  final SalonInfo salon;
  final VoidCallback? onReserve;
  final VoidCallback? onViewServices;
  final VoidCallback? onViewSlots;
  final VoidCallback? onViewImages;
  final VoidCallback? onToggleFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (salon.mainImageUrl != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(
                salon.mainImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, s) => Container(
                  color: salon.color.withAlpha(30),
                  child: Center(child: Icon(salon.icon, color: salon.color, size: 40)),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: salon.color.withAlpha(20),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),
          Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SalonAvatar(color: salon.color, icon: salon.icon, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${salon.city} - ${salon.distance}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                RatingPill(rating: salon.rating),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.schedule_outlined, size: 16),
                  label: const Text('Pogledaj termine'),
                  onPressed: onViewSlots,
                ),
                ActionChip(
                  avatar: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Usluge'),
                  onPressed: onViewServices,
                ),
                if (salon.mainImageUrl != null)
                  ActionChip(
                    avatar: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Slike'),
                    onPressed: onViewImages,
                  ),
                InfoPill(
                  icon: Icons.groups_outlined,
                  label: '${salon.capacity} u terminu',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in salon.services)
                  Chip(
                    label: Text(service),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                    ),
                    label: Text(isFavorite ? 'Ukloni' : 'Favorit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReserve,
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Rezervisi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);
  }
}

class CompactSalonTile extends StatelessWidget {
  const CompactSalonTile({
    super.key,
    required this.salon,
    this.onTap,
    this.selected = false,
  });

  final SalonInfo salon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: AppColors.soft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: SalonAvatar(color: salon.color, icon: salon.icon),
        title: Text(
          salon.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${salon.city} - ${salon.address}'),
        trailing: selected
            ? const Icon(Icons.my_location, color: AppColors.primary)
            : RatingPill(rating: salon.rating),
      ),
    );
  }
}

class MapPanel extends StatefulWidget {
  const MapPanel({
    super.key,
    this.salons = sampleSalons,
    this.center,
    this.selectedPoint,
    this.onLocationSelected,
  });

  final List<SalonInfo> salons;
  final LatLng? center;
  final LatLng? selectedPoint;
  final ValueChanged<LatLng>? onLocationSelected;

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(covariant MapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final center = widget.center ?? widget.selectedPoint;
    final oldCenter = oldWidget.center ?? oldWidget.selectedPoint;
    if (center != null &&
        (oldCenter == null ||
            center.latitude != oldCenter.latitude ||
            center.longitude != oldCenter.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(center, 13.5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstSalon = widget.salons.isEmpty ? null : widget.salons.first;
    final center =
        widget.center ??
        widget.selectedPoint ??
        (firstSalon == null
            ? LatLng(44.7722, 17.1910)
            : LatLng(firstSalon.latitude, firstSalon.longitude));
    final bottomText = firstSalon == null
        ? 'Klikni na mapu da oznacis lokaciju salona'
        : '${firstSalon.city} - ${widget.salons.length} salona na mapi';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 360,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13.2,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.flingAnimation |
                        InteractiveFlag.pinchMove |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.scrollWheelZoom,
                  ),
                  onTap: widget.onLocationSelected == null
                      ? null
                      : (_, point) => widget.onLocationSelected!(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.makaze.app',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final salon in widget.salons)
                        Marker(
                          point: LatLng(salon.latitude, salon.longitude),
                          width: 136,
                          height: 54,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _showSalonOnMap(context, salon),
                            child: MapMarker(
                              label: salon.shortName,
                              rating: salon.rating.toStringAsFixed(1),
                              color: salon.color,
                            ),
                          ),
                        ),
                      if (widget.selectedPoint != null)
                        Marker(
                          point: widget.selectedPoint!,
                          width: 52,
                          height: 52,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.danger,
                            size: 42,
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bottomText,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSalonOnMap(BuildContext context, SalonInfo salon) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SalonAvatar(color: salon.color, icon: salon.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        salon.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    RatingPill(rating: salon.rating),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  salon.distance,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Pogledaj salon'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MapMarker extends StatelessWidget {
  const MapMarker({
    super.key,
    required this.label,
    required this.rating,
    required this.color,
  });

  final String label;
  final String rating;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(74),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.content_cut, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              '$label  $rating',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.onCancel,
    this.onReview,
  });

  final BookingInfo booking;
  final VoidCallback? onCancel;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final colors = statusColors(booking.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.salon,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusPill(
                  label: booking.status,
                  foreground: colors.$1,
                  background: colors.$2,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              booking.time,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              booking.service,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (booking.canCancel || onReview != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (booking.canCancel)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Otkazi'),
                      ),
                    ),
                  if (booking.canCancel && onReview != null)
                    const SizedBox(width: 10),
                  if (onReview != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onReview,
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Ocijeni'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({super.key, required this.metrics});

  final List<MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 650 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth > 650 ? 1.25 : 1.15,
          children: [for (final metric in metrics) MetricCard(metric: metric)],
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.metric});

  final MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(metric.icon, color: metric.color),
            Text(
              metric.value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(metric.label, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class ScheduleSlotTile extends StatelessWidget {
  const ScheduleSlotTile({super.key, required this.slot});

  final ScheduleSlot slot;

  @override
  Widget build(BuildContext context) {
    final colors = statusColors(slot.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                slot.time,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
            Container(width: 1, height: 48, color: AppColors.border),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            StatusPill(
              label: slot.status,
              foreground: colors.$1,
              background: colors.$2,
            ),
          ],
        ),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    this.onAccept,
    this.onReject,
  });

  final RequestInfo request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(31),
                  child: Text(
                    request.customer.substring(0, 1),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.customer,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        request.time,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: 'Pending',
                  foreground: AppColors.warning,
                  background: AppColors.warning.withAlpha(26),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoPill(icon: Icons.content_cut, label: request.service),
            const SizedBox(height: 10),
            WarningBox(text: request.warning),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Odbij'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Prihvati'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SalonReservationCard extends StatelessWidget {
  const SalonReservationCard({
    super.key,
    required this.reservation,
    this.onComplete,
    this.onNoShow,
  });

  final RequestInfo reservation;
  final VoidCallback? onComplete;
  final VoidCallback? onNoShow;

  @override
  Widget build(BuildContext context) {
    final colors = statusColors(reservation.status);
    final canClose = onComplete != null || onNoShow != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    reservation.time.isEmpty ? '--:--' : reservation.time,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Container(width: 1, height: 48, color: AppColors.border),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.customer,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reservation.service,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: reservation.status,
                  foreground: colors.$1,
                  background: colors.$2,
                ),
              ],
            ),
            if (canClose) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onNoShow,
                      icon: const Icon(Icons.person_off_outlined, size: 18),
                      label: const Text('NoShow'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Zavrseno'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context) {
    const days = [
      ('Pon', '18'),
      ('Uto', '19'),
      ('Sri', '20'),
      ('Cet', '21'),
      ('Pet', '22'),
      ('Sub', '23'),
      ('Ned', '24'),
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == 4;
          return SizedBox(
            width: 66,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      days[index].$1,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[index].$2,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CalendarDayStrip extends StatelessWidget {
  const CalendarDayStrip({
    super.key,
    required this.selectedDate,
    required this.onSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (index) {
      final date = DateTime(today.year, today.month, today.day + index);
      return date;
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final date in days) ...[
            _CalendarDayButton(
              date: date,
              selected: sameCalendarDay(date, selectedDate),
              onTap: () => onSelected(date),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = const [
      'Pon',
      'Uto',
      'Sri',
      'Cet',
      'Pet',
      'Sub',
      'Ned',
    ][date.weekday - 1];
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: SizedBox(
          width: 66,
          height: 78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                date.day.toString(),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CapacitySlotTile extends StatelessWidget {
  const CapacitySlotTile({super.key, required this.slot});

  final CapacitySlot slot;

  @override
  Widget build(BuildContext context) {
    final ratio = slot.booked / slot.capacity;
    final full = slot.booked >= slot.capacity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                slot.time,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    full ? 'Popunjeno' : 'Slobodno',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: ratio,
                      backgroundColor: AppColors.border,
                      color: full ? AppColors.danger : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${slot.booked}/${slot.capacity}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class SalonImagesPanel extends StatelessWidget {
  const SalonImagesPanel({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    if (session.salonId == null) {
      return const EmptyStateCard(
        icon: Icons.storefront_outlined,
        title: 'Salon nije povezan',
        message: 'Slike mozes dodati kada se ulogujes kao vlasnik salona.',
      );
    }
    return ApiSalonImagesPanel(session: session);
  }
}

class SalonBasicsPanel extends StatefulWidget {
  const SalonBasicsPanel({super.key, required this.session});

  final AuthSession session;

  @override
  State<SalonBasicsPanel> createState() => _SalonBasicsPanelState();
}

class _SalonBasicsPanelState extends State<SalonBasicsPanel> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<SalonDetails> _detailsFuture = _load();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _capacityController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _isReady = false;
  bool _isSaving = false;

  Future<SalonDetails> _load() {
    final salonId = widget.session.salonId;
    if (salonId == null || salonId.isEmpty) {
      return Future.error('Salon nije povezan sa nalogom.');
    }
    return _api.getSalonDetails(salonId);
  }

  void _fill(SalonInfo salon) {
    if (_isReady) return;
    _nameController.text = salon.name;
    _descriptionController.text = salon.description ?? '';
    _addressController.text = salon.address;
    _cityController.text = salon.city;
    _countryController.text = salon.country;
    _phoneController.text = salon.phoneNumber ?? '';
    _capacityController.text = salon.capacity.toString();
    _latitudeController.text = salon.latitude.toStringAsFixed(7);
    _longitudeController.text = salon.longitude.toStringAsFixed(7);
    _isReady = true;
  }

  Future<void> _save() async {
    final salonId = widget.session.salonId;
    if (salonId == null || salonId.isEmpty) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 1;
    final latitude = double.tryParse(
      _latitudeController.text.trim().replaceAll(',', '.'),
    );
    final longitude = double.tryParse(
      _longitudeController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty || address.isEmpty) {
      _showMessage('Naziv i adresa salona su obavezni.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _api.updateSalon(
        salonId: salonId,
        name: name,
        description: _descriptionController.text.trim(),
        address: address,
        city: _cityController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? 'BiH'
            : _countryController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        capacity: capacity < 1 ? 1 : capacity,
        latitude: latitude,
        longitude: longitude,
      );
      setState(() {
        _isReady = false;
        _detailsFuture = _load();
      });
      _showMessage('Salon je sacuvan.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _capacityController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.salonId == null) {
      return const EmptyStateCard(
        icon: Icons.storefront_outlined,
        title: 'Salon nije povezan',
        message: 'Uloguj se kao vlasnik salona da bi uredio podatke.',
      );
    }

    return FutureBuilder<SalonDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return WarningBox(text: 'Ne mogu ucitati salon: ${snapshot.error}');
        }

        _fill(snapshot.data!.salon);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Naziv salona',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Opis',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresa',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Grad'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(labelText: 'Drzava'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kapacitet',
                          prefixIcon: Icon(Icons.groups_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Lat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Lng'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Sacuvaj salon'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ApiSalonImagesPanel extends StatefulWidget {
  const ApiSalonImagesPanel({super.key, required this.session});

  final AuthSession session;

  @override
  State<ApiSalonImagesPanel> createState() => _ApiSalonImagesPanelState();
}

class _ApiSalonImagesPanelState extends State<ApiSalonImagesPanel> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<SalonImageInfo>> _imagesFuture = _loadImages();

  bool _isMain = false;
  bool _isSaving = false;

  Future<List<SalonImageInfo>> _loadImages() {
    return _api.listSalonImages(widget.session.salonId!);
  }

  void _reload() {
    setState(() => _imagesFuture = _loadImages());
  }

  Future<void> _uploadImage() async {
    final file = await pickImageFile();
    if (file == null) return;
    setState(() => _isSaving = true);
    try {
      await _api.uploadSalonImage(
        salonId: widget.session.salonId!,
        file: file,
        isMain: _isMain,
      );
      _isMain = false;
      _reload();
      _showMessage('Slika je dodana.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteImage(SalonImageInfo image) async {
    try {
      await _api.deleteSalonImage(
        salonId: widget.session.salonId!,
        imageId: image.id,
      );
      _reload();
    } catch (error) {
      _showMessage('$error');
    }
  }

  Future<void> _setMain(SalonImageInfo image) async {
    try {
      await _api.setMainSalonImage(
        salonId: widget.session.salonId!,
        imageId: image.id,
      );
      _reload();
    } catch (error) {
      _showMessage('$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Slike salona',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<SalonImageInfo>>(
          future: _imagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return WarningBox(
                text: 'Ne mogu ucitati slike: ${snapshot.error}',
              );
            }
            final images = snapshot.data ?? [];
            if (images.isEmpty) {
              return const EmptyStateCard(
                icon: Icons.image_outlined,
                title: 'Nema slika',
                message: 'Uploaduj prvu sliku salona za prikaz korisnicima.',
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 520 ? 3 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    for (final image in images)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              image.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: AppColors.soft,
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: StatusPill(
                                label: image.isMain ? 'Glavna' : 'Slika',
                                foreground: image.isMain
                                    ? AppColors.warning
                                    : AppColors.primary,
                                background: Colors.white,
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Row(
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: 'Glavna',
                                    onPressed: image.isMain
                                        ? null
                                        : () => _setMain(image),
                                    icon: const Icon(Icons.star_outline),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton.filledTonal(
                                    tooltip: 'Obrisi',
                                    onPressed: () => _deleteImage(image),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  value: _isMain,
                  onChanged: (value) => setState(() => _isMain = value),
                  title: const Text('Postavi kao glavnu sliku'),
                ),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _uploadImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Upload slike'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ApiServicesPanel extends StatefulWidget {
  const ApiServicesPanel({super.key, required this.session});

  final AuthSession session;

  @override
  State<ApiServicesPanel> createState() => _ApiServicesPanelState();
}

class _ApiServicesPanelState extends State<ApiServicesPanel> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<List<ApiServiceInfo>> _servicesFuture = _loadServices();

  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _priceController = TextEditingController(text: '15');

  bool _isSaving = false;

  Future<List<ApiServiceInfo>> _loadServices() {
    final salonId = widget.session.salonId;
    if (salonId == null || salonId.isEmpty) {
      return Future.value(const []);
    }
    return _api.listServices(salonId);
  }

  void _reload() {
    setState(() => _servicesFuture = _loadServices());
  }

  Future<void> _addService() async {
    final salonId = widget.session.salonId;
    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim()) ?? 0;
    final priceText = _priceController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(priceText) ?? 0;

    if (salonId == null || salonId.isEmpty) {
      _showMessage('Salon nije povezan sa nalogom.');
      return;
    }
    if (name.isEmpty || duration <= 0) {
      _showMessage('Unesi naziv usluge i trajanje vece od 0 minuta.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _api.createService(
        salonId: salonId,
        name: name,
        durationMinutes: duration,
        price: price,
      );
      _nameController.clear();
      _durationController.text = '30';
      _priceController.text = '15';
      _reload();
      _showMessage('Usluga je dodana.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.salonId == null) {
      return const EmptyStateCard(
        icon: Icons.storefront_outlined,
        title: 'Salon nije povezan',
        message: 'Uloguj se kao vlasnik salona da bi dodavao usluge.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Usluge',
          actionLabel: 'Osvjezi',
          onAction: _reload,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<ApiServiceInfo>>(
          future: _servicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return WarningBox(
                text: 'Ne mogu ucitati usluge: ${snapshot.error}',
              );
            }
            final services = snapshot.data ?? [];
            if (services.isEmpty) {
              return const EmptyStateCard(
                icon: Icons.content_cut,
                title: 'Nema usluga',
                message: 'Dodaj prvu uslugu da korisnici mogu rezervisati.',
              );
            }
            return Column(
              children: [
                for (final service in services) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.content_cut,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        service.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${service.durationMinutes} min - ${service.priceLabel}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nova usluga',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Naziv',
                    prefixIcon: Icon(Icons.content_cut),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Trajanje',
                          suffixText: 'min',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cijena',
                          suffixText: 'EUR',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _addService,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Dodaj uslugu'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ServicesPanel extends StatelessWidget {
  const ServicesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final service in salonServices) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.content_cut, color: AppColors.primary),
              title: Text(
                service.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${service.duration} min - ${service.price} EUR'),
              trailing: Switch(value: service.active, onChanged: (_) {}),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Usluge se dodaju u panelu Usluge salona.'),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Dodaj uslugu'),
          ),
        ),
      ],
    );
  }
}

class WorkingHoursPanel extends StatefulWidget {
  const WorkingHoursPanel({super.key, required this.session});

  final AuthSession session;

  @override
  State<WorkingHoursPanel> createState() => _WorkingHoursPanelState();
}

class _WorkingSchedule {
  const _WorkingSchedule({required this.hours, required this.breaks});

  final List<WorkingHourInfo> hours;
  final List<SalonBreakInfo> breaks;
}

class _WorkingHoursPanelState extends State<WorkingHoursPanel> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<_WorkingSchedule> _scheduleFuture = _load();

  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _breakStartController = TextEditingController(text: '12:00');
  final _breakEndController = TextEditingController(text: '13:00');
  final _breakReasonController = TextEditingController(text: 'Pauza');

  _WorkingSchedule? _schedule;
  int _selectedDay = 1;
  bool _isClosed = false;
  bool _isSaving = false;

  Future<_WorkingSchedule> _load() async {
    final salonId = widget.session.salonId;
    if (salonId == null || salonId.isEmpty) {
      return Future.error('Salon nije povezan sa nalogom.');
    }
    final hours = await _api.listWorkingHours(salonId);
    final breaks = await _api.listBreaks(salonId);
    return _WorkingSchedule(hours: hours, breaks: breaks);
  }

  void _reload() {
    setState(() {
      _schedule = null;
      _scheduleFuture = _load();
    });
  }

  void _seed(_WorkingSchedule schedule) {
    if (_schedule != null) return;
    _schedule = schedule;
    _fillDay(_selectedDay);
  }

  void _fillDay(int day) {
    final schedule = _schedule;
    WorkingHourInfo? hour;
    for (final item in schedule?.hours ?? const <WorkingHourInfo>[]) {
      if (item.dayOfWeek == day) {
        hour = item;
        break;
      }
    }
    _startController.text = hour?.startTime ?? '09:00';
    _endController.text = hour?.endTime ?? '17:00';
    _isClosed = hour?.isClosed ?? false;
  }

  Future<void> _saveDay() async {
    final salonId = widget.session.salonId;
    final schedule = _schedule;
    if (salonId == null || schedule == null) return;

    final updatedHours = [
      for (final hour in schedule.hours)
        if (hour.dayOfWeek == _selectedDay)
          WorkingHourInfo(
            dayOfWeek: _selectedDay,
            startTime: _isClosed ? null : _startController.text.trim(),
            endTime: _isClosed ? null : _endController.text.trim(),
            isClosed: _isClosed,
          )
        else
          hour,
    ];

    setState(() => _isSaving = true);
    try {
      final saved = await _api.updateWorkingHours(
        salonId: salonId,
        workingHours: updatedHours,
      );
      setState(() {
        _schedule = _WorkingSchedule(hours: saved, breaks: schedule.breaks);
        _scheduleFuture = Future.value(_schedule);
      });
      _showMessage('Radno vrijeme je sacuvano.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addBreak() async {
    final salonId = widget.session.salonId;
    if (salonId == null) return;
    try {
      await _api.createBreak(
        salonId: salonId,
        dayOfWeek: _selectedDay,
        startTime: _breakStartController.text.trim(),
        endTime: _breakEndController.text.trim(),
        reason: _breakReasonController.text.trim(),
      );
      _reload();
      _showMessage('Pauza je dodana.');
    } catch (error) {
      _showMessage('$error');
    }
  }

  Future<void> _deleteBreak(SalonBreakInfo item) async {
    final salonId = widget.session.salonId;
    if (salonId == null) return;
    try {
      await _api.deleteBreak(salonId: salonId, breakId: item.id);
      _reload();
    } catch (error) {
      _showMessage('$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _breakStartController.dispose();
    _breakEndController.dispose();
    _breakReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.salonId == null) {
      return const EmptyStateCard(
        icon: Icons.schedule_outlined,
        title: 'Salon nije povezan',
        message: 'Radno vrijeme mozes podesiti kao vlasnik salona.',
      );
    }

    return FutureBuilder<_WorkingSchedule>(
      future: _scheduleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return WarningBox(
            text: 'Ne mogu ucitati radno vrijeme: ${snapshot.error}',
          );
        }

        _seed(snapshot.data!);
        final schedule = _schedule!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Radno vrijeme',
              actionLabel: 'Osvjezi',
              onAction: _reload,
            ),
            const SizedBox(height: 10),
            SettingsCard(
              children: [
                for (final hour in schedule.hours)
                  SettingsRow(
                    icon: hour.isClosed
                        ? Icons.do_not_disturb_on_outlined
                        : Icons.calendar_today_outlined,
                    title: dayName(hour.dayOfWeek),
                    value: hour.label,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDay,
                      decoration: const InputDecoration(
                        labelText: 'Dan',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      items: [
                        for (var day = 1; day <= 7; day++)
                          DropdownMenuItem(
                            value: day,
                            child: Text(dayName(day)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedDay = value;
                          _fillDay(value);
                        });
                      },
                    ),
                    SwitchListTile(
                      value: _isClosed,
                      onChanged: (value) => setState(() => _isClosed = value),
                      title: const Text('Zatvoreno'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            enabled: !_isClosed,
                            decoration: const InputDecoration(
                              labelText: 'Od',
                              prefixIcon: Icon(Icons.schedule),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            enabled: !_isClosed,
                            decoration: const InputDecoration(labelText: 'Do'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveDay,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Sacuvaj dan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SectionHeader(title: 'Pauze'),
            const SizedBox(height: 10),
            if (schedule.breaks.isEmpty)
              const EmptyStateCard(
                icon: Icons.coffee_outlined,
                title: 'Nema pauza',
                message: 'Dodaj pauzu koja blokira rezervacije.',
              )
            else
              SettingsCard(
                children: [
                  for (final item in schedule.breaks)
                    ListTile(
                      leading: const Icon(
                        Icons.coffee_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(dayName(item.dayOfWeek)),
                      subtitle: Text(
                        '${item.startTime} - ${item.endTime}  ${item.reason}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Obrisi',
                        onPressed: () => _deleteBreak(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _breakStartController,
                            decoration: const InputDecoration(labelText: 'Od'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _breakEndController,
                            decoration: const InputDecoration(labelText: 'Do'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _breakReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Razlog',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _addBreak,
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj pauzu'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CapacityPanel extends StatefulWidget {
  const CapacityPanel({super.key, required this.session});

  final AuthSession session;

  @override
  State<CapacityPanel> createState() => _CapacityPanelState();
}

class _CapacityPanelState extends State<CapacityPanel> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late final Future<SalonDetails> _detailsFuture = _load();
  SalonInfo? _salon;
  int _capacity = 1;
  bool _isSaving = false;

  Future<SalonDetails> _load() {
    final salonId = widget.session.salonId;
    if (salonId == null || salonId.isEmpty) {
      return Future.error('Salon nije povezan sa nalogom.');
    }
    return _api.getSalonDetails(salonId);
  }

  void _seed(SalonInfo salon) {
    if (_salon != null) return;
    _salon = salon;
    _capacity = salon.capacity;
  }

  Future<void> _save() async {
    final salon = _salon;
    if (salon == null) return;

    setState(() => _isSaving = true);
    try {
      final updated = await _api.updateSalon(
        salonId: salon.id,
        name: salon.name,
        description: salon.description ?? '',
        address: salon.address,
        city: salon.city,
        country: salon.country,
        phoneNumber: salon.phoneNumber ?? '',
        capacity: _capacity,
        latitude: salon.latitude,
        longitude: salon.longitude,
        isActive: salon.isActive,
      );
      setState(() {
        _salon = updated;
        _capacity = updated.capacity;
      });
      _showMessage('Kapacitet je sacuvan.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.salonId == null) {
      return const EmptyStateCard(
        icon: Icons.groups_outlined,
        title: 'Salon nije povezan',
        message: 'Kapacitet mozes podesiti kao vlasnik salona.',
      );
    }

    return FutureBuilder<SalonDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return WarningBox(
            text: 'Ne mogu ucitati kapacitet: ${snapshot.error}',
          );
        }

        _seed(snapshot.data!.salon);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kapacitet salona',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_capacity osobe mogu imati aktivnu rezervaciju u istom terminu.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _capacity <= 1
                          ? null
                          : () => setState(() => _capacity--),
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 18),
                    Text(
                      '$_capacity',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 18),
                    IconButton.filled(
                      onPressed: () => setState(() => _capacity++),
                      icon: const Icon(Icons.add),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Sacuvaj'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LocationPanel extends StatefulWidget {
  const LocationPanel({super.key, required this.session});

  final AuthSession session;

  @override
  State<LocationPanel> createState() => _LocationPanelState();
}

class _LocationPanelState extends State<LocationPanel> {
  late final AppApiClient _api = AppApiClient(widget.session);
  late Future<SalonDetails> _detailsFuture = _api.getSalonDetails(
    widget.session.salonId ?? '',
  );
  final _locationSearchController = TextEditingController();
  LatLng? _selectedPoint;
  SalonInfo? _salon;
  bool _isSaving = false;

  void _reload() {
    setState(() {
      _selectedPoint = null;
      _salon = null;
      _detailsFuture = _api.getSalonDetails(widget.session.salonId!);
    });
  }

  Future<void> _goToPlace() async {
    try {
      final point = await _api.geocodePlace(_locationSearchController.text);
      if (point == null) {
        _showMessage('Lokacija nije pronadjena.');
        return;
      }
      setState(() => _selectedPoint = point);
    } catch (error) {
      _showMessage('$error');
    }
  }

  Future<void> _saveLocation() async {
    final salon = _salon;
    final point = _selectedPoint;
    if (salon == null || point == null) return;

    setState(() => _isSaving = true);
    try {
      await _api.updateSalon(
        salonId: salon.id,
        name: salon.name,
        description: salon.description ?? '',
        address: salon.address,
        city: salon.city,
        country: salon.country,
        phoneNumber: salon.phoneNumber ?? '',
        capacity: salon.capacity,
        latitude: point.latitude,
        longitude: point.longitude,
        isActive: salon.isActive,
      );
      _showMessage('Lokacija je sacuvana.');
      _reload();
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _locationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.salonId == null) {
      return const EmptyStateCard(
        icon: Icons.location_on_outlined,
        title: 'Salon nije povezan',
        message: 'Lokaciju mozes podesiti u podacima salona.',
      );
    }
    return FutureBuilder<SalonDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return WarningBox(
            text: 'Ne mogu ucitati lokaciju: ${snapshot.error}',
          );
        }
        final salon = snapshot.data!.salon;
        _salon ??= salon;
        final selectedPoint =
            _selectedPoint ?? LatLng(salon.latitude, salon.longitude);
        return Column(
          children: [
            TextField(
              controller: _locationSearchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _goToPlace(),
              decoration: InputDecoration(
                hintText: 'Unesi grad ili adresu salona',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Pronadji',
                  onPressed: _goToPlace,
                  icon: const Icon(Icons.my_location_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            MapPanel(
              salons: [salon],
              center: selectedPoint,
              selectedPoint: selectedPoint,
              onLocationSelected: (point) =>
                  setState(() => _selectedPoint = point),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _selectedPoint == null || _isSaving
                  ? null
                  : _saveLocation,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Sacuvaj izabranu lokaciju'),
            ),
            const SizedBox(height: 12),
            SettingsCard(
              children: [
                SettingsRow(
                  icon: Icons.place_outlined,
                  title: 'Adresa',
                  value: salon.address,
                ),
                SettingsRow(
                  icon: Icons.location_city_outlined,
                  title: 'Grad',
                  value: salon.city,
                ),
                SettingsRow(
                  icon: Icons.public_outlined,
                  title: 'Drzava',
                  value: salon.country,
                ),
                SettingsRow(
                  icon: Icons.my_location_outlined,
                  title: 'Koordinate',
                  value:
                      '${selectedPoint.latitude.toStringAsFixed(5)}, ${selectedPoint.longitude.toStringAsFixed(5)}',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.badge,
    this.profileImageUrl,
    this.onUploadImage,
  });

  final String name;
  final String subtitle;
  final String badge;
  final String? profileImageUrl;
  final VoidCallback? onUploadImage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              backgroundImage: profileImageUrl == null
                  ? null
                  : NetworkImage(profileImageUrl!),
              child: profileImageUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 32)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  StatusPill(
                    label: badge,
                    foreground: AppColors.success,
                    background: AppColors.success.withAlpha(26),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Upload profilne slike',
              onPressed: onUploadImage,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: value.isEmpty ? null : Text(value),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}

class EditableRow extends StatelessWidget {
  const EditableRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  const NotificationItem({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(31),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(message),
      ),
    );
  }
}

class SalonAvatar extends StatelessWidget {
  const SalonAvatar({
    super.key,
    required this.color,
    required this.icon,
    this.size = 46,
  });

  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(26),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 16, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class WarningBox extends StatelessWidget {
  const WarningBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withAlpha(64)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

(Color, Color) statusColors(String status) {
  return switch (status) {
    'Accepted' ||
    'Prihvacen' ||
    'Completed' => (AppColors.success, AppColors.success.withAlpha(26)),
    'Pending' ||
    'Ceka potvrdu' => (AppColors.warning, AppColors.warning.withAlpha(28)),
    'NoShow' ||
    'Otkazan' ||
    'Rejected' => (AppColors.danger, AppColors.danger.withAlpha(26)),
    _ => (AppColors.primary, AppColors.primary.withAlpha(24)),
  };
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppColors {
  static const primary = Color(0xFF0F766E);
  static const ink = Color(0xFF17211E);
  static const muted = Color(0xFF65706B);
  static const canvas = Color(0xFFF7F8F5);
  static const border = Color(0xFFDDE5E0);
  static const soft = Color(0xFFEAF3F1);
  static const success = Color(0xFF16814F);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFB42318);
}

class SalonInfo {
  const SalonInfo({
    this.id = '',
    this.description,
    this.address = '',
    this.country = 'BiH',
    this.phoneNumber,
    this.isActive = true,
    this.minPrice,
    required this.name,
    required this.shortName,
    required this.city,
    required this.distance,
    required this.rating,
    required this.nextSlot,
    required this.priceLabel,
    required this.capacity,
    required this.services,
    required this.latitude,
    required this.longitude,
    required this.color,
    required this.icon,
    this.mainImageUrl,
  });

  factory SalonInfo.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Salon';
    final city = json['city'] as String? ?? 'Nepoznat grad';
    final address = json['address'] as String? ?? city;
    final services = (json['services'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    final minPrice = ((json['minPrice'] as num?)?.toDouble());
    final fallbackPoint =
        cityFallbackCoordinates('$city $address') ?? LatLng(44.7587, 19.2144);
    final latitude =
        (json['latitude'] as num?)?.toDouble() ?? fallbackPoint.latitude;
    final longitude =
        (json['longitude'] as num?)?.toDouble() ?? fallbackPoint.longitude;
    return SalonInfo(
      id: json['id'] as String? ?? '',
      description: json['description'] as String?,
      address: address,
      country: json['country'] as String? ?? 'BiH',
      phoneNumber: json['phoneNumber'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      minPrice: minPrice,
      name: name,
      shortName: name.length > 12 ? name.substring(0, 12) : name,
      city: city,
      distance: address,
      rating: ((json['rating'] as num?) ?? 0).toDouble(),
      nextSlot: 'Pogledaj termine',
      priceLabel: minPrice == null
          ? 'Usluge'
          : 'od ${minPrice.toStringAsFixed(2)} EUR',
      capacity: (json['capacity'] as num?)?.toInt() ?? 1,
      services: services,
      latitude: latitude,
      longitude: longitude,
      color: AppColors.primary,
      icon: Icons.storefront_outlined,
      mainImageUrl: json['mainImageUrl'] as String?,
    );
  }

  final String id;
  final String? description;
  final String address;
  final String country;
  final String? phoneNumber;
  final bool isActive;
  final double? minPrice;
  final String name;
  final String shortName;
  final String city;
  final String distance;
  final double rating;
  final String nextSlot;
  final String priceLabel;
  final int capacity;
  final List<String> services;
  final double latitude;
  final double longitude;
  final Color color;
  final IconData icon;
  final String? mainImageUrl;
}

class SalonDetails {
  const SalonDetails({
    required this.salon,
    required this.services,
    required this.images,
  });

  factory SalonDetails.fromJson(Map<String, dynamic> json) {
    final services = json['services'] as List<dynamic>? ?? [];
    final images = json['images'] as List<dynamic>? ?? [];
    return SalonDetails(
      salon: SalonInfo.fromJson(json['salon'] as Map<String, dynamic>),
      services: services
          .map((item) => ApiServiceInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      images: images
          .map((item) => SalonImageInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final SalonInfo salon;
  final List<ApiServiceInfo> services;
  final List<SalonImageInfo> images;
}

class SalonImageInfo {
  const SalonImageInfo({
    required this.id,
    required this.imageUrl,
    required this.isMain,
  });

  factory SalonImageInfo.fromJson(Map<String, dynamic> json) {
    return SalonImageInfo(
      id: json['id'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      isMain: json['isMain'] as bool? ?? false,
    );
  }

  final String id;
  final String imageUrl;
  final bool isMain;
}

class BookingInfo {
  const BookingInfo({
    this.id = '',
    required this.salon,
    required this.time,
    required this.service,
    required this.status,
    required this.canCancel,
    this.canReview = false,
  });

  factory BookingInfo.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startTime'] as String? ?? '');
    final status = json['status'] as String? ?? 'Pending';
    return BookingInfo(
      id: json['id'] as String? ?? '',
      salon: json['salonName'] as String? ?? 'Salon',
      time: start == null ? '' : formatDateTime(start),
      service: json['serviceName'] as String? ?? 'Usluga',
      status: status,
      canCancel: status == 'Pending' || status == 'Accepted',
      canReview: status == 'Completed',
    );
  }

  final String id;
  final String salon;
  final String time;
  final String service;
  final String status;
  final bool canCancel;
  final bool canReview;
}

class RequestInfo {
  const RequestInfo({
    this.id = '',
    required this.customer,
    required this.time,
    required this.service,
    required this.warning,
    this.status = 'Pending',
    this.durationMinutes,
    this.start,
  });

  factory RequestInfo.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startTime'] as String? ?? '');
    final durationMinutes = (json['durationMinutes'] as num?)?.toInt();
    final serviceName = json['serviceName'] as String? ?? 'Usluga';
    return RequestInfo(
      id: json['id'] as String? ?? '',
      customer: json['customerName'] as String? ?? 'Korisnik',
      time: start == null ? '' : formatDateTime(start),
      service: durationMinutes == null
          ? serviceName
          : '$serviceName - $durationMinutes min',
      warning:
          json['reliabilityStatus'] as String? ??
          'Status korisnika: Novi korisnik.',
      status: json['status'] as String? ?? 'Pending',
      durationMinutes: durationMinutes,
      start: start,
    );
  }

  final String id;
  final String customer;
  final String time;
  final String service;
  final String warning;
  final String status;
  final int? durationMinutes;
  final DateTime? start;
}

class ScheduleSlot {
  const ScheduleSlot({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String time;
  final String title;
  final String subtitle;
  final String status;
}

class CapacitySlot {
  const CapacitySlot({
    required this.time,
    required this.booked,
    required this.capacity,
  });

  final String time;
  final int booked;
  final int capacity;
}

class ServiceInfo {
  const ServiceInfo({
    required this.name,
    required this.duration,
    required this.price,
    required this.active,
  });

  final String name;
  final int duration;
  final int price;
  final bool active;
}

class ApiServiceInfo {
  const ApiServiceInfo({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
  });

  factory ApiServiceInfo.fromJson(Map<String, dynamic> json) {
    return ApiServiceInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Usluga',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      price: ((json['price'] as num?) ?? 0).toDouble(),
    );
  }

  final String id;
  final String name;
  final int durationMinutes;
  final double price;

  String get priceLabel =>
      price == 0 ? 'Cijena nije unesena' : '${price.toStringAsFixed(2)} EUR';
}

class ApiSlotInfo {
  const ApiSlotInfo({
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.taken,
    required this.available,
  });

  factory ApiSlotInfo.fromJson(Map<String, dynamic> json) {
    return ApiSlotInfo(
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 1,
      taken: (json['taken'] as num?)?.toInt() ?? 0,
      available: (json['available'] as num?)?.toInt() ?? 0,
    );
  }

  final String startTime;
  final String endTime;
  final int capacity;
  final int taken;
  final int available;

  String get startLabel {
    final parsed = DateTime.tryParse(startTime);
    if (parsed == null) return startTime;
    final local = parsed.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class WorkingHourInfo {
  const WorkingHourInfo({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isClosed,
  });

  factory WorkingHourInfo.fromJson(Map<String, dynamic> json) {
    return WorkingHourInfo(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      isClosed: json['isClosed'] as bool? ?? false,
    );
  }

  final int dayOfWeek;
  final String? startTime;
  final String? endTime;
  final bool isClosed;

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isClosed': isClosed,
    };
  }

  WorkingHourInfo copyWith({
    String? startTime,
    String? endTime,
    bool? isClosed,
  }) {
    return WorkingHourInfo(
      dayOfWeek: dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  String get label {
    if (isClosed) return 'Zatvoreno';
    return '${startTime ?? '--:--'} - ${endTime ?? '--:--'}';
  }
}

class SalonBreakInfo {
  const SalonBreakInfo({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.reason,
  });

  factory SalonBreakInfo.fromJson(Map<String, dynamic> json) {
    return SalonBreakInfo(
      id: json['id'] as String? ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      reason: json['reason'] as String? ?? 'Pauza',
    );
  }

  final String id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String reason;
}

class NotificationInfo {
  const NotificationInfo({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
  });

  factory NotificationInfo.fromJson(Map<String, dynamic> json) {
    return NotificationInfo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Obavjestenje',
      message: json['message'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final String message;
  final bool isRead;

  IconData get icon {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('prihvac')) return Icons.check_circle_outline;
    if (lowerTitle.contains('odbij')) return Icons.block_outlined;
    if (lowerTitle.contains('otkazan')) return Icons.cancel_outlined;
    if (lowerTitle.contains('zahtjev')) return Icons.inbox_outlined;
    if (lowerTitle.contains('upozorenje')) {
      return Icons.warning_amber_outlined;
    }
    return Icons.notifications_outlined;
  }

  Color get color {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('prihvac')) return AppColors.success;
    if (lowerTitle.contains('odbij') || lowerTitle.contains('upozorenje')) {
      return AppColors.danger;
    }
    if (lowerTitle.contains('otkazan')) return AppColors.warning;
    return isRead ? AppColors.muted : AppColors.primary;
  }
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month. $hour:$minute';
}

String dayName(int day) {
  return switch (day) {
    1 => 'Ponedjeljak',
    2 => 'Utorak',
    3 => 'Srijeda',
    4 => 'Cetvrtak',
    5 => 'Petak',
    6 => 'Subota',
    7 => 'Nedjelja',
    _ => 'Dan $day',
  };
}

bool sameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Future<LatLng?> geocodePlaceQuery(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;

  final fallback = cityFallbackCoordinates(trimmed);
  if (fallback != null) return fallback;

  final response = await http.get(
    Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'limit': '1',
      'q': trimmed,
    }),
    headers: {'User-Agent': 'Makaze MVP local app'},
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const AuthException('Pretraga lokacije nije uspjela.');
  }
  final decoded = jsonDecode(response.body) as List<dynamic>;
  if (decoded.isEmpty) return null;
  final item = decoded.first as Map<String, dynamic>;
  final lat = double.tryParse(item['lat']?.toString() ?? '');
  final lon = double.tryParse(item['lon']?.toString() ?? '');
  if (lat == null || lon == null) return null;
  return LatLng(lat, lon);
}

Future<PlatformFile?> pickImageFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.single;
}

LatLng? cityFallbackCoordinates(String query) {
  final normalized = query.toLowerCase().trim();
  final cities = <String, LatLng>{
    'banja luka': LatLng(44.7722, 17.1910),
    'banjaluka': LatLng(44.7722, 17.1910),
    'bijeljina': LatLng(44.7587, 19.2144),
    'sarajevo': LatLng(43.8563, 18.4131),
    'tuzla': LatLng(44.5384, 18.6671),
    'mostar': LatLng(43.3438, 17.8078),
    'prijedor': LatLng(44.9799, 16.7140),
    'doboj': LatLng(44.7348, 18.0875),
    'beograd': LatLng(44.8125, 20.4612),
    'novi sad': LatLng(45.2671, 19.8335),
    'zagreb': LatLng(45.8150, 15.9819),
  };
  for (final entry in cities.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return null;
}

class MetricData {
  const MetricData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

const sampleSalons = [
  SalonInfo(
    name: 'Salon Elite',
    shortName: 'Elite',
    city: 'Bijeljina',
    distance: '1.2 km',
    rating: 4.8,
    nextSlot: 'Danas 16:30',
    priceLabel: 'od 15 EUR',
    capacity: 3,
    services: ['Sisanje', 'Brada', 'Feniranje'],
    latitude: 44.7588,
    longitude: 19.2146,
    color: AppColors.primary,
    icon: Icons.spa_outlined,
  ),
  SalonInfo(
    name: 'Studio Line',
    shortName: 'Line',
    city: 'Bijeljina',
    distance: '2.4 km',
    rating: 4.6,
    nextSlot: 'Sutra 09:00',
    priceLabel: 'od 12 EUR',
    capacity: 2,
    services: ['Musko sisanje', 'Farbanje', 'Pranje'],
    latitude: 44.7654,
    longitude: 19.2233,
    color: AppColors.warning,
    icon: Icons.brush_outlined,
  ),
  SalonInfo(
    name: 'Barber House',
    shortName: 'House',
    city: 'Dvorovi',
    distance: '4.1 km',
    rating: 4.9,
    nextSlot: 'Danas 18:00',
    priceLabel: 'od 18 EUR',
    capacity: 4,
    services: ['Brada', 'Fade', 'Tretman'],
    latitude: 44.7865,
    longitude: 19.2561,
    color: AppColors.success,
    icon: Icons.chair_outlined,
  ),
];

const customerBookings = [
  BookingInfo(
    salon: 'Salon Elite',
    time: 'Danas, 16:30',
    service: 'Musko sisanje - 30 min',
    status: 'Prihvacen',
    canCancel: true,
  ),
  BookingInfo(
    salon: 'Studio Line',
    time: 'Petak, 15:30',
    service: 'Sisanje + brada - 45 min',
    status: 'Ceka potvrdu',
    canCancel: true,
  ),
  BookingInfo(
    salon: 'Barber House',
    time: '12. maj, 11:00',
    service: 'Brada - 20 min',
    status: 'Completed',
    canCancel: false,
  ),
  BookingInfo(
    salon: 'Salon Elite',
    time: '8. maj, 10:00',
    service: 'Feniranje - 40 min',
    status: 'Otkazan',
    canCancel: false,
  ),
];

const salonRequests = [
  RequestInfo(
    customer: 'Nemanja Pejic',
    time: 'Petak, 15:30',
    service: 'Musko sisanje - 30 min',
    warning: 'Korisnik je jednom otkazao prekasno.',
  ),
  RequestInfo(
    customer: 'Marko Petrovic',
    time: 'Danas, 17:00',
    service: 'Sisanje + brada - 45 min',
    warning: 'Pouzdan korisnik, 5 zavrsenih termina.',
  ),
  RequestInfo(
    customer: 'Stefan Milic',
    time: 'Sutra, 09:30',
    service: 'Brada - 20 min',
    warning: 'Korisnik ima 2 kasna otkazivanja i 1 nedolazak.',
  ),
];

const todaySlots = [
  ScheduleSlot(
    time: '09:00',
    title: 'Marko Petrovic',
    subtitle: 'Musko sisanje',
    status: 'Accepted',
  ),
  ScheduleSlot(
    time: '09:30',
    title: 'Slobodno',
    subtitle: '0/3 popunjeno',
    status: 'Open',
  ),
  ScheduleSlot(
    time: '10:00',
    title: 'Nemanja Pejic',
    subtitle: 'Ceka potvrdu - upozorenje',
    status: 'Pending',
  ),
  ScheduleSlot(
    time: '10:30',
    title: 'Jovan Lukic',
    subtitle: 'Sisanje + brada',
    status: 'Accepted',
  ),
  ScheduleSlot(
    time: '11:00',
    title: 'Slobodno',
    subtitle: '1/3 popunjeno',
    status: 'Open',
  ),
];

const calendarSlots = [
  CapacitySlot(time: '09:00', booked: 1, capacity: 3),
  CapacitySlot(time: '09:30', booked: 0, capacity: 3),
  CapacitySlot(time: '10:00', booked: 2, capacity: 3),
  CapacitySlot(time: '10:30', booked: 3, capacity: 3),
  CapacitySlot(time: '11:00', booked: 1, capacity: 3),
  CapacitySlot(time: '11:30', booked: 0, capacity: 3),
];

const salonServices = [
  ServiceInfo(name: 'Musko sisanje', duration: 30, price: 15, active: true),
  ServiceInfo(name: 'Brada', duration: 20, price: 8, active: true),
  ServiceInfo(name: 'Sisanje + brada', duration: 45, price: 20, active: true),
  ServiceInfo(name: 'Farbanje', duration: 120, price: 50, active: false),
];
