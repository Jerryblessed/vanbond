import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:geolocator/geolocator.dart';

/**
 * VANBOND - Nomadic Dating & Community Platform
 * "For God so loved the world..." - John 3:16
 * 
 * Features: Nomadic Dating, Activity-Based Friends, Builder Help Marketplace,
 * Verified Community, AI-Powered Matching, Real-time Chat
 */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RevenueCat
  await Purchases.configure(
    PurchasesConfiguration('goog_ackWTVXQpPlsDdyhXiQIbztZfDl'),
  );

  runApp(const VanBondApp());
}

class VanBondApp extends StatelessWidget {
  const VanBondApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanBond',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4E71),
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// === MODELS ===

enum UserTier { free, pro, premium }

enum VerificationStatus { pending, verified, rejected }

enum LookingFor { dating, friends, both }

class UserSession {
  final String userId;
  final String email;
  String name;
  String bio;
  String location;
  String? vanType;
  String? travelRoute;
  List<String> activities;
  List<String> profileImages;
  LookingFor lookingFor;
  VerificationStatus verificationStatus;
  int creditsRemaining;
  UserTier tier;
  int? age;
  String? gender;
  double? latitude;
  double? longitude;

  UserSession({
    required this.userId,
    required this.email,
    this.name = '',
    this.bio = '',
    this.location = '',
    this.vanType,
    this.travelRoute,
    this.activities = const [],
    this.profileImages = const [],
    this.lookingFor = LookingFor.both,
    this.verificationStatus = VerificationStatus.pending,
    this.creditsRemaining = 5,
    this.tier = UserTier.free,
    this.age,
    this.gender,
    this.latitude,
    this.longitude,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    userId: json['user_id'] ?? '',
    email: json['email'] ?? '',
    name: json['name'] ?? '',
    bio: json['bio'] ?? '',
    location: json['location'] ?? '',
    vanType: json['van_type'],
    travelRoute: json['travel_route'],
    activities: List<String>.from(json['activities'] ?? []),
    profileImages: List<String>.from(json['profile_images'] ?? []),
    lookingFor: LookingFor.values.firstWhere(
      (t) => t.toString().split('.').last == (json['looking_for'] ?? 'both'),
      orElse: () => LookingFor.both,
    ),
    verificationStatus: VerificationStatus.values.firstWhere(
      (t) =>
          t.toString().split('.').last ==
          (json['verification_status'] ?? 'pending'),
      orElse: () => VerificationStatus.pending,
    ),
    creditsRemaining: json['credits_remaining'] ?? 5,
    tier: UserTier.values.firstWhere(
      (t) => t.toString().split('.').last == (json['tier'] ?? 'free'),
      orElse: () => UserTier.free,
    ),
    age: json['age'],
    gender: json['gender'],
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'name': name,
    'bio': bio,
    'location': location,
    'van_type': vanType,
    'travel_route': travelRoute,
    'activities': activities,
    'profile_images': profileImages,
    'looking_for': lookingFor.toString().split('.').last,
    'verification_status': verificationStatus.toString().split('.').last,
    'credits_remaining': creditsRemaining,
    'tier': tier.toString().split('.').last,
    'age': age,
    'gender': gender,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class UserProfile {
  final String userId;
  final String name;
  final int? age;
  final String bio;
  final String location;
  final List<String> images;
  final List<String> activities;
  final String? vanType;
  final double? distance;

  UserProfile({
    required this.userId,
    required this.name,
    this.age,
    required this.bio,
    required this.location,
    required this.images,
    required this.activities,
    this.vanType,
    this.distance,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: json['user_id'] ?? '',
    name: json['name'] ?? 'Anonymous',
    age: json['age'],
    bio: json['bio'] ?? '',
    location: json['location'] ?? '',
    images: List<String>.from(json['images'] ?? []),
    activities: List<String>.from(json['activities'] ?? []),
    vanType: json['van_type'],
    distance: json['distance']?.toDouble(),
  );
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] ?? '',
    senderId: json['sender_id'] ?? '',
    receiverId: json['receiver_id'] ?? '',
    message: json['message'] ?? '',
    timestamp: DateTime.parse(json['timestamp']),
    isRead: json['is_read'] ?? false,
  );
}

class BuilderProfile {
  final String userId;
  final String name;
  final String title;
  final String description;
  final double hourlyRate;
  final List<String> expertise;
  final double rating;
  final int sessionsCompleted;
  final String? profileImage;

  BuilderProfile({
    required this.userId,
    required this.name,
    required this.title,
    required this.description,
    required this.hourlyRate,
    required this.expertise,
    this.rating = 0.0,
    this.sessionsCompleted = 0,
    this.profileImage,
  });

  factory BuilderProfile.fromJson(Map<String, dynamic> json) => BuilderProfile(
    userId: json['user_id'] ?? '',
    name: json['name'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    hourlyRate: json['hourly_rate']?.toDouble() ?? 0.0,
    expertise: List<String>.from(json['expertise'] ?? []),
    rating: json['rating']?.toDouble() ?? 0.0,
    sessionsCompleted: json['sessions_completed'] ?? 0,
    profileImage: json['profile_image'],
  );
}

// === API SERVICE ===

class ApiService {
  static const String baseUrl =
      'https://vanbon-gbgzfqh8gpbpbkfa.eastus-01.azurewebsites.net';

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String inviteCode,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'invite_code': inviteCode,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateProfile(UserSession user) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/${user.userId}/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(user.toJson()),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> uploadProfileImage(
    String userId,
    File image,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/user/$userId/upload-image'),
    );
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  static Future<List<UserProfile>> getDiscoverProfiles(
    String userId,
    String mode,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/discover/$userId?mode=$mode'),
    );
    final List<dynamic> data = jsonDecode(response.body)['profiles'];
    return data.map((p) => UserProfile.fromJson(p)).toList();
  }

  static Future<Map<String, dynamic>> swipe(
    String userId,
    String targetUserId,
    String direction,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/swipe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'target_user_id': targetUserId,
        'direction': direction,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<List<UserProfile>> getMatches(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/matches/$userId'));
    final List<dynamic> data = jsonDecode(response.body)['matches'];
    return data.map((m) => UserProfile.fromJson(m)).toList();
  }

  static Future<List<Message>> getMessages(
    String userId,
    String otherUserId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/$userId/$otherUserId'),
    );
    final List<dynamic> data = jsonDecode(response.body)['messages'];
    return data.map((m) => Message.fromJson(m)).toList();
  }

  static Future<Map<String, dynamic>> sendMessage(
    String senderId,
    String receiverId,
    String message,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message': message,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<List<BuilderProfile>> getBuilders() async {
    final response = await http.get(Uri.parse('$baseUrl/builders'));
    final List<dynamic> data = jsonDecode(response.body)['builders'];
    return data.map((b) => BuilderProfile.fromJson(b)).toList();
  }

  static Future<Map<String, dynamic>> createBuilderProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/builders/$userId/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> bookBuilder(
    String clientId,
    String builderId,
    int hours,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/builders/book'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': clientId,
        'builder_id': builderId,
        'hours': hours,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyProfile(
    String userId,
    File image,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/verify/$userId'),
    );
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAiMatchSuggestions(
    String userId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ai/match-suggestions/$userId'),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> askVanBuildQuestion(
    String question,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/van-help'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question}),
    );
    return jsonDecode(response.body);
  }
}

// === AUTH WRAPPER ===

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserSession? session;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_session');

    if (userData != null) {
      setState(() {
        session = UserSession.fromJson(jsonDecode(userData));
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void handleAuth(UserSession user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_session', jsonEncode(user.toJson()));
    setState(() => session = user);

    // === SYNC WITH REVENUECAT ===
    try {
      await Purchases.logIn(user.userId);
      await Purchases.setEmail(user.email);

      // UPDATE THIS STRING FOR EACH APP:
      await Purchases.setAttributes({
        'app_name':
            'VanBond', // Change to 'MumWise', 'AICoach', 'PacksLight', etc.
        'signup_tier': user.tier.toString(),
      });
    } catch (e) {
      debugPrint('RevenueCat user sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return session == null
        ? LoginScreen(onSuccess: handleAuth)
        : MainNavigation(
          user: session!,
          onSessionUpdate: (u) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_session', jsonEncode(u.toJson()));
            setState(() => session = u);
          },
        );
  }
}

// === LOGIN SCREEN ===

class LoginScreen extends StatefulWidget {
  final Function(UserSession) onSuccess;
  const LoginScreen({super.key, required this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _inviteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response =
          isLogin
              ? await ApiService.login(
                _emailController.text,
                _passController.text,
              )
              : await ApiService.register(
                _emailController.text,
                _passController.text,
                _inviteController.text,
              );

      if (response['success'] == true) {
        widget.onSuccess(UserSession.fromJson(response['user']));
      } else {
        _showError(response['message'] ?? 'Authentication failed');
      }
    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6B4E71),
              const Color(0xFF9B7EAC),
              const Color(0xFFD4A5A5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_car,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'VanBond',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Where Nomads Connect',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '"For God so loved the world..." - John 3:16',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 48),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (v) => v!.contains('@') ? null : 'Invalid email',
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (v) => v!.length >= 6 ? null : 'Min 6 characters',
                    ),

                    if (!isLogin) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _inviteController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Invite Code (Required)',
                          prefixIcon: const Icon(Icons.verified_user),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator:
                            (v) =>
                                v!.isNotEmpty ? null : 'Invite code required',
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6B4E71),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            isLoading
                                ? const CircularProgressIndicator()
                                : Text(
                                  isLogin ? 'Login' : 'Join the Community',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin
                            ? 'New Nomad? Get Invite Code'
                            : 'Already have account? Login',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.verified_user,
                            color: Colors.white70,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Verified Community',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Invite-only access keeps our nomadic family safe and intentional',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// === MAIN NAVIGATION ===

class MainNavigation extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onSessionUpdate;

  const MainNavigation({
    super.key,
    required this.user,
    required this.onSessionUpdate,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _updatePages();
  }

  @override
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _updatePages();
    }
  }

  void _updatePages() {
    _pages = [
      HomeScreen(user: widget.user),
      DiscoverScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      BuilderHubScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      MessagesScreen(user: widget.user),
      ProfileScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Builders',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// === HOME SCREEN ===

class HomeScreen extends StatelessWidget {
  final UserSession user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VanBond',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (user.verificationStatus != VerificationStatus.verified)
            IconButton(
              icon: const Icon(Icons.verified_user, color: Colors.orange),
              onPressed: () => _showVerificationDialog(context),
              tooltip: 'Get Verified',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(context),
            _buildQuickActions(context),
            _buildMissionSection(),
            _buildActivitySuggestions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      height: 240,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B4E71), Color(0xFF9B7EAC)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Opacity(
                opacity: 0.2,
                child: Image.network(
                  'https://images.unsplash.com/photo-1527786356703-4b100091cd2c?w=800',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name.isEmpty ? "Nomad" : user.name}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find your travel companions and build your dream van',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatusChip(
                      icon: Icons.verified,
                      label:
                          user.verificationStatus
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(),
                      color:
                          user.verificationStatus == VerificationStatus.verified
                              ? Colors.green
                              : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      icon: Icons.stars,
                      label: user.tier.toString().split('.').last.toUpperCase(),
                      color: Colors.amber,
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

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.favorite,
                  title: 'Find Love',
                  subtitle: 'Meet fellow nomads',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFC06C84)],
                  ),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  DiscoverScreen(user: user, onUpdate: (_) {}),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.people,
                  title: 'Find Friends',
                  subtitle: 'Activity buddies',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E8CFF), Color(0xFF6B7FDB)],
                  ),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  DiscoverScreen(user: user, onUpdate: (_) {}),
                        ),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Text(
                'Our Mission',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '"For God so loved the world, that he gave his only begotten Son..." - John 3:16',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Just as connection was meant to be shared, we bring nomads together in love, community, and purpose. Travel is better together.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySuggestions() {
    final activities = [
      '🧗 Climbing',
      '🎿 Skiing',
      '🏔️ Hiking',
      '🏄 Surfing',
      '🚴 Biking',
      '📸 Photography',
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Activities',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activities.map((a) => Chip(label: Text(a))).toList(),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Get Verified'),
            content: const Text(
              'Verification helps keep our community safe. Upload a selfie to verify your identity.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to verification screen
                },
                child: const Text('Verify Now'),
              ),
            ],
          ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// === DISCOVER SCREEN (SWIPE) ===

class DiscoverScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const DiscoverScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserProfile> _profiles = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadProfiles();
      }
    });
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final mode = _tabController.index == 0 ? 'dating' : 'friends';
      final profiles = await ApiService.getDiscoverProfiles(
        widget.user.userId,
        mode,
      );
      setState(() {
        _profiles = profiles;
        _currentIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _swipe(String direction) async {
    if (_currentIndex >= _profiles.length) return;

    final profile = _profiles[_currentIndex];
    final result = await ApiService.swipe(
      widget.user.userId,
      profile.userId,
      direction,
    );

    if (result['match'] == true) {
      _showMatchDialog(profile);
    }

    setState(() {
      _currentIndex++;
      if (_currentIndex >= _profiles.length) {
        _loadProfiles();
      }
    });
  }

  void _showMatchDialog(UserProfile profile) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('🎉 It\'s a Match!'),
            content: Text('You and ${profile.name} both liked each other!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep Swiping'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to chat
                },
                child: const Text('Say Hi'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dating 💕', icon: Icon(Icons.favorite)),
            Tab(text: 'Friends 🤝', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentIndex >= _profiles.length
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No more profiles for now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadProfiles,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Again'),
                    ),
                  ],
                ),
              )
              : _buildSwipeCard(),
    );
  }

  Widget _buildSwipeCard() {
    final profile = _profiles[_currentIndex];

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                _swipe('right');
              } else if (details.primaryVelocity! < 0) {
                _swipe('left');
              }
            },
            child: Card(
              margin: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (profile.images.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: profile.images[0],
                            fit: BoxFit.cover,
                            placeholder:
                                (_, __) =>
                                    Container(color: Colors.grey.shade300),
                            errorWidget:
                                (_, __, ___) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.person, size: 100),
                                ),
                          )
                        else
                          Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.person, size: 100),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${profile.name}${profile.age != null ? ", ${profile.age}" : ""}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      profile.location,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (profile.distance != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${profile.distance!.toStringAsFixed(0)} miles away',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              if (profile.vanType != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '🚐 ${profile.vanType}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                profile.bio,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children:
                                    profile.activities
                                        .take(3)
                                        .map(
                                          (a) => Chip(
                                            label: Text(
                                              a,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                            backgroundColor: Colors.white
                                                .withOpacity(0.3),
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SwipeButton(
                icon: Icons.close,
                color: Colors.red,
                onPressed: () => _swipe('left'),
              ),
              const SizedBox(width: 24),
              _SwipeButton(
                icon: Icons.star,
                color: Colors.blue,
                onPressed: () {
                  // Super like functionality
                },
              ),
              const SizedBox(width: 24),
              _SwipeButton(
                icon: Icons.favorite,
                color: Colors.green,
                onPressed: () => _swipe('right'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _SwipeButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _SwipeButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: color,
        heroTag: null,
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}

// === BUILDER HUB SCREEN ===

class BuilderHubScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const BuilderHubScreen({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<BuilderHubScreen> createState() => _BuilderHubScreenState();
}

class _BuilderHubScreenState extends State<BuilderHubScreen> {
  List<BuilderProfile> _builders = [];
  bool _isLoading = true;
  final _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBuilders();
  }

  Future<void> _loadBuilders() async {
    setState(() => _isLoading = true);
    try {
      final builders = await ApiService.getBuilders();
      setState(() {
        _builders = builders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _askAiQuestion() async {
    if (_questionController.text.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.askVanBuildQuestion(
        _questionController.text,
      );
      Navigator.pop(context);

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('AI Van Build Assistant'),
              content: SingleChildScrollView(
                child: Text(response['answer'] ?? 'No response'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
      );

      _questionController.clear();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get AI response')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Builder Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create builder profile
            },
            tooltip: 'Become a Builder',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAiAssistant(),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _builders.isEmpty
                    ? const Center(child: Text('No builders available'))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _builders.length,
                      itemBuilder: (context, index) {
                        final builder = _builders[index];
                        return _BuilderCard(
                          builder: builder,
                          user: widget.user,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistant() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'AI Van Build Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ask anything about van builds...',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _askAiQuestion,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }
}

class _BuilderCard extends StatelessWidget {
  final BuilderProfile builder;
  final UserSession user;

  const _BuilderCard({required this.builder, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      builder.profileImage != null
                          ? NetworkImage(builder.profileImage!)
                          : null,
                  child:
                      builder.profileImage == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        builder.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        builder.title,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${builder.rating.toStringAsFixed(1)} • ${builder.sessionsCompleted} sessions',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              builder.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children:
                  builder.expertise
                      .map(
                        (e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 11)),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${builder.hourlyRate.toStringAsFixed(0)}/hour',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showBookingDialog(context);
                  },
                  child: const Text('Book Session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDialog(BuildContext context) {
    int hours = 1;
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Book ${builder.name}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hourly Rate: \$${builder.hourlyRate.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (hours > 1) setState(() => hours--);
                            },
                          ),
                          Text(
                            '$hours hours',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setState(() => hours++),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Total: \$${(builder.hourlyRate * hours).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await ApiService.bookBuilder(
                            user.userId,
                            builder.userId,
                            hours,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Session booked! Check your messages.',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Booking failed')),
                          );
                        }
                      },
                      child: const Text('Confirm Booking'),
                    ),
                  ],
                ),
          ),
    );
  }
}

// === MESSAGES SCREEN ===

class MessagesScreen extends StatefulWidget {
  final UserSession user;
  const MessagesScreen({super.key, required this.user});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<UserProfile> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final matches = await ApiService.getMatches(widget.user.userId);
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _matches.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No matches yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Start swiping to find your travel companions!'),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _matches.length,
                itemBuilder: (context, index) {
                  final match = _matches[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          match.images.isNotEmpty
                              ? NetworkImage(match.images[0])
                              : null,
                      child:
                          match.images.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                    ),
                    title: Text(
                      match.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(match.location),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  ChatScreen(user: widget.user, match: match),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}

// === CHAT SCREEN ===

class ChatScreen extends StatefulWidget {
  final UserSession user;
  final UserProfile match;

  const ChatScreen({super.key, required this.user, required this.match});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  List<Message> _messages = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadMessages(),
    );
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await ApiService.getMessages(
        widget.user.userId,
        widget.match.userId,
      );
      if (mounted) {
        setState(() => _messages = messages);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final message = _messageController.text;
    _messageController.clear();

    try {
      await ApiService.sendMessage(
        widget.user.userId,
        widget.match.userId,
        message,
      );
      _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  widget.match.images.isNotEmpty
                      ? NetworkImage(widget.match.images[0])
                      : null,
              child:
                  widget.match.images.isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
            ),
            const SizedBox(width: 12),
            Text(widget.match.name),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _messages.isEmpty
                    ? const Center(
                      child: Text('Say hi to start the conversation!'),
                    )
                    : ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        final isMe = message.senderId == widget.user.userId;

                        return Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? const Color(0xFF6B4E71)
                                      : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              message.message,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF6B4E71),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }
}

// === PROFILE SCREEN ===

class ProfileScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const ProfileScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _vanTypeController;
  late TextEditingController _travelRouteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio);
    _locationController = TextEditingController(text: widget.user.location);
    _vanTypeController = TextEditingController(text: widget.user.vanType);
    _travelRouteController = TextEditingController(
      text: widget.user.travelRoute,
    );
  }

  Future<void> _saveProfile() async {
    widget.user.name = _nameController.text;
    widget.user.bio = _bioController.text;
    widget.user.location = _locationController.text;
    widget.user.vanType = _vanTypeController.text;
    widget.user.travelRoute = _travelRouteController.text;

    try {
      await ApiService.updateProfile(widget.user);
      widget.onUpdate(widget.user);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Update failed')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        final result = await ApiService.uploadProfileImage(
          widget.user.userId,
          File(image.path),
        );
        if (result['success'] == true) {
          widget.user.profileImages.add(result['image_url']);
          widget.onUpdate(widget.user);
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload failed')));
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      widget.user.profileImages.isNotEmpty
                          ? NetworkImage(widget.user.profileImages[0])
                          : null,
                  child:
                      widget.user.profileImages.isEmpty
                          ? const Icon(Icons.person, size: 60)
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF6B4E71),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Current Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _vanTypeController,
              decoration: const InputDecoration(
                labelText: 'Van Type (e.g., Sprinter, ProMaster)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _travelRouteController,
              decoration: const InputDecoration(
                labelText: 'Travel Route/Plans',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Profile'),
              ),
            ),

            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text('Upgrade Plan'),
              subtitle: Text(
                'Current: ${widget.user.tier.toString().split('.').last.toUpperCase()}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => UpgradeScreen(
                          user: widget.user,
                          onUpdate: widget.onUpdate,
                        ),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Verification Status'),
              subtitle: Text(
                widget.user.verificationStatus
                    .toString()
                    .split('.')
                    .last
                    .toUpperCase(),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Community Values',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '"For God so loved the world..." - John 3:16\n\nLove, generosity, and intentional connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _vanTypeController.dispose();
    _travelRouteController.dispose();
    super.dispose();
  }
}

// === UPGRADE SCREEN ===

class UpgradeScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const UpgradeScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _isProcessing = false;

  Future<void> _purchaseSubscription(String productId) async {
    setState(() => _isProcessing = true);

    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final package = offerings.current!.availablePackages.firstWhere(
          (p) => p.identifier == productId,
        );

        final purchaserInfo = await Purchases.purchasePackage(package);

        if (purchaserInfo.customerInfo.entitlements.all[productId]?.isActive ??
            false) {
          if (productId.contains('pro')) {
            widget.user.tier = UserTier.pro;
            widget.user.creditsRemaining = 25;
          } else if (productId.contains('premium')) {
            widget.user.tier = UserTier.premium;
            widget.user.creditsRemaining = 50;
          }

          widget.onUpdate(widget.user);
          _showSuccess('Subscription activated!');
        }
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _purchaseCredits(String productId, int credits) async {
    setState(() => _isProcessing = true);

    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final package = offerings.current!.availablePackages.firstWhere(
          (p) => p.identifier == productId,
        );

        await Purchases.purchasePackage(package);

        widget.user.creditsRemaining += credits;
        widget.onUpdate(widget.user);
        _showSuccess('$credits credits added!');
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body:
          _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      size: 80,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unlock More Connections',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    _SubscriptionCard(
                      title: 'Pro Plan',
                      price: '\$25/month',
                      features: const [
                        'Unlimited Swipes',
                        'See Who Likes You',
                        'Advanced Filters',
                        '25 Credits',
                      ],
                      color: Colors.blue,
                      onTap: () => _purchaseSubscription('pro'),
                    ),
                    const SizedBox(height: 16),

                    _SubscriptionCard(
                      title: 'Premium Plan',
                      price: '\$35/month',
                      features: const [
                        'Everything in Pro',
                        'Priority Builder Access',
                        'Travel Route Matching',
                        '50 Credits',
                        'Premium Badge',
                      ],
                      color: Colors.purple,
                      onTap: () => _purchaseSubscription('premium'),
                      recommended: true,
                    ),

                    const SizedBox(height: 32),
                    const Text(
                      'Credit Packs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _CreditCard(
                      title: 'Booster Pack',
                      credits: 25,
                      price: '\$40',
                      onTap: () => _purchaseCredits('credits_25', 25),
                    ),
                    const SizedBox(height: 12),

                    _CreditCard(
                      title: 'Starter Pack',
                      credits: 10,
                      price: '\$15',
                      onTap: () => _purchaseCredits('credits_10', 10),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final Color color;
  final VoidCallback onTap;
  final bool recommended;

  const _SubscriptionCard({
    required this.title,
    required this.price,
    required this.features,
    required this.color,
    required this.onTap,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          elevation: recommended ? 8 : 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 20, color: color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (recommended)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreditCard extends StatelessWidget {
  final String title;
  final int credits;
  final String price;
  final VoidCallback onTap;

  const _CreditCard({
    required this.title,
    required this.credits,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.add_shopping_cart, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$credits Credits'),
        trailing: Text(
          price,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
