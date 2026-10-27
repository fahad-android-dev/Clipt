import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_theme.dart';
import 'live_session_view_model.dart';
import '../../routing/routes.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key, required this.viewModel});

  final LiveSessionViewModel viewModel;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  LiveSessionViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.load().then((_) {
      // Resuming a session that is already running.
      if (mounted && _vm.isLive) WakelockPlus.enable();
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _onStart() async {
    HapticFeedback.mediumImpact();
    await _vm.start();
    if (_vm.isLive) WakelockPlus.enable(); // keep the screen on while playing
  }

  void _onMark() {
    HapticFeedback.mediumImpact();
    _vm.mark();
  }

  Future<void> _confirmEnd() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: Text('You marked ${_vm.markCount} moments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _vm.end();
    if (!mounted) return;
    context.pushReplacement(Routes.reviewPath(_vm.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_vm.notFound) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This session no longer exists.')),
          );
        }
        // A session that hasn't started can be left freely. A live one asks
        // before ending.
        return PopScope(
          canPop: !_vm.isLive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmEnd();
          },
          child: Scaffold(
            appBar: AppBar(title: Text(_vm.title)),
            body: SafeArea(child: _content()),
          ),
        );
      },
    );
  }

  Widget _content() {
    final live = _vm.isLive;
    final error = _vm.errorMessage;
    final String status;
    if (error != null) {
      status = error;
    } else if (!live) {
      status = 'Press Start when you begin recording';
    } else if (_vm.markCount == 0) {
      status = 'Tap when something cool happens';
    } else {
      status = '${_vm.markCount} marked, last at ${_vm.lastMark}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _ElapsedClock(elapsed: () => _vm.elapsed),
          const SizedBox(height: 8),
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: error == null ? AppColors.muted : AppColors.accent,
            ),
          ),
          Expanded(
            child: Center(
              child: live
                  ? _RoundButton(
                      label: 'Mark',
                      color: AppColors.accent,
                      onPressed: _onMark,
                      fireOnTouchDown: true, // fires on touch, not on release
                    )
                  : _RoundButton(
                      label: 'Start',
                      color: AppColors.ink,
                      onPressed: _onStart,
                    ),
            ),
          ),
          if (live) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final t in LiveSessionViewModel.tags)
                  ChoiceChip(
                    label: Text(t),
                    selected: _vm.selectedTag == t,
                    showCheckmark: false,
                    backgroundColor: AppColors.card,
                    selectedColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.line),
                    labelStyle: TextStyle(
                      color: _vm.selectedTag == t
                          ? Colors.white
                          : AppColors.ink,
                    ),
                    onSelected: (_) => _vm.selectTag(t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.line),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _confirmEnd,
                child: const Text('End session'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Redraws only the clock four times a second. The time itself comes from
/// the view model, so the rest of the screen isn't rebuilt.
class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.elapsed});

  final Duration Function() elapsed;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatClock(widget.elapsed().inMilliseconds),
      style: AppTheme.mono(size: 64),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.fireOnTouchDown = false,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  /// Mark reacts the instant a finger lands. Start waits for a normal tap.
  final bool fireOnTouchDown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: fireOnTouchDown ? (_) => onPressed() : null,
          onTap: fireOnTouchDown ? () {} : onPressed,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
