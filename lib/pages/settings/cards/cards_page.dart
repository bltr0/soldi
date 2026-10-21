import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_log.dart';
import '../../../services/security/backup_crypto.dart';
import '../../../services/security/biometric_key.dart';
import '../../../services/security/card_vault.dart';
import '../../../services/security/secure_window.dart';
import '../../../ui/device.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../ui/widgets/passphrase_dialog.dart';

/// The card vault. Asks for the owner again on every visit, shows nothing
/// until then, blocks screenshots while open, and closes itself when the
/// app goes to the background or is left idle.
class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage>
    with WidgetsBindingObserver {
  static const _idleTimeout = Duration(minutes: 2);

  final _vault = const CardVault();
  CardVaultSession? _session;
  List<StoredCard>? get _cards => _session?.cards;
  final _revealed = <String>{};
  Timer? _idle;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    SecureWindow.setSecure(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle?.cancel();
    _session?.close();
    SecureWindow.setSecure(false);
    super.dispose();
  }

  Future<void> _unlock() async {
    try {
      final session = await _openSession();
      if (!mounted) return session?.close();
      if (session == null) {
        Navigator.pop(context);
        return;
      }
      setState(() => _session = session);
      // Only now: the unlock prompts themselves pause the app briefly.
      WidgetsBinding.instance.addObserver(this);
      _touch();
    } catch (e, stack) {
      AppLog.error('cards', 'Opening the vault failed: $e', stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot open cards: $e')));
        Navigator.pop(context);
      }
    }
  }

  /// Fingerprint/face first, the backup passphrase otherwise; sets the
  /// passphrase up on the very first visit. Null when the user gives up.
  Future<CardVaultSession?> _openSession() async {
    final biometrics = await BiometricKey.status() == BiometricStatus.ok;
    if (!await _vault.isSetUp) {
      if (!mounted) return null;
      final chosen = await choosePassphrase(context);
      if (chosen == null) return null;
      final session = await _vault.setUp(chosen.$2);
      if (biometrics) await _tryEnroll(session);
      return session;
    }

    String? notice;
    if (biometrics && await _vault.hasBiometricUnlock) {
      try {
        return await _vault.unlockWithBiometrics('Open your cards');
      } on BiometricException catch (e) {
        if (e.error == BiometricError.invalidated) {
          notice =
              'Fingerprints changed on this phone: enter the passphrase once '
              'to turn fingerprint unlock back on.';
        }
      }
    }

    var retry = false;
    while (true) {
      if (!mounted) return null;
      final passphrase = await askPassphrase(
        context,
        title: 'Open your cards',
        message: notice ?? 'Enter your backup passphrase.',
        error: retry ? 'Wrong passphrase' : null,
      );
      if (passphrase == null) return null;
      try {
        final session = await _vault.unlockWithPassphrase(passphrase);
        if (biometrics && !await _vault.hasBiometricUnlock) {
          await _tryEnroll(session);
        }
        return session;
      } on WrongPassphrase {
        retry = true;
      }
    }
  }

  Future<void> _tryEnroll(CardVaultSession session) async {
    try {
      await session.enrollBiometrics('Unlock cards with your fingerprint');
    } on BiometricException catch (e) {
      AppLog.info('cards', 'Fingerprint unlock not enrolled: ${e.error.name}');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _close();
    }
  }

  void _touch() {
    _idle?.cancel();
    _idle = Timer(_idleTimeout, _close);
  }

  /// Leaves the vault and anything opened from it.
  void _close() {
    if (!mounted) return;
    final route = _route;
    final navigator = Navigator.of(context);
    if (route != null && route.isActive) {
      navigator.popUntil((r) => r == route);
      navigator.pop();
    }
  }

  Future<void> _save(List<StoredCard> cards) async {
    await _session?.save(cards);
    if (mounted) setState(() {});
  }

  Future<void> _edit([StoredCard? card]) async {
    _touch();
    final result = await Navigator.of(context).push<StoredCard>(
      MaterialPageRoute(builder: (_) => _CardEditPage(card: card)),
    );
    if (result == null || !mounted) return;
    final cards = [...?_cards];
    final index = cards.indexWhere((c) => c.id == result.id);
    if (index >= 0) {
      cards[index] = result;
    } else {
      cards.add(result);
    }
    await _save(cards);
  }

  void _delete(StoredCard card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${card.label}?'),
        content: const Text('The card is removed from this phone for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _save([...?_cards]..removeWhere((c) => c.id == card.id));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _copy(String label, String value) {
    _touch();
    SecureWindow.copySecret(value);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied, cleared in 30 s')));
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final cards = _cards;
    return Listener(
      onPointerDown: (_) => _touch(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Cards'),
          actions: [
            if (cards != null)
              IconButton(
                tooltip: 'Add a card',
                icon: const Icon(Icons.add_rounded),
                onPressed: _edit,
              ),
          ],
        ),
        body: cards == null
            ? Center(
                child: Icon(
                  Icons.lock_rounded,
                  size: 48,
                  color: visual.textSecondary,
                ),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  Sizes.lg,
                  Sizes.md,
                  Sizes.lg,
                  MediaQuery.paddingOf(context).bottom + Sizes.xl,
                ),
                children: [
                  if (cards.isEmpty) ...[
                    const SizedBox(height: Sizes.xxl),
                    Icon(
                      Icons.credit_card_rounded,
                      size: 48,
                      color: visual.textSecondary,
                    ),
                    const SizedBox(height: Sizes.md),
                    Text(
                      'No card yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: visual.textPrimary,
                      ),
                    ),
                    const SizedBox(height: Sizes.lg),
                    Center(
                      child: AccentButton(
                        label: 'Add a card',
                        onPressed: _edit,
                      ),
                    ),
                  ],
                  for (final card in cards) ...[
                    _CardTile(
                      card: card,
                      revealed: _revealed.contains(card.id),
                      onToggle: () => setState(() {
                        _touch();
                        if (!_revealed.remove(card.id)) _revealed.add(card.id);
                      }),
                      onCopy: _copy,
                      onEdit: () => _edit(card),
                      onDelete: () => _delete(card),
                    ),
                    const SizedBox(height: Sizes.lg),
                  ],
                  const SizedBox(height: Sizes.md),
                  Text(
                    'Encrypted with a key only your fingerprint (on this '
                    'phone) or your backup passphrase can open. Backups carry '
                    'them still encrypted. Screenshots are blocked here, '
                    'copied values are wiped after 30 s, and the vault closes '
                    'when you leave the app or after 2 minutes idle. CVV '
                    'codes are never stored.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: visual.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.revealed,
    required this.onToggle,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final StoredCard card;
  final bool revealed;
  final VoidCallback onToggle;
  final void Function(String label, String value) onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static List<Color> _colors(CardNetwork network) => switch (network) {
    CardNetwork.visa => const [Color(0xFF1A1F71), Color(0xFF3B4BC8)],
    CardNetwork.mastercard => const [Color(0xFF2B2B2B), Color(0xFFEB5E28)],
    CardNetwork.amex => const [Color(0xFF006FCF), Color(0xFF4FB3E8)],
    CardNetwork.unionPay => const [Color(0xFF7A1018), Color(0xFF00447C)],
    _ => const [Color(0xFF3A3A4A), Color(0xFF6B6B80)],
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const white = Colors.white;
    final dim = white.withValues(alpha: 0.7);
    final mono = textTheme.titleLarge?.copyWith(
      color: white,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget field(String label, String shown, String? copyValue) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall?.copyWith(color: dim)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shown,
              style: textTheme.titleMedium?.copyWith(
                color: white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (copyValue != null && copyValue.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: dim,
                tooltip: 'Copy $label',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () => onCopy(label, copyValue),
              ),
          ],
        ),
      ],
    );

    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _colors(card.network),
          ),
        ),
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(Sizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.label,
                        style: textTheme.titleMedium?.copyWith(
                          color: white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      card.network.label,
                      style: textTheme.labelLarge?.copyWith(color: dim),
                    ),
                    PopupMenuButton<String>(
                      iconColor: white,
                      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Sizes.md),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          revealed ? card.formattedNumber : card.maskedNumber,
                          style: mono,
                        ),
                      ),
                    ),
                    if (revealed)
                      IconButton(
                        color: dim,
                        tooltip: 'Copy number',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () => onCopy('Number', card.number),
                      ),
                  ],
                ),
                const SizedBox(height: Sizes.md),
                Wrap(
                  spacing: Sizes.xl,
                  runSpacing: Sizes.sm,
                  children: [
                    if (card.expiry.isNotEmpty)
                      field(
                        card.isExpired ? 'Expired' : 'Expires',
                        card.expiry,
                        revealed ? card.expiry : null,
                      ),
                    if (card.pin.isNotEmpty)
                      field(
                        'PIN',
                        revealed ? card.pin : '••••',
                        revealed ? card.pin : null,
                      ),
                    if (card.holder.isNotEmpty)
                      field('Holder', card.holder, null),
                  ],
                ),
                if (card.note.isNotEmpty) ...[
                  const SizedBox(height: Sizes.sm),
                  Text(
                    card.note,
                    style: textTheme.bodySmall?.copyWith(color: dim),
                  ),
                ],
                const SizedBox(height: Sizes.sm),
                Text(
                  revealed ? 'Tap to hide' : 'Tap to show',
                  style: textTheme.labelSmall?.copyWith(color: dim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardEditPage extends StatefulWidget {
  const _CardEditPage({this.card});

  final StoredCard? card;

  @override
  State<_CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<_CardEditPage> {
  late final _label = TextEditingController(text: widget.card?.label);
  late final _holder = TextEditingController(text: widget.card?.holder);
  late final _number = TextEditingController(
    text: widget.card?.formattedNumber,
  );
  late final _expiry = TextEditingController(text: widget.card?.expiry);
  late final _pin = TextEditingController(text: widget.card?.pin);
  late final _note = TextEditingController(text: widget.card?.note);
  bool _showPin = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _holder, _number, _expiry, _pin, _note]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  String get _digits => _number.text.replaceAll(RegExp(r'\D'), '');

  void _submit() {
    final digits = _digits;
    final expiry = _expiry.text.trim();
    final pin = _pin.text.trim();
    String? error;
    if (_label.text.trim().isEmpty) {
      error = 'Give the card a name';
    } else if (digits.length < 12 || digits.length > 19) {
      error = 'A card number has 12 to 19 digits';
    } else if (expiry.isNotEmpty &&
        !RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(expiry)) {
      error = 'Expiry is MM/YY';
    } else if (pin.isNotEmpty && !RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      error = 'The PIN code has 4 to 6 digits';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      StoredCard(
        id: widget.card?.id ?? StoredCard.newId(),
        label: _label.text.trim(),
        holder: _holder.text.trim(),
        number: digits,
        expiry: expiry,
        pin: pin,
        note: _note.text.trim(),
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final digits = _digits;
    final luhnWarning = digits.length >= 12 && !isValidCardNumber(digits)
        ? 'This number fails the card checksum, check for a typo'
        : null;
    // Keeps typed secrets out of keyboard learning and autofill.
    const private = (
      autocorrect: false,
      enableSuggestions: false,
      learning: false,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.card == null ? 'New card' : 'Edit card'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Sizes.lg,
          Sizes.lg,
          Sizes.lg,
          MediaQuery.paddingOf(context).bottom + Sizes.xl,
        ),
        children: [
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Name', hint: 'e.g. Boursorama Visa'),
          ),
          const SizedBox(height: Sizes.md),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            autocorrect: private.autocorrect,
            enableSuggestions: private.enableSuggestions,
            enableIMEPersonalizedLearning: private.learning,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              _CardNumberFormatter(),
            ],
            onChanged: (_) => setState(() {}),
            decoration: _decoration(
              'Card number',
              suffix: digits.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(Sizes.md),
                      child: Text(CardNetwork.of(digits).label),
                    ),
            ).copyWith(helperText: luhnWarning),
          ),
          const SizedBox(height: Sizes.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiry,
                  keyboardType: TextInputType.number,
                  autocorrect: private.autocorrect,
                  enableSuggestions: private.enableSuggestions,
                  enableIMEPersonalizedLearning: private.learning,
                  inputFormatters: [_ExpiryFormatter()],
                  decoration: _decoration('Expiry', hint: 'MM/YY'),
                ),
              ),
              const SizedBox(width: Sizes.md),
              Expanded(
                child: TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  obscureText: !_showPin,
                  autocorrect: private.autocorrect,
                  enableSuggestions: private.enableSuggestions,
                  enableIMEPersonalizedLearning: private.learning,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: _decoration(
                    'PIN code',
                    suffix: IconButton(
                      icon: Icon(
                        _showPin
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () => setState(() => _showPin = !_showPin),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.md),
          TextField(
            controller: _holder,
            textCapitalization: TextCapitalization.characters,
            decoration: _decoration('Cardholder (optional)'),
          ),
          const SizedBox(height: Sizes.md),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Note (optional)'),
          ),
          const SizedBox(height: Sizes.sm),
          Text(
            'No CVV field on purpose: the 3 digits on the back are never '
            'stored.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
          ),
          if (_error != null) ...[
            const SizedBox(height: Sizes.md),
            Text(_error!, style: TextStyle(color: visual.negative)),
          ],
          const SizedBox(height: Sizes.xl),
          Center(
            child: AccentButton(
              label: 'Save',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// Spaces the digits as they are typed, keeping the cursor at the end.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatCardNumber(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// `1226` → `12/26`.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    // Deleting the slash also deletes the digit before it.
    if (oldValue.text.endsWith('/') &&
        newValue.text.length < oldValue.text.length) {
      digits = digits.substring(
        0,
        digits.length - 1 < 0 ? 0 : digits.length - 1,
      );
    }
    final text = digits.length >= 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
