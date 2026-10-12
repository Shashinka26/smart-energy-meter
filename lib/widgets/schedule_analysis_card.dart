import 'package:flutter/material.dart';

import '../services/appliance_config.dart';
import '../services/schedule_model_service.dart';
import '../theme/app_colors.dart';

class ScheduleAnalysisCard extends StatefulWidget {
  const ScheduleAnalysisCard({
    super.key,
    required this.applianceType,
    required this.isOwner,
    required this.onApply,
    required this.onCreateManual,
  });

  final ApplianceType applianceType;
  final bool isOwner;
  final Future<void> Function(ScheduleSuggestion suggestion) onApply;
  final VoidCallback onCreateManual;

  @override
  State<ScheduleAnalysisCard> createState() => _ScheduleAnalysisCardState();
}

class _ScheduleAnalysisCardState extends State<ScheduleAnalysisCard> {
  final ScheduleModelService _scheduleModelService = ScheduleModelService();

  ScheduleSuggestion? _cachedSuggestion;
  bool _isInitialLoad = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  @override
  void didUpdateWidget(covariant ScheduleAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.applianceType != widget.applianceType) {
      _loadAnalysis();
    }
  }

  Future<void> _loadAnalysis() async {
    final hadCachedData = _cachedSuggestion != null;

    if (!hadCachedData) {
      setState(() => _isInitialLoad = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    final result = await _scheduleModelService.analyzeUsage(
      applianceType: widget.applianceType,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _cachedSuggestion = result;
      _isInitialLoad = false;
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad && _cachedSuggestion == null) {
      return _loadingCard();
    }

    final suggestion = _cachedSuggestion;

    if (suggestion == null) {
      return _emptyCard();
    }

    return Stack(
      children: [
        _suggestionCard(suggestion),
        if (_isRefreshing)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _loadingCard() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(0.06)),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(0.06)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Usage Analysis',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Collecting usage history from your smart meter. '
            'Check back after at least 3 days of readings for schedule suggestions.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard(ScheduleSuggestion suggestion) {
    final showPeakStats =
        suggestion.kind != ScheduleSuggestionKind.insufficientData;
    final showSavings =
        suggestion.canApply && suggestion.estimatedMonthlySavings > 0;
    final showManualAction = suggestion.kind == ScheduleSuggestionKind.advisory ||
        suggestion.kind == ScheduleSuggestionKind.lowPower;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Usage Analysis',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (showPeakStats) ...[
            const SizedBox(height: 14),
            _analysisRow(
              'Peak usage',
              '${suggestion.peakHours} (${suggestion.peakAveragePower.toStringAsFixed(1)} W avg)',
            ),
            const SizedBox(height: 8),
            _analysisRow(
              'Low usage',
              '${suggestion.lowHours} (${suggestion.lowAveragePower.toStringAsFixed(1)} W avg)',
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.primary, 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.suggestionTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  suggestion.tariffAdvice,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion.applianceAdvice,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                if (showSavings) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Save ~Rs. ${suggestion.estimatedMonthlySavings.toStringAsFixed(0)}/month',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
                if (showPeakStats) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Based on ${suggestion.dataDaysUsed} day${suggestion.dataDaysUsed == 1 ? '' : 's'} of meter data',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (suggestion.canApply) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.isOwner ? () => widget.onApply(suggestion) : null,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Apply Suggestion'),
              ),
            ),
          ] else if (showManualAction) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.isOwner ? widget.onCreateManual : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Manual Schedule'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _analysisRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
