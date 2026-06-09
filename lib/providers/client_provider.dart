import 'package:flutter/foundation.dart';
import '../models/fundi_model.dart';
import '../services/category_service.dart';
import '../services/location_service.dart';

/// Distance options for the "Nearby" filter.
///
/// [auto] = auto-radius (show all within ~15 km).
/// The others are explicit km caps.
enum NearbyOption { anywhere, auto, km1, km3, km5, km10 }

extension NearbyOptionX on NearbyOption {
  /// Returns the radius in km, or null for "anywhere".
  double? get radiusKm {
    switch (this) {
      case NearbyOption.anywhere: return null;
      case NearbyOption.auto:     return 15.0;
      case NearbyOption.km1:      return 1.0;
      case NearbyOption.km3:      return 3.0;
      case NearbyOption.km5:      return 5.0;
      case NearbyOption.km10:     return 10.0;
    }
  }

  String get label {
    switch (this) {
      case NearbyOption.anywhere: return 'Anywhere';
      case NearbyOption.auto:     return 'Nearby (Auto)';
      case NearbyOption.km1:      return 'Within 1 km';
      case NearbyOption.km3:      return 'Within 3 km';
      case NearbyOption.km5:      return 'Within 5 km';
      case NearbyOption.km10:     return 'Within 10 km';
    }
  }

  bool get isNearby => this != NearbyOption.anywhere;
}

class ClientProvider extends ChangeNotifier {
  final CategoryService _categoryService;
  final LocationService? _locationService;

  ClientProvider({
    required CategoryService categoryService,
    LocationService? locationService,
  })  : _categoryService = categoryService,
        _locationService = locationService;

  List<FundiModel> _fundis = [], _promotedFundis = [];
  bool _isLoading = false, _isSearching = false;
  bool _isRequestingLocation = false;
  String? _errorMessage, _selectedCategory, _selectedRegion, _selectedDistrict;
  String _searchQuery = '';
  double? _minRating;
  String  _sortBy = 'recommended'; // recommended | rating | jobs

  // ── Location ───────────────────────────────────────────────────────────────
  double? _clientLat;
  double? _clientLng;

  // ── Nearby filter ──────────────────────────────────────────────────────────
  NearbyOption _nearbyOption = NearbyOption.anywhere;
  String? _locationError;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<FundiModel> get fundis          => _fundis;
  List<FundiModel> get promotedFundis  => _promotedFundis;
  bool   get isLoading                 => _isLoading;
  bool   get isSearching               => _isSearching;
  bool   get isRequestingLocation      => _isRequestingLocation;
  String? get errorMessage             => _errorMessage;
  String? get locationError            => _locationError;
  String? get selectedCategory         => _selectedCategory;
  String? get selectedRegion           => _selectedRegion;
  NearbyOption get nearbyOption        => _nearbyOption;
  String       get sortBy              => _sortBy;
  bool   get isNearbyActive            => _nearbyOption.isNearby;
  double? get clientLat                => _clientLat;
  double? get clientLng                => _clientLng;

  bool get hasActiveFilters =>
      _selectedCategory != null ||
      _selectedRegion    != null ||
      _selectedDistrict  != null ||
      _minRating         != null ||
      _nearbyOption.isNearby;

  // ── Load dashboard ─────────────────────────────────────────────────────────

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _fetchLocationSilently();
      final results = await Future.wait([
        _categoryService.searchFundis(),
        _categoryService.getPromotedFundis(),
      ]);
      _fundis = results[0];
      _promotedFundis = results[1];
    } catch (e) {
      _errorMessage = 'Failed to load fundis.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch location silently on startup for distance display.
  /// Never crashes — LocationError is swallowed.
  void _fetchLocationSilently() {
    if (_locationService == null || _clientLat != null) return;
    _locationService!.detectLocation().then((result) {
      _clientLat = result.latitude;
      _clientLng = result.longitude;
      notifyListeners();
    }).catchError((_) {});
  }

  // ── Nearby ─────────────────────────────────────────────────────────────────

  /// Called when user selects a NearbyOption in the filter sheet.
  /// If option requires location, requests it first.
  Future<void> setNearbyOption(NearbyOption option) async {
    if (option == _nearbyOption) return;

    // If switching to a nearby option and we don't have location yet, request it.
    if (option.isNearby && _clientLat == null) {
      final ok = await _requestLocationForNearby();
      if (!ok) return; // location denied — stay on current option
    }

    _nearbyOption = option;
    await _performSearch();
  }

  /// Request location explicitly (user chose a nearby option).
  /// Returns true if location was obtained.
  Future<bool> _requestLocationForNearby() async {
    if (_locationService == null) {
      _locationError = 'Location service unavailable.';
      notifyListeners();
      return false;
    }
    _isRequestingLocation = true;
    _locationError = null;
    notifyListeners();

    try {
      final result = await _locationService!.detectLocation();
      _clientLat = result.latitude;
      _clientLng = result.longitude;
      _locationError = null;
      return true;
    } catch (e) {
      if (e is LocationError) {
        _locationError = LocationService.errorMessage(e);
      } else {
        _locationError = 'Could not get your location.';
      }
      return false;
    } finally {
      _isRequestingLocation = false;
      notifyListeners();
    }
  }

  // ── Search / filter ────────────────────────────────────────────────────────

  Future<void> search(String query) async {
    _searchQuery = query;
    await _performSearch();
  }

  Future<void> applyFilters({
    String? category,
    String? region,
    String? district,
    double? minRating,
    NearbyOption? nearbyOption,
    String? sortBy,
  }) async {
    _selectedCategory = category;
    _selectedRegion   = region;
    _selectedDistrict = district;
    _minRating        = minRating;
    if (sortBy != null) _sortBy = sortBy;

    if (nearbyOption != null && nearbyOption != _nearbyOption) {
      if (nearbyOption.isNearby && _clientLat == null) {
        final ok = await _requestLocationForNearby();
        if (!ok) {
          // Revert to anywhere if location denied
          _nearbyOption = NearbyOption.anywhere;
          await _performSearch();
          return;
        }
      }
      _nearbyOption = nearbyOption;
    }

    await _performSearch();
  }

  Future<void> clearFilters() async {
    _selectedCategory = null;
    _selectedRegion   = null;
    _selectedDistrict = null;
    _minRating        = null;
    _nearbyOption     = NearbyOption.anywhere;
    _searchQuery      = '';
    _locationError    = null;
    _sortBy           = 'recommended';
    await loadDashboard();
  }

  Future<void> selectCategory(String? category) async {
    _selectedCategory = category;
    await _performSearch();
  }

  Future<void> _performSearch() async {
    _isSearching = true;
    notifyListeners();
    try {
      _fundis = await _categoryService.searchFundis(
        query:          _searchQuery,
        category:       _selectedCategory,
        region:         _selectedRegion,
        district:       _selectedDistrict,
        minRating:      _minRating,
        nearbyRadiusKm: _nearbyOption.radiusKm,
        clientLat:      _clientLat,
        clientLng:      _clientLng,
        sortBy:         _sortBy,
      );
    } catch (e) {
      _errorMessage = 'Search failed.';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
}
