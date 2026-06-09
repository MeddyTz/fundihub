import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // ── App ────────────────────────────────────────────────────────────────────
  static const String appName = 'FundiHub';
  static const String appVersion = '1.0.0';

  // ── Roles ──────────────────────────────────────────────────────────────────
  static const String roleClient = 'client';
  static const String roleFundi = 'fundi';
  static const String roleAdmin = 'admin';

  // ── Categories ─────────────────────────────────────────────────────────────
  static const String categoryOthers = 'Other';

  static const List<String> serviceCategories = [
    // ── Trades & Construction ──────────────
    'Plumber',
    'Electrician',
    'Carpenter',
    'Mason / Builder',
    'Welder',
    'Painter',
    'Tiler',
    'Roofing Specialist',
    'Ceiling Installer',
    'Window Installer',
    'Aluminium Fabricator',
    'Furniture Maker',
    // ── Home & Facilities ──────────────────
    'Cleaner',
    'House Maid',
    'Gardener',
    'Pest Control',
    'Borehole Technician',
    'Water Pump Technician',
    'Locksmith',
    'Laundry Services',
    // ── Appliance & Vehicle Repair ─────────
    'Mechanic',
    'Bike Mechanic',
    'Tyre Service',
    'AC Technician',
    'Fridge Repair',
    'Washing Machine Repair',
    'TV Repair',
    'Appliance Repair',
    // ── Tech & IT ──────────────────────────
    'Phone Repair',
    'Computer Repair',
    'Network Technician',
    'IT / Tech Support',
    'CCTV Installer',
    'CCTV & Smart Home',
    'Solar Installer',
    'Web Developer',
    'Mobile App Developer',
    // ── Creative & Media ───────────────────
    'Photographer',
    'Videographer',
    'Graphic Designer',
    'Interior Designer',
    'Sign Writer',
    'Branding Services',
    'Printing Services',
    'Digital Marketing',
    'Social Media Manager',
    // ── Beauty & Personal Care ─────────────
    'Beautician / Barber',
    'Barber',
    'Hair Stylist',
    'Makeup Artist',
    'Nail Technician',
    // ── Fashion ────────────────────────────
    'Tailor',
    'Fashion Designer',
    // ── Events & Entertainment ─────────────
    'Event Planner',
    'MC / Host',
    'DJ',
    'Sound Technician',
    // ── Food & Hospitality ─────────────────
    'Chef',
    'Baker',
    // ── Education & Care ───────────────────
    'Tutor',
    'Babysitter',
    'Nurse / Home Care',
    'Gym Trainer',
    'Swimming Coach',
    'Translator',
    // ── Transport & Logistics ──────────────
    'Driver / Delivery',
    'Delivery Rider',
    'Moving Services',
    'Truck Loader',
    // ── Security & Other ───────────────────
    'Security Guard',
    'Other',
  ];

  static const List<String> homeCategories = [
    'Plumber',
    'Electrician',
    'Carpenter',
    'Cleaner',
    'Mechanic',
    'Painter',
    'Beautician / Barber',
    'Mason / Builder',
  ];

  /// Single source of truth for All Categories page.
  /// Must contain the same entries as serviceCategories.
  static const Map<String, List<String>> categoryGroups = {
    'Trades & Construction': [
      'Plumber', 'Electrician', 'Carpenter', 'Mason / Builder',
      'Welder', 'Painter', 'Tiler', 'Roofing Specialist',
      'Ceiling Installer', 'Window Installer',
      'Aluminium Fabricator', 'Furniture Maker',
    ],
    'Home & Facilities': [
      'Cleaner', 'House Maid', 'Gardener', 'Pest Control',
      'Borehole Technician', 'Water Pump Technician',
      'Locksmith', 'Laundry Services',
    ],
    'Appliance & Vehicle Repair': [
      'Mechanic', 'Bike Mechanic', 'Tyre Service',
      'AC Technician', 'Fridge Repair', 'Washing Machine Repair',
      'TV Repair', 'Appliance Repair',
    ],
    'Tech & IT': [
      'Phone Repair', 'Computer Repair', 'Network Technician',
      'IT / Tech Support', 'CCTV Installer', 'CCTV & Smart Home',
      'Solar Installer', 'Web Developer', 'Mobile App Developer',
    ],
    'Creative & Media': [
      'Photographer', 'Videographer', 'Graphic Designer',
      'Interior Designer', 'Sign Writer', 'Branding Services',
      'Printing Services', 'Digital Marketing', 'Social Media Manager',
    ],
    'Beauty & Personal Care': [
      'Beautician / Barber', 'Barber', 'Hair Stylist',
      'Makeup Artist', 'Nail Technician',
    ],
    'Fashion': [
      'Tailor', 'Fashion Designer',
    ],
    'Events & Entertainment': [
      'Event Planner', 'MC / Host', 'DJ', 'Sound Technician',
    ],
    'Food, Education & Care': [
      'Chef', 'Baker', 'Tutor', 'Babysitter',
      'Nurse / Home Care', 'Gym Trainer', 'Swimming Coach',
      'Translator',
    ],
    'Transport, Security & Other': [
      'Driver / Delivery', 'Delivery Rider', 'Moving Services',
      'Truck Loader', 'Security Guard', 'Other',
    ],
  };

  static const List<String> tanzaniaRegions = [
    'Dar es Salaam',
    'Arusha',
    'Mwanza',
    'Dodoma',
    'Mbeya',
    'Morogoro',
    'Tanga',
    'Kilimanjaro',
    'Kagera',
    'Mara',
    'Shinyanga',
    'Tabora',
    'Singida',
    'Iringa',
    'Rukwa',
    'Kigoma',
    'Lindi',
    'Mtwara',
    'Ruvuma',
    'Pwani',
    'Zanzibar North',
    'Zanzibar South',
    'Zanzibar West',
    'Pemba North',
    'Pemba South',
  ];

  // ── Plans ──────────────────────────────────────────────────────────────────
  static const String planFree = 'free';
  static const String planPremium = 'premium';
  static const int premiumSubscriptionFee = 35000;

  // ── Account status ─────────────────────────────────────────────────────────
  static const String statusActive = 'active';
  static const String statusSuspended = 'suspended';
  static const String statusBlocked = 'blocked';
  static const String statusPending = 'pending';
  static const String statusIncomplete = 'incomplete';

  // ── Booking status ─────────────────────────────────────────────────────────
  static const String bookingPending = 'pending';
  static const String bookingAccepted = 'accepted';

  static const String bookingAgreementConfirmed =
      'agreement_confirmed';

  static const String bookingInProgress = 'in_progress';

  static const String bookingAwaitingConfirmation =
      'awaiting_confirmation';

  static const String bookingCompletionDisputed =
      'completion_disputed';

  static const String bookingCompleted = 'completed';
  static const String bookingRejected = 'rejected';
  static const String bookingCancelled = 'cancelled';
  static const String bookingExpired = 'expired';

  // ── Payment types ──────────────────────────────────────────────────────────
  static const String paymentJobFee = 'job_fee';
  static const String paymentSubscription = 'subscription';
  static const String paymentPromotion = 'promotion';

  // ── Payment status ─────────────────────────────────────────────────────────
  static const String paymentPending = 'pending';
  static const String paymentSubmitted = 'submitted';
  static const String paymentApproved = 'approved';
  static const String paymentConfirmed = 'confirmed';
  static const String paymentRejected = 'rejected';

  // ── Fees ───────────────────────────────────────────────────────────────────
  static const int jobCompletionFee = 2500;

  static const String feeUnpaid = 'unpaid';
  static const String feePaid = 'paid';
  static const String feeNone = 'none';

  // ── Wallet lock reasons ────────────────────────────────────────────────────
  static const String lockNone = 'none';
  static const String lockActiveJob = 'active_job';
  static const String lockJobFeeUnpaid = 'job_fee_unpaid';

  // ── Promotion / Boost ──────────────────────────────────────────────────────
  static const String promotionPending = 'pending';
  static const String promotionActive = 'active';
  static const String promotionInactive = 'inactive';

  // ── Reel status ────────────────────────────────────────────────────────────
  static const String reelPendingApproval = 'pending';
  static const String reelApproved = 'approved';
  static const String reelRejected = 'rejected';

  // ── Message types ──────────────────────────────────────────────────────────
  static const String msgText = 'text';
  static const String msgImage = 'image';
  static const String msgVoice = 'voice';
  static const String msgSystem = 'system';
  static const String msgLocation = 'location';

  // ── Chat ───────────────────────────────────────────────────────────────────
  static const int chatMessagePageSize = 30;

  // ── Company payment info ───────────────────────────────────────────────────
  static const String companyPaymentNumber = '0754289831';

  static const String companyPaymentNumberLabel =
      'FundiHub Payment Number';

  // ── Contact unlock helper ──────────────────────────────────────────────────
  static bool isContactUnlocked(String status) {
    switch (status.toLowerCase()) {
      case bookingAccepted:
      case bookingAgreementConfirmed:
      case bookingInProgress:
      case bookingAwaitingConfirmation:
      case bookingCompletionDisputed:
        return true;
      default:
        return false;
    }
  }

  static bool isChatOpen(String status) {
    switch (status.toLowerCase()) {
      case bookingAccepted:
      case bookingAgreementConfirmed:
      case bookingInProgress:
      case bookingAwaitingConfirmation:
      case bookingCompletionDisputed:
        return true;
      default:
        return false;
    }
  }

  static String normalizeBookingStatus(String status) {
    final value = status.trim().toLowerCase();

    switch (value) {
      case 'pending':
        return bookingPending;

      case 'accepted':
        return bookingAccepted;

      case 'agreement_confirmed':
      case 'agreement confirmed':
        return bookingAgreementConfirmed;

      case 'in_progress':
      case 'in progress':
        return bookingInProgress;

      case 'awaiting_confirmation':
      case 'awaiting confirmation':
      case 'awaiting client confirmation':
        return bookingAwaitingConfirmation;

      case 'completion_disputed':
      case 'completion disputed':
        return bookingCompletionDisputed;

      case 'completed':
        return bookingCompleted;

      case 'rejected':
        return bookingRejected;

      case 'cancelled':
      case 'canceled':
        return bookingCancelled;

      case 'expired':
        return bookingExpired;

      default:
        return value;
    }
  }

  static String bookingStatusLabel(String status) {
    switch (normalizeBookingStatus(status)) {
      case bookingPending:
        return 'Pending';

      case bookingAccepted:
        return 'Accepted';

      case bookingAgreementConfirmed:
        return 'Accepted';

      case bookingInProgress:
        return 'In Progress';

      case bookingAwaitingConfirmation:
        return 'Awaiting Client Confirmation';

      case bookingCompletionDisputed:
        return 'Completion Disputed';

      case bookingCompleted:
        return 'Completed';

      case bookingRejected:
        return 'Rejected';

      case bookingCancelled:
        return 'Cancelled';

      case bookingExpired:
        return 'Expired';

      default:
        return status;
    }
  }

  // ── Theme colors ───────────────────────────────────────────────────────────
  static const MaterialColor primarySwatch = Colors.blue;
}