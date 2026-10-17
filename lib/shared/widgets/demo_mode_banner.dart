import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.demoBannerBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.demoBannerText,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'DEMO MODE — SIMULATED DATA',
              style: TextStyle(
                color: AppColors.demoBannerText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              context.push('/settings/simulation-controls');
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.demoBannerBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sim Controls',
                    style: TextStyle(
                      color: AppColors.demoBannerText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.tune, size: 13, color: AppColors.demoBannerText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
