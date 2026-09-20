import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _required = ['account', 'characters', 'inventories', 'wallet'];
  static const _optional = ['builds', 'progression', 'unlocks'];

  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) setState(() => _ctrl.text = text.trim());
  }

  Future<void> _connect() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Önce API key yapıştır.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await Gw2Api(key).tokenInfo();
      final perms = ((info['permissions'] as List?) ?? const []).map((e) => '$e').toList();
      final missing = _required.where((p) => !perms.contains(p)).toList();
      if (missing.isNotEmpty) {
        setState(() => _error = 'Key geçerli ama şu izinler eksik: ${missing.join(', ')}');
        return;
      }
      await ref.read(apiKeyProvider.notifier).save(key);
    } catch (e) {
      if (mounted) setState(() => _error = 'Key doğrulanamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Center(
              child: SizedBox(width: 72, height: 72, child: CustomPaint(painter: _EmblemPainter())),
            ),
            const SizedBox(height: 12),
            Text('Tyria Codex', textAlign: TextAlign.center, style: display(34)),
            const SizedBox(height: 6),
            const Text(
              'Karakterlerin, hesabın ve tüm wiki — tek bir yerde.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('API KEY NASIL ALINIR?'),
                  const SizedBox(height: 14),
                  const _Step(1, 'account.arena.net adresinde Uygulamalar sekmesini aç.'),
                  const SizedBox(height: 12),
                  const _Step(2, 'Yeni Key oluştur ve aşağıdaki izinleri işaretle.'),
                  const SizedBox(height: 12),
                  const _Step(3, "Oluşan key'i kopyala ve buraya yapıştır."),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => openUrl(context, 'https://account.arena.net/applications'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('account.arena.net sayfasını aç'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('API Key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSoft)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: fieldDecoration('XXXXXXXX-XXXX-XXXX-…'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: IconButton.filledTonal(
                    onPressed: _paste,
                    tooltip: 'Panodan yapıştır',
                    icon: const Icon(Icons.content_paste),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Kicker('İZİNLER', color: AppColors.muted),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _required) _PermChip(p, isRequired: true),
                for (final p in _optional) _PermChip(p, isRequired: false),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error, style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _connect,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.onGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onGold),
                      )
                    : const Text('Bağlan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
                SizedBox(width: 6),
                Text('Key yalnızca bu cihazda, şifreli olarak saklanır.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold),
          ),
          child: Text('$number',
              style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSoft)),
        ),
      ],
    );
  }
}

class _PermChip extends StatelessWidget {
  const _PermChip(this.name, {required this.isRequired});

  final String name;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isRequired ? Icons.check : Icons.add, size: 14, color: isRequired ? AppColors.green : AppColors.muted),
          const SizedBox(width: 6),
          Text(
            isRequired ? name : '$name (isteğe bağlı)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isRequired ? AppColors.textSoft : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final cx = size.width / 2;
    final cy = size.height / 2;

    Path diamond(double r) => Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();

    canvas.drawPath(diamond(size.width / 2 - 2), stroke);
    canvas.drawPath(diamond(size.width / 2 - 16), stroke);
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
