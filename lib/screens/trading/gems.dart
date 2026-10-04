part of '../trading_screen.dart';

/// two way gem exchange for any amount
class _GemCalculator extends ConsumerStatefulWidget {
  const _GemCalculator();

  @override
  ConsumerState<_GemCalculator> createState() => _GemCalculatorState();
}

class _GemCalculatorState extends ConsumerState<_GemCalculator> {
  final _gems = TextEditingController(text: '400');
  final _gold = TextEditingController(text: '100');
  int _gemAmount = 400;
  int _goldAmount = 100;

  /// typing 10000 would ask the exchange five times, the last number is enough
  Timer? _debounce;

  void _later(void Function() update) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(update);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _gems.dispose();
    _gold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final coins = ref.watch(exchangeProvider('gems:$_gemAmount'));
    final gems = ref.watch(exchangeProvider('coins:${_goldAmount * 10000}'));

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('gem_calculator').toUpperCase()),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _gems,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (v) => setState(() => _gemAmount = int.tryParse(v) ?? 0),
                  onChanged: (v) => _later(() => _gemAmount = int.tryParse(v) ?? 0),
                  decoration: fieldDecoration(s.t('gems')),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward, size: 18, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: coins.when(
                  data: (value) => CoinText(value, size: 16),
                  loading: () => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  ),
                  error: (_, __) => const Text('-', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _gold,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (v) => setState(() => _goldAmount = int.tryParse(v) ?? 0),
                  onChanged: (v) => _later(() => _goldAmount = int.tryParse(v) ?? 0),
                  decoration: fieldDecoration(s.t('gold')),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward, size: 18, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: gems.when(
                  data: (value) => Text(s.t('n_gems', {'n': fmtInt(value)}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  loading: () => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  ),
                  error: (_, __) => const Text('-', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.t('exchange_note'), style: const TextStyle(fontSize: 11, color: AppColors.hint)),
        ],
      ),
    );
  }
}
