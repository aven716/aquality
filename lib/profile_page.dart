import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'notification_service.dart';

// ════════════════════════════════════════════
// PROFILE PAGE
// ════════════════════════════════════════════

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _userData = doc.data();
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    NotificationService().reset();
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  bool get _isAdmin => _userData?['role'] == 'Admin';

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        if (_isAdmin) SliverToBoxAdapter(child: _buildUserManagement()),
        SliverToBoxAdapter(child: _buildSignOutButton()),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 24,
        20,
        28,
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF0055FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : Center(
                        child: Text(
                          _getInitials(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1628),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00D4FF),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 13,
                  color: Color(0xFF00D4FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          _isLoading
              ? _shimmer(width: 140, height: 22)
              : Text(
                  _userData?['fullName'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
          const SizedBox(height: 6),

          // Email
          _isLoading
              ? _shimmer(width: 180, height: 14)
              : Text(
                  _userData?['email'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
          const SizedBox(height: 12),

          // Role badge
          _isLoading
              ? _shimmer(width: 80, height: 28)
              : _RoleBadge(role: _userData?['role'] ?? 'No Role'),

          const SizedBox(height: 24),

          // Info cards
          _buildInfoCard(
            icon: Icons.person_outline_rounded,
            label: 'Full Name',
            value: _userData?['fullName'] ?? '—',
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: _userData?['email'] ?? '—',
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            icon: Icons.calendar_today_outlined,
            label: 'Date Joined',
            value: _formatDate(_userData?['createdAt']),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: const Color(0xFF00D4FF), size: 17),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.35),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Admin: User Management ────────────────────────────────
  Widget _buildUserManagement() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 13,
                      color: Color(0xFFFF6B6B),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Admin Panel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Manage Users',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4)),
                  ),
                );
              }

              final users = snapshot.data!.docs;
              return Column(
                children: users.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isCurrentUser = doc.id == _auth.currentUser?.uid;
                  return _UserTile(
                    uid: doc.id,
                    data: data,
                    isCurrentUser: isCurrentUser,
                    onRoleChanged: (newRole) async {
                      await _db.collection('users').doc(doc.id).update({
                        'role': newRole,
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Sign Out ─────────────────────────────────────────────
  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _signOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4444).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF4444).withOpacity(0.20),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFFF4444), size: 18),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFFF4444),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  String _getInitials() {
    final name = _userData?['fullName'] ?? '';
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '—';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
    return '—';
  }

  Widget _shimmer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ════════════════════════════════════════════
// ROLE BADGE
// ════════════════════════════════════════════

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  Color get _color => switch (role) {
    'Admin' => const Color(0xFFFF6B6B),
    'Owner' => const Color(0xFFFFB800),
    'Caretaker' => const Color(0xFF00FF88),
    _ => Colors.white,
  };

  IconData get _icon => switch (role) {
    'Admin' => Icons.admin_panel_settings_outlined,
    'Owner' => Icons.verified_outlined,
    'Caretaker' => Icons.handyman_outlined,
    _ => Icons.person_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 14),
          const SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// USER TILE (Admin view)
// ════════════════════════════════════════════

class _UserTile extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final bool isCurrentUser;
  final Function(String) onRoleChanged;

  const _UserTile({
    required this.uid,
    required this.data,
    required this.isCurrentUser,
    required this.onRoleChanged,
  });

  String _getInitials() {
    final name = data['fullName'] ?? '';
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final role = data['role'] ?? 'No Role';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF00D4FF).withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF0055FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data['fullName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00D4FF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  data['email'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.38),
                  ),
                ),
              ],
            ),
          ),

          // Role dropdown
          if (!isCurrentUser)
            _RoleDropdown(currentRole: role, onChanged: onRoleChanged)
          else
            _RoleBadge(role: role),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// ROLE DROPDOWN
// ════════════════════════════════════════════

class _RoleDropdown extends StatelessWidget {
  final String currentRole;
  final Function(String) onChanged;

  const _RoleDropdown({required this.currentRole, required this.onChanged});

  Color _roleColor(String role) => switch (role) {
    'Admin' => const Color(0xFFFF6B6B),
    'Owner' => const Color(0xFFFFB800),
    'Caretaker' => const Color(0xFF00FF88),
    _ => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    final roles = ['Admin', 'Owner', 'Caretaker'];
    final color = _roleColor(currentRole);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: roles.contains(currentRole) ? currentRole : null,
          hint: Text(
            'Set Role',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          isDense: true,
          dropdownColor: const Color(0xFF0E1628),
          icon: Icon(Icons.expand_more_rounded, size: 14, color: color),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          items: roles
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _roleColor(r),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
