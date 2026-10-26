import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_theme.dart';
import 'live_session_view_model.dart';

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
    _vm.load();
    WakelockPlus.enable(); // keep the screen on while playing
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
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
    context.pop();
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
        return PopScope(
          canPop: false,
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
    final error = _vm.errorMessage;
    final status = error ??
        (_vm.markCount == 0
            ? 'Tap when something cool happens'
            : '${_vm.markCount} marked, last at ${_vm.lastMark}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _ElapsedClock(elapsed: () => _vm.elapsed),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              color: error == null ? AppColors.muted : AppColors.accent,
            ),
          ),
          Expanded(child: Center(child: _MarkButton(onMark: _onMark))),
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
                    color: _vm.selectedTag == t ? Colors.white : AppColors.ink,
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

class _MarkButton extends StatelessWidget {
  const _MarkButton({required this.onMark});

  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: (_) => onMark(), // fires on touch, not on release
          onTap: () {},
          child: const Center(
            child: Text(
              'Mark',
              style: TextStyle(
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