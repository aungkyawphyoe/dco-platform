import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/stats/presentation/stats_format.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One KPI tile. Null [value] renders the FRD em dash; null [sub] hides the
/// sub-value line.
class StatsKpi {
  const StatsKpi({required this.label, required this.value, this.sub});

  final String label;
  final String? value;
  final String? sub;
}

/// 2-column KPI card grid (FRD stats.md common shell).
class StatsKpiGrid extends StatelessWidget {
  const StatsKpiGrid({super.key, required this.kpis});

  final List<StatsKpi> kpis;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.space.s4,
        tokens.space.s2,
        tokens.space.s4,
        tokens.space.s2,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: tokens.space.s3,
        crossAxisSpacing: tokens.space.s3,
        childAspectRatio: 1.75,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return Container(
          padding: EdgeInsets.all(tokens.space.s3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.background.card,
                tokens.background.card.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            border: Border(
              top: BorderSide(
                color: tokens.text.accent.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            boxShadow: tokens.shadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                kpi.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: tokens.text.caption),
              ),
              SizedBox(height: tokens.space.s1),
              Text(
                kpi.value ?? statsDash,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(
                  color: kpi.value == null ? tokens.text.disabled : tokens.text.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (kpi.sub != null) ...[
                SizedBox(height: 2),
                Text(
                  kpi.sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    color: tokens.text.caption,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
