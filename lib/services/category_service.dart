import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../models/fundi_model.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Search fundis with optional nearby radius filter.
  ///
  /// [nearbyRadiusKm]: when not null, only fundis within this distance from
  ///   [clientLat]/[clientLng] are returned.  Uses Haversine formula.
  ///   Firestore doesn't support geo-radius queries directly, so we fetch a
  ///   larger set and filter client-side.
  Future<List<FundiModel>> searchFundis({
    String? category,
    String? region,
    String? district,
    String? query,
    double? minRating,
    double? nearbyRadiusKm,
    double? clientLat,
    double? clientLng,
    String  sortBy = 'recommended', // recommended | rating | jobs
    int limit = 50,
  }) async {
    Query q = _db
        .collection(FirestoreConstants.users)
        .where('role', isEqualTo: AppConstants.roleFundi)
        .where('isProfileComplete', isEqualTo: true)
        .where('accountStatus', isEqualTo: AppConstants.statusActive);

    if (category != null && category.isNotEmpty) {
      // Normalise the 'Other/Others' category:
      // Firestore can't do OR queries easily, so we fetch all if Others
      // is selected and filter client-side to catch any variant spelling.
      if (category.trim().toLowerCase() != 'other' &&
          category.trim().toLowerCase() != 'others') {
        q = q.where('category', isEqualTo: category);
      }
      // else: no category filter — fetch all and filter below
    }
    if (region != null && region.isNotEmpty) {
      q = q.where('region', isEqualTo: region);
    }
    if (district != null && district.isNotEmpty) {
      q = q.where('district', isEqualTo: district);
    }

    final snap = await q.limit(limit).get();
    // Build known-category lookup from AppConstants (canonical source).
    // This ensures the Others bucket matches exactly what the app shows.
    final knownLower = AppConstants.serviceCategories
        .map((c) => c.trim().toLowerCase())
        .toSet();

    List<FundiModel> fundis = snap.docs
        .map((d) => FundiModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();

    // If Others was selected, keep only fundis whose category is not
    // a known main category (case-insensitive, trimmed).
    if (category != null &&
        (category.trim().toLowerCase() == 'other' ||
         category.trim().toLowerCase() == 'others')) {
      fundis = fundis.where((f) {
        final cat = f.category.trim().toLowerCase();
        return cat.isEmpty ||
               cat == 'other' ||
               cat == 'others' ||
               !knownLower.contains(cat);
      }).toList();
    }

    // ── Text search filter ─────────────────────────────────────────────────
    if (query != null && query.isNotEmpty) {
      final q2 = query.toLowerCase();
      fundis = fundis
          .where((f) =>
              f.fullName.toLowerCase().contains(q2) ||
              f.category.toLowerCase().contains(q2) ||
              (f.otherCategoryName?.toLowerCase().contains(q2) ?? false) ||
              f.skills.any((s) => s.toLowerCase().contains(q2)) ||
              f.bio.toLowerCase().contains(q2))
          .toList();
    }

    // ── Rating filter ──────────────────────────────────────────────────────
    if (minRating != null) {
      fundis = fundis.where((f) => f.rating >= minRating).toList();
    }

    // ── Nearby radius filter (Haversine client-side) ───────────────────────
    // Only applied when caller provides a valid radius AND client location.
    // Fundis without lat/lng are excluded from nearby results.
    if (nearbyRadiusKm != null &&
        nearbyRadiusKm > 0 &&
        clientLat != null &&
        clientLng != null) {
      fundis = fundis.where((f) {
        if (f.latitude == null || f.longitude == null) return false;
        final distKm = _haversineKm(
          clientLat,
          clientLng,
          f.latitude!,
          f.longitude!,
        );
        return distKm <= nearbyRadiusKm;
      }).toList();
    }

    // ── Sort ───────────────────────────────────────────────────────────────
    // When nearby, sort by distance; otherwise by the existing score.
    if (nearbyRadiusKm != null &&
        nearbyRadiusKm > 0 &&
        clientLat != null &&
        clientLng != null) {
      fundis.sort((a, b) {
        final da = a.latitude != null && a.longitude != null
            ? _haversineKm(clientLat, clientLng, a.latitude!, a.longitude!)
            : double.infinity;
        final db = b.latitude != null && b.longitude != null
            ? _haversineKm(clientLat, clientLng, b.latitude!, b.longitude!)
            : double.infinity;
        return da.compareTo(db);
      });
    } else {
      switch (sortBy) {
        case 'rating':
          // High to low rating, then jobsDone as tiebreak
          fundis.sort((a, b) {
            final cmp = b.rating.compareTo(a.rating);
            return cmp != 0 ? cmp : b.jobsDone.compareTo(a.jobsDone);
          });
          break;
        case 'jobs':
          // Most jobs completed first, then rating
          fundis.sort((a, b) {
            final cmp = b.jobsDone.compareTo(a.jobsDone);
            return cmp != 0 ? cmp : b.rating.compareTo(a.rating);
          });
          break;
        default: // 'recommended'
          fundis.sort((a, b) {
            int aS = 0, bS = 0;
            if (a.isPromoted) aS += 10000;
            if (b.isPromoted) bS += 10000;
            if (a.isPremium)  aS += 5000;
            if (b.isPremium)  bS += 5000;
            aS += a.jobsDone * 80;
            bS += b.jobsDone * 80;
            aS += (a.rating * 120).round();
            bS += (b.rating * 120).round();
            aS += a.reviewCount * 12;
            bS += b.reviewCount * 12;
            return bS.compareTo(aS);
          });
      }
    }

    return fundis;
  }

  Future<List<FundiModel>> getPromotedFundis({int limit = 10}) async {
    final snap = await _db
        .collection(FirestoreConstants.users)
        .where('role', isEqualTo: AppConstants.roleFundi)
        .where('isProfileComplete', isEqualTo: true)
        .where('accountStatus', isEqualTo: AppConstants.statusActive)
        .where('promotionStatus', isEqualTo: AppConstants.promotionActive)
        .limit(limit)
        .get();

    final fundis = snap.docs
        .map((d) => FundiModel.fromMap(d.data()))
        .where((f) => f.isPromoted)
        .toList();

    fundis.sort((a, b) {
      final score = b.jobsDone.compareTo(a.jobsDone);
      if (score != 0) return score;
      return b.rating.compareTo(a.rating);
    });

    return fundis;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Haversine distance in km
  // ─────────────────────────────────────────────────────────────────────────
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0; // Earth radius in km
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
