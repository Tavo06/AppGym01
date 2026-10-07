import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/achievement_widgets.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/responsive.dart';
import '../../widgets/workout_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().refreshProfile();
        context.read<ProgressProvider>().refresh();
      }
    });
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.logout_rounded,
      title: '¿Deseas cerrar sesión?',
      message: 'Tu progreso y tus datos quedan guardados en tu cuenta.',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      // Al cambiar el usuario, `main.dart` limpia el entrenamiento y las
      // estadísticas en memoria, y el router lleva al Login.
      await authProvider.logout();
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      showAppMessage(context, 'No se pudo cerrar sesión: $error');
    }
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final progressProvider = context.watch<ProgressProvider>();
    final progress = progressProvider.progress;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Configuración',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            auth.refreshProfile(),
            progressProvider.refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            MaxWidth(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(auth: auth, profile: auth.profile),
                  const SizedBox(height: 20),
                  if (progress == null && progressProvider.error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.error,
                        ),
                        title: Text(progressProvider.error!),
                        trailing: TextButton(
                          onPressed: progressProvider.refresh,
                          child: const Text('Reintentar'),
                        ),
                      ),
                    )
                  else
                    StatGrid(
                      minTileWidth: 120,
                      children: [
                        ProgressCard(
                          icon: Icons.fitness_center_rounded,
                          label: 'Entrenamientos',
                          value: progress == null
                              ? '—'
                              : '${progress.totalWorkouts}',
                        ),
                        ProgressCard(
                          icon: Icons.emoji_events_rounded,
                          label: 'Récords',
                          color: AppColors.amber,
                          value: progress == null
                              ? '—'
                              : '${progress.recordCount}',
                        ),
                        ProgressCard(
                          icon: Icons.scale_rounded,
                          label: 'Volumen',
                          color: AppColors.violet,
                          value: progress == null
                              ? '—'
                              : Formatters.formatVolume(progress.totalVolume),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Logros'),
                  const _AchievementsCard(),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Cuenta'),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _ProfileAction(
                          icon: Icons.edit_outlined,
                          title: 'Editar perfil',
                          subtitle:
                              'Nombre, fecha de nacimiento, objetivo y '
                              'nivel',
                          onTap: () => context.push('/profile/edit'),
                        ),
                        // Solo las cuentas con contraseña pueden cambiarla.
                        if (auth.hasPasswordSignIn) ...[
                          const Divider(height: 1, indent: 64),
                          _ProfileAction(
                            icon: Icons.password_rounded,
                            title: 'Cambiar contraseña',
                            onTap: () => context.push('/change-password'),
                          ),
                        ],
                        const Divider(height: 1, indent: 64),
                        _ProfileAction(
                          icon: Icons.palette_outlined,
                          title: 'Apariencia y configuración',
                          subtitle: _themeLabel(
                            context.watch<ThemeProvider>().mode,
                          ),
                          onTap: _openSettings,
                        ),
                        const Divider(height: 1, indent: 64),
                        _ProfileAction(
                          icon: Icons.logout_rounded,
                          title: 'Cerrar sesión',
                          color: AppColors.error,
                          trailing: _loggingOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: _loggingOut ? null : _logout,
                        ),
                      ],
                    ),
                  ),
                  if (progressProvider.workouts.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Actividad reciente',
                      actionLabel: 'Ver progreso',
                      onAction: () => context.go('/progreso'),
                    ),
                    for (final session in progressProvider.workouts.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: WorkoutCard(session: session),
                      ),
                  ] else if (progress != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Aún no hay actividad. Tus entrenamientos aparecerán '
                      'aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Tema claro',
  ThemeMode.dark => 'Tema oscuro',
  ThemeMode.system => 'Tema del sistema',
};

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.auth, required this.profile});

  final AuthProvider auth;
  final UserModel? profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = auth.displayName;
    final email = auth.user?.email ?? '';
    final photoUrl = profile?.photoUrl;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    Widget fallback() => CircleAvatar(
      radius: 36,
      backgroundColor: palette.primarySoft,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: context.palette.primaryText,
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            if (photoUrl != null && photoUrl.isNotEmpty)
              ClipOval(
                child: Image.network(
                  photoUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback(),
                ),
              )
            else
              fallback(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: palette.textSecondary,
                    ),
                  ),
                  if (profile?.goal != null ||
                      profile?.level != null ||
                      profile?.birthDate != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (profile?.goal != null)
                          _Chip(
                            icon: Icons.flag_outlined,
                            label: profile!.goal!,
                          ),
                        if (profile?.level != null)
                          _Chip(
                            icon: Icons.trending_up_rounded,
                            label: profile!.level!,
                          ),
                        if (_age(profile?.birthDate) != null)
                          _Chip(
                            icon: Icons.cake_outlined,
                            label: '${_age(profile?.birthDate)} años',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int? _age(String? birthDate) {
    final date = DateTime.tryParse(birthDate ?? '');
    if (date == null) return null;
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Acceso a Mis logros con el total conseguido y los más recientes.
class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard();

  @override
  Widget build(BuildContext context) {
    final achievements = context.watch<AchievementProvider>();
    final latest = achievements.unlockedDefinitions.take(5).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.logros),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileAction(
              icon: Icons.emoji_events_rounded,
              title: 'Mis logros',
              color: AppColors.amber,
              subtitle:
                  '${achievements.unlockedCount} de ${achievements.total} '
                  'conseguidos',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.logros),
            ),
            if (latest.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final definition in latest)
                      Tooltip(
                        message: definition.title,
                        child: AchievementBadge(
                          definition: definition,
                          unlocked: true,
                          size: 38,
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
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effective = color ?? palette.textPrimary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color ?? AppColors.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: effective,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
      trailing:
          trailing ??
          Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;
    final providers = [
      if (auth.hasPasswordSignIn) 'Correo y contraseña',
      if (auth.hasGoogleSignIn) 'Google',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configuración',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Apariencia',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Oscuro'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text('Sistema'),
              ),
            ],
            selected: {theme.mode},
            onSelectionChanged: (value) => theme.setMode(value.first),
          ),
          const SizedBox(height: 24),
          Text(
            'Cuenta',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _SettingsRow(
            icon: Icons.shield_outlined,
            title: 'Inicio de sesión',
            value: providers.isEmpty ? '—' : providers.join(' y '),
          ),
          _SettingsRow(
            icon: auth.isEmailVerified
                ? Icons.verified_user_rounded
                : Icons.gpp_maybe_rounded,
            title: 'Correo verificado',
            value: auth.isEmailVerified ? 'Sí' : 'No',
          ),
          if ((auth.profile?.phone ?? '').isNotEmpty || auth.isPhoneVerified)
            _SettingsRow(
              icon: auth.isPhoneVerified
                  ? Icons.phonelink_lock_rounded
                  : Icons.phone_iphone_rounded,
              title: auth.isPhoneVerified
                  ? 'Teléfono verificado'
                  : 'Teléfono (sin verificar)',
              value: auth.user?.phoneNumber ?? auth.profile?.phone ?? '—',
            ),
          if (user?.metadata.lastSignInTime != null)
            _SettingsRow(
              icon: Icons.schedule_rounded,
              title: 'Último acceso',
              value: Formatters.formatDateTime(user!.metadata.lastSignInTime!),
            ),
          const _SettingsRow(
            icon: Icons.info_outline_rounded,
            title: 'Aplicación',
            value: '${AppConstants.appName} 1.0.0',
          ),
          const SizedBox(height: 14),
          Text(
            'Tus datos se guardan de forma segura en tu cuenta. La '
            'contraseña la gestiona Firebase Authentication y nunca se '
            'almacena en la base de datos.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
