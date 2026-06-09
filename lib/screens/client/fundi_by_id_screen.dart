import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/fundi_model.dart';
import '../../widgets/common/app_loader.dart';
import 'fundi_details_screen.dart';

/// Loads a FundiModel by ID, then delegates to FundiDetailsScreen.
/// Used when navigating from reels where we only have the fundiId.
class FundiByIdScreen extends StatefulWidget {
  final String fundiId;
  const FundiByIdScreen({super.key, required this.fundiId});

  @override
  State<FundiByIdScreen> createState() => _FundiByIdScreenState();
}

class _FundiByIdScreenState extends State<FundiByIdScreen> {
  FundiModel? _fundi;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFundi();
  }

  Future<void> _loadFundi() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.fundiId)
          .get();
      if (!doc.exists) {
        setState(() {
          _error = 'Fundi profile not found.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _fundi = FundiModel.fromMap(doc.data()!);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: AppLoaderCenter()),
      );
    }

    if (_error != null || _fundi == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 64, color: AppColors.grey400),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Profile not found',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return FundiDetailsScreen(fundi: _fundi!);
  }
}
