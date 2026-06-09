import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/location_service.dart';
import 'app_text_field.dart';
import '../../widgets/common/app_loader.dart';

/// A reusable location picker that replaces all Region/District dropdowns.
/// Shows three text fields (Region, District, Area) plus a "Use My Location" button.
/// On GPS tap, auto-fills all fields from detected address.
class LocationPicker extends StatefulWidget {
  final TextEditingController regionCtrl;
  final TextEditingController districtCtrl;
  final TextEditingController areaCtrl;
  final ValueChanged<double?>? onLatChanged;
  final ValueChanged<double?>? onLngChanged;
  final ValueChanged<String>? onAddressChanged;
  final bool areaOptional;

  const LocationPicker({
    super.key,
    required this.regionCtrl,
    required this.districtCtrl,
    required this.areaCtrl,
    this.onLatChanged,
    this.onLngChanged,
    this.onAddressChanged,
    this.areaOptional = true,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  bool _detecting  = false;
  bool _detected   = false;
  String? _selectedRegion;  // drives the dropdown

  Future<void> _detect() async {
    if (_detecting) return;
    setState(() => _detecting = true);

    try {
      final result = await context.read<LocationService>().detectLocation();
      final parsed = _parseAddress(result.detectedAddress);

      widget.regionCtrl.text = parsed.region;
      widget.districtCtrl.text = parsed.district;
      if (parsed.area.isNotEmpty) widget.areaCtrl.text = parsed.area;
      // Sync dropdown to detected region
      final detected = AppConstants.tanzaniaRegions
          .where((r) => r.toLowerCase() ==
              parsed.region.toLowerCase())
          .firstOrNull;
      if (detected != null) {
        setState(() => _selectedRegion = detected);
      }

      widget.onLatChanged?.call(result.latitude);
      widget.onLngChanged?.call(result.longitude);
      widget.onAddressChanged?.call(result.detectedAddress);

      setState(() => _detected = true);

      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Location detected! Please confirm the fields below.',
        );
      }
    } on LocationError catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          LocationService.errorMessage(e),
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Could not detect location. Enter manually.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  _AddressParts _parseAddress(String address) {
    String region = '';
    final lower = address.toLowerCase();

    for (final r in AppConstants.tanzaniaRegions) {
      if (lower.contains(r.toLowerCase())) {
        region = r;
        break;
      }
    }

    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) =>
            p.isNotEmpty &&
            p.toLowerCase() != 'tanzania' &&
            p.toLowerCase() != 'united republic of tanzania' &&
            (region.isEmpty || p.toLowerCase() != region.toLowerCase()))
        .toList();

    final district = parts.isNotEmpty ? parts.first : '';
    final area = parts.length > 1 ? parts[1] : '';

    return _AddressParts(region: region, district: district, area: area);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // GPS button
        _GpsButton(
          detecting: _detecting,
          detected: _detected,
          onTap: _detect,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        // Region dropdown
        DropdownButtonFormField<String>(
          value: _selectedRegion,
          decoration: InputDecoration(
            labelText: 'Region',
            prefixIcon:
                const Icon(Icons.map_outlined, color: AppColors.primary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
          hint: const Text('Select your region'),
          isExpanded: true,
          items: AppConstants.tanzaniaRegions
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() => _selectedRegion = v);
            widget.regionCtrl.text = v ?? '';
          },
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please select your region' : null,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        // District text field
        AppTextField(
          controller: widget.districtCtrl,
          label: 'District',
          hint: 'e.g. Kinondoni',
          prefixIcon: Icons.location_city_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter your district' : null,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        // Area / Street text field
        AppTextField(
          controller: widget.areaCtrl,
          label: widget.areaOptional ? 'Area / Street (Optional)' : 'Area / Street',
          hint: 'e.g. Sinza, Morocco',
          prefixIcon: Icons.place_outlined,
          textInputAction: TextInputAction.done,
          validator: widget.areaOptional
              ? null
              : (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter your area'
                  : null,
        ),
      ],
    );
  }
}

class _GpsButton extends StatelessWidget {
  final bool detecting;
  final bool detected;
  final VoidCallback onTap;

  const _GpsButton({
    required this.detecting,
    required this.detected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: detecting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLG,
          vertical: AppTheme.spaceMD,
        ),
        decoration: BoxDecoration(
          color: detected
              ? AppColors.successSurface
              : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: detected
                ? AppColors.success.withOpacity(0.4)
                : AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: detected ? AppColors.success : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: detecting
                  ? const AppLoader(size: 22, color: Colors.white)
                  : Icon(
                      detected
                          ? Icons.check_circle_rounded
                          : Icons.my_location_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detecting
                        ? 'Detecting location...'
                        : detected
                            ? 'Location detected!'
                            : 'Use My Current Location',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: detected
                          ? AppColors.success
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detecting
                        ? 'Please wait'
                        : detected
                            ? 'Fields filled — please confirm below'
                            : 'Auto-fill region, district & area via GPS',
                    style: AppTextStyles.caption.copyWith(
                      color: detected
                          ? AppColors.success.withOpacity(0.8)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!detecting)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: detected ? AppColors.success : AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressParts {
  final String region;
  final String district;
  final String area;

  const _AddressParts({
    required this.region,
    required this.district,
    required this.area,
  });
}
