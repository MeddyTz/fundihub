import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

class LangProvider extends ChangeNotifier {
  static const String _key = 'app_locale';
  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  bool get isSwahili => _locale.languageCode == 'sw';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'sw') {
      _locale = const Locale('sw');
      notifyListeners();
    }
  }

  Future<void> setEnglish() async {
    _locale = const Locale('en');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'en');
  }

  Future<void> setSwahili() async {
    _locale = const Locale('sw');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'sw');
  }

  Future<void> toggle() async {
    if (isSwahili) {
      await setEnglish();
    } else {
      await setSwahili();
    }
  }
}

extension LangContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}

class AppL10n {
  final bool sw;
  const AppL10n({required this.sw});

  static AppL10n of(BuildContext context) {
    final lang = context.watch<LangProvider>();
    return AppL10n(sw: lang.isSwahili);
  }

  // ── Navigation ────────────────────────────────────────────────────────
  String get home => sw ? 'Nyumbani' : 'Home';
  String get dashboard => sw ? 'Dashibodi' : 'Dashboard';
  String get bookings => sw ? 'Maombi' : 'Bookings';
  String get jobs => sw ? 'Kazi' : 'Jobs';
  String get chats => sw ? 'Ujumbe' : 'Chats';
  String get messages => sw ? 'Ujumbe' : 'Messages';
  String get profile => sw ? 'Wasifu' : 'Profile';
  String get wallet => sw ? 'Malipo' : 'Payments';
  String get boost => sw ? 'Tangaza' : 'Boost';
  String get notifications => sw ? 'Arifa' : 'Notifications';
  String get reels => sw ? 'Reels' : 'Reels';
  String get workShowcase => sw ? 'Onyesho la Kazi' : 'Work Showcase';

  // ── Actions ────────────────────────────────────────────────────────────
  String get accept => sw ? 'Kubali' : 'Accept';
  String get reject => sw ? 'Kataa' : 'Reject';
  String get cancel => sw ? 'Ghairi' : 'Cancel';
  String get confirm => sw ? 'Thibitisha' : 'Confirm';
  String get pay => sw ? 'Lipa' : 'Pay';
  String get submit => sw ? 'Wasilisha' : 'Submit';
  String get save => sw ? 'Hifadhi' : 'Save';
  String get saveChanges => sw ? 'Hifadhi Mabadiliko' : 'Save Changes';
  String get edit => sw ? 'Hariri' : 'Edit';
  String get done => sw ? 'Imekamilika' : 'Done';
  String get send => sw ? 'Tuma' : 'Send';
  String get search => sw ? 'Tafuta' : 'Search';
  String get filter => sw ? 'Chuja' : 'Filter';
  String get signOut => sw ? 'Toka' : 'Sign Out';
  String get login => sw ? 'Ingia' : 'Login';
  String get signIn => sw ? 'Ingia' : 'Sign In';
  String get register => sw ? 'Jisajili' : 'Register';
  String get createAccount => sw ? 'Fungua Akaunti' : 'Create Account';
  String get readAll => sw ? 'Soma Zote' : 'Read all';
  String get shareApp => sw ? 'Shiriki App' : 'Share App';
  String get back => sw ? 'Rudi' : 'Back';
  String get close => sw ? 'Funga' : 'Close';
  String get continue_ => sw ? 'Endelea' : 'Continue';
  String get add => sw ? 'Ongeza' : 'Add';
  String get remove => sw ? 'Ondoa' : 'Remove';
  String get clearAll => sw ? 'Futa Zote' : 'Clear All';
  String get applyFilters => sw ? 'Tumia Vichujio' : 'Apply Filters';
  String get retry => sw ? 'Jaribu Tena' : 'Retry';
  String get openChat => sw ? 'Fungua Mazungumzo' : 'Open Chat';
  String get call => sw ? 'Piga Simu' : 'Call';
  String get viewAll => sw ? 'Ona Zote' : 'View All';
  String get viewProfile => sw ? 'Ona Wasifu' : 'View Profile';
  String get bookNow => sw ? 'Omba Sasa' : 'Book Now';

  // ── Status labels ──────────────────────────────────────────────────────
  String get pending => sw ? 'Inasubiri' : 'Pending';
  String get active => sw ? 'Inafanya Kazi' : 'Active';
  String get completed => sw ? 'Imekamilika' : 'Completed';
  String get locked => sw ? 'Imefungwa' : 'Locked';
  String get freePlan => sw ? 'Mpango Bure' : 'Free Plan';
  String get premium => sw ? 'Premium' : 'Premium';

  // ── Stats labels ───────────────────────────────────────────────────────
  String get avgRating => sw ? 'Ukadiriaji' : 'Avg Rating';
  String get reviews => sw ? 'Maoni' : 'Reviews';
  String get feesLabel => sw ? 'Malipo' : 'Payments';
  String get noJobsYet => sw ? 'Hakuna Kazi Bado' : 'No Jobs Yet';

  // ── Greetings ──────────────────────────────────────────────────────────
  String get greetingMorning => sw ? 'Habari za asubuhi 👋' : 'Good morning 👋';
  String get greetingAfternoon =>
      sw ? 'Habari za mchana 👋' : 'Good afternoon 👋';
  String get greetingEvening => sw ? 'Habari za jioni 👋' : 'Good evening 👋';
  String get goodMorning => sw ? 'Habari za asubuhi' : 'Good morning';
  String get goodAfternoon => sw ? 'Habari za mchana' : 'Good afternoon';
  String get goodEvening => sw ? 'Habari za jioni' : 'Good evening';
  String get findSkilled =>
      sw ? 'Pata wataalamu mahiri\nkaribu nawe' : 'Find skilled professionals\nnear you';

  // ── Auth ───────────────────────────────────────────────────────────────
  String get welcomeBack => sw ? 'Karibu Tena' : 'Welcome Back';
  String get emailLabel => sw ? 'Barua Pepe' : 'Email';
  String get passwordLabel => sw ? 'Nywila' : 'Password';
  String get forgotPassword => sw ? 'Umesahau Nywila?' : 'Forgot Password?';
  String get noAccount => sw ? 'Huna akaunti?' : "Don't have an account?";
  String get hasAccount => sw ? 'Una akaunti?' : 'Already have an account?';
  String get fullNameLabel => sw ? 'Jina Kamili' : 'Full Name';
  String get phoneLabel => sw ? 'Nambari ya Simu' : 'Phone Number';

  // ── Boost ─────────────────────────────────────────────────────────────
  String get boostProfile => sw ? 'Tangaza Wasifu' : 'Boost Profile';
  String get boostScreen => sw ? 'Tangaza Wasifu' : 'Boost Profile';
  String get boostPlans => sw ? 'Mipango ya Kutangaza' : 'Boost Plans';
  String get premiumOption => sw ? 'Chaguo la Premium' : 'Premium Option';
  String get selcomPayments => sw ? 'Malipo ya Selcom' : 'Selcom Payments';
  String get dailyBoost => sw ? 'Tangaza Kwa Siku' : 'Daily Boost';
  String get dailyBoostSub =>
      sw ? 'Weka wasifu wako juu kwa saa 24.' : 'Feature your profile for 24 hours.';
  String get weeklyBoost => sw ? 'Tangaza Kwa Wiki' : 'Weekly Boost';
  String get weeklyBoostSub =>
      sw ? 'Pata umaarufu zaidi kwa siku 7.' : 'Get better visibility for 7 days.';
  String get monthlyBoost => sw ? 'Tangaza Kwa Mwezi' : 'Monthly Boost';
  String get monthlyBoostSub =>
      sw ? 'Kaa juu kwa siku 30.' : 'Stay near the top for 30 days.';
  String get popular => sw ? 'Maarufu' : 'Popular';
  String get premiumPlan => sw ? 'Mpango wa Premium' : 'Premium Plan';
  String get premiumPlanSub =>
      sw ? 'Kazi bila kikwazo na bila kizuizi cha ada ya kukamilisha.'
          : 'Unlimited jobs and no completion fee lock.';
  String get boostHeroTitle =>
      sw ? 'Tangaza Wasifu Wako' : 'Boost Your Fundi Profile';
  String get boostHeroSub =>
      sw ? 'Onekana juu ya matokeo ya utafutaji na upate maombi zaidi ya kazi.'
          : 'Appear higher in search results and get more booking requests.';
  String get selcomNotice =>
      sw ? 'Malipo ya kutangaza yako katika hali ya majaribio.'
          : 'Boost payments are currently in mock/testing mode.';
  String get premiumPlanSub2 =>
      sw ? 'Kazi bila kikwazo na bila kizuizi cha ada ya kukamilisha.'
          : 'Unlimited jobs and no completion fee lock.';

  // ── Reels ─────────────────────────────────────────────────────────────
  String get uploadReel =>
      sw ? 'Pakia Video ya Kazi' : 'Upload Work Video';
  String get reelSubmitted => sw ? 'Reel Imetumwa!' : 'Reel Submitted!';
  String get reelUnderReview =>
      sw ? 'Video yako inakaguliwa na timu yetu.'
          : 'Your video is being reviewed by our team.';
  String get reelApprovedNotif =>
      sw ? 'Reel yako imeidhinishwa na inaweza kuonekana sasa.'
          : 'Your reel was approved and is now live.';
  String get reelRejectedNotif =>
      sw ? 'Reel yako ilikataliwa. Tafadhali angalia na ujaribu tena.'
          : 'Your reel was rejected. Please review and try again.';

  // ── Booking ────────────────────────────────────────────────────────────
  String get bookAFundi => sw ? 'Omba Fundi' : 'Book a Fundi';
  String get jobDetails => sw ? 'Maelezo ya Kazi' : 'Job Details';
  String get describeJob => sw ? 'Elezea kazi' : 'Describe the job';
  String get jobLocationLabel => sw ? 'Mahali pa Kazi' : 'Job Location';
  String get additionalDetails =>
      sw ? 'Maelezo ya Ziada (Hiari)' : 'Additional Details (Optional)';
  String get additionalHint =>
      sw ? 'mf. Karibu na lango la bluu, ghorofa ya pili...'
          : 'e.g. Near the blue gate, second floor...';
  String get howBookingWorks =>
      sw ? 'Jinsi Ombi Linavyofanya Kazi' : 'How Booking Works';
  String get sendBookingRequest =>
      sw ? 'Tuma Ombi la Kazi' : 'Send Booking Request';

  // ── Fundi profile labels ────────────────────────────────────────────────
  String get myPortfolio => sw ? 'Picha za Kazi' : 'My Portfolio';
  String get portfolioSubtitle =>
      sw ? 'Onyesha kazi yako ili kuvutia wateja zaidi.'
          : 'Showcase your work to attract more clients.';
  String get addPortfolioPhotos =>
      sw ? 'Ongeza Picha za Kazi' : 'Add Portfolio Photos';
  String get tapToAddPhotos =>
      sw ? 'Gusa kuongeza picha za kazi yako'
          : 'Tap to add photos of your work';
  String get addPortfolioBtn =>
      sw ? 'Ongeza picha za kazi' : 'Add portfolio photos';
  String get editPortfolioBtn => sw ? 'Hariri picha za kazi' : 'Edit portfolio';
  String get myReviews => sw ? 'Maoni Yangu' : 'My Reviews';
  String get noReviewsYet => sw ? 'Bado Hakuna Maoni' : 'No Reviews Yet';
  String get reviewsAppear =>
      sw ? 'Maoni ya wateja yataonekana hapa baada ya kazi.'
          : 'Client reviews appear here after jobs.';
  String get signOutLabel => sw ? 'Toka' : 'Sign Out';

  // ── Fundi details ─────────────────────────────────────────────────────
  String get ratingLabel => sw ? 'Ukadiriaji' : 'Rating';
  String get jobsDoneLabel => sw ? 'Kazi Zilizofanywa' : 'Jobs Done';
  String get reviewsLabel => sw ? 'Maoni' : 'Reviews';
  String get aboutLabel => sw ? 'Kuhusu' : 'About';
  String get reviewsCount => sw ? 'Maoni' : 'Reviews';
  String get jobsDoneInfo =>
      sw ? 'Kazi Zilizofanywa zinaonyesha miadi iliyokamilika kwenye FundiHub.'
          : 'Jobs Done shows completed bookings on FundiHub.';

  // ── Nearby ────────────────────────────────────────────────────────────
  String get fundisNearMe => sw ? 'Mafundi Karibu Nawe' : 'Fundis Near Me';
  String get findingFundis =>
      sw ? 'Inatafuta mafundi karibu nawe...' : 'Finding fundis near you...';
  String get noFundisNearby => sw ? 'Hakuna Mafundi Karibu' : 'No Fundis Found';
  String get noFundisNearbySubtitle =>
      sw ? 'Hakuna mafundi karibu. Jaribu kutafuta kwa aina badala yake.'
          : 'No fundis found nearby. Try searching by category instead.';
  String get failedToLoad =>
      sw ? 'Imeshindwa kupakia mafundi. Tafadhali jaribu tena.'
          : 'Failed to load fundis. Please try again.';

  // ── Review ────────────────────────────────────────────────────────────
  String get rateYourExperience =>
      sw ? 'Kadiria Uzoefu Wako' : 'Rate Your Experience';
  String get yourRating => sw ? 'Ukadiriaji Wako' : 'Your Rating';
  String get yourReview => sw ? 'Maoni Yako' : 'Your Review';
  String get reviewHint =>
      sw ? 'Waambie wengine kuhusu uzoefu wako na fundi huyu...'
          : 'Tell others about your experience with this fundi...';
  String get onlyClientCanReview =>
      sw ? 'Mteja aliyeunda ombi hili peke yake anaweza kuandika maoni.'
          : 'Only the client who created this booking can review it.';
  String get reviewAfterComplete =>
      sw ? 'Unaweza kuandika maoni baada ya kazi kukamilika.'
          : 'You can only review after the job is completed.';
  String get reviewMinChars =>
      sw ? 'Tafadhali andika angalau herufi 10' : 'Please write at least 10 characters';
  String get reviewSubmittedThanks =>
      sw ? 'Maoni yametumwa. Asante!' : 'Review submitted. Thank you!';
  String get checkingReview =>
      sw ? 'Inakagua maoni...' : 'Checking review...';
  String get submittingReview =>
      sw ? 'Inawasilisha maoni...' : 'Submitting review...';

  // ── Payment / Wallet ──────────────────────────────────────────────────
  String get walletPayments =>
      sw ? 'Historia ya Malipo' : 'Payment History';
  String get overviewTab => sw ? 'Muhtasari' : 'Overview';
  String get historyTab => sw ? 'Historia' : 'History';
  String get totalPaid => sw ? 'Jumla Iliyolipwa' : 'Total Paid';
  String get planLabel => sw ? 'Mpango' : 'Plan';
  String get noPaymentsYet => sw ? 'Hakuna Malipo Bado' : 'No Payments Yet';
  String get pendingConfirmation =>
      sw ? 'Inasubiri Uthibitisho' : 'Pending Confirmation';
  String get quickActions => sw ? 'Vitendo vya Haraka' : 'Quick Actions';
  String get upgradePremium => sw ? 'Panda kwa Premium' : 'Upgrade to Premium';
  String get upgradePremiumSub =>
      sw ? 'Kazi bila kikwazo na bila ada za kazi.'
          : 'Unlimited jobs and no per-job fees.';
  String get boostMyProfile => sw ? 'Tangaza Wasifu Wangu' : 'Boost My Profile';
  String get boostMyProfileSub =>
      sw ? 'Onekana juu ya matokeo ya utafutaji.'
          : 'Appear higher in search results.';

  // ── Account locked (kept for compat, not shown in UI now) ─────────────
  String get accountLocked => sw ? 'Akaunti Imefungwa' : 'Account Locked';
  String get actionRequired => sw ? 'Hatua Inahitajika' : 'Action Required';
  String get completeActiveJob =>
      sw ? 'Kamilisha kazi yako ya sasa' : 'Complete your active job';
  String get payFeeNow => sw ? 'Lipa Ada Sasa' : 'Pay Fee Now';
  String get lockActiveJob =>
      sw ? 'Una kazi inayoendelea. Imaliza kabla ya kupokea maombi mapya.'
          : 'You have an active job. Complete it before accepting new bookings.';
  String get lockFeePending =>
      sw ? 'Lazima ulipe ada ya kukamilisha kazi ya Tsh 2,500 kabla ya kupokea kazi mpya.'
          : 'You must pay Tsh 2,500 job completion fee before accepting new jobs.';
  String get lockDefault =>
      sw ? 'Akaunti yako imefungwa kwa muda.' : 'Your account is temporarily locked.';

  // ── Booking detail ────────────────────────────────────────────────────
  String get bookingCreated => sw ? 'Ombi Limeundwa' : 'Booking Created';
  String get fundiAccepted => sw ? 'Fundi Amekubali' : 'Fundi Accepted';
  String get agreementConfirmedLabel =>
      sw ? 'Makubaliano Yamethibitishwa' : 'Agreement Confirmed';
  String get jobStarted => sw ? 'Kazi Imeanza' : 'Job Started';
  String get jobCompleted => sw ? 'Kazi Imekamilika' : 'Job Completed';
  String get bookingRejectedLabel =>
      sw ? 'Ombi Limekataliwa' : 'Booking Rejected';
  String get bookingCancelledLabel =>
      sw ? 'Ombi Limeghairiwa' : 'Booking Cancelled';
  String get statusWaitingFundi =>
      sw ? 'Inasubiri fundi kujibu' : 'Waiting for fundi to respond';
  String get statusBothMustAgree =>
      sw ? 'Ombi limekubaliwa. Pande zote lazima zikubaliane kabla ya mawasiliano kufunguliwa.'
          : 'Booking accepted. Both sides must agree before contact is unlocked.';
  String get statusBothAgreed =>
      sw ? 'Pande zote zimekubaliana. Mawasiliano yamefunguliwa wakati kazi inaendelea.'
          : 'Both parties agreed. Contact is unlocked while the job is active.';
  String get statusInProgress =>
      sw ? 'Kazi inaendelea sasa hivi' : 'Job is currently in progress';
  String get statusRejectedDefault =>
      sw ? 'Ombi limekataliwa' : 'Booking rejected';
  String get statusCancelledDefault =>
      sw ? 'Ombi limeghairiwa' : 'Booking cancelled';
  String get whatsappCallUnlock =>
      sw ? 'WhatsApp & Simu vinafunguliwa pande zote zinapokubaliana'
          : 'WhatsApp & Call unlock after both parties confirm agreement';
  String get agreeToJobTerms =>
      sw ? 'Kubali Masharti ya Kazi' : 'Agree to Job Terms';
  String get thankYouReview =>
      sw ? 'Asante kwa kusaidia wateja wengine kuchagua mafundi wanaoaminika.'
          : 'Thank you for helping other clients choose trusted fundis.';
  String get rejectJobTitle => sw ? 'Kataa Kazi?' : 'Reject Job?';
  String get rejectJobMessage =>
      sw ? 'Ghairi ombi hili la kazi?' : 'Reject this booking request?';
  String get completeJobTitle => sw ? 'Maliza Kazi?' : 'Complete Job?';
  String get completeJobMessage =>
      sw ? 'Weka kazi hii kama imekamilika?'
          : 'Mark this job as completed?';
  String get cancelJobTitle => sw ? 'Ghairi Kazi?' : 'Cancel Job?';
  String get cancelJobMessage =>
      sw ? 'Je, una uhakika unataka kughairi kazi hii?'
          : 'Are you sure you want to cancel this job?';
  String get acceptJobLabel => sw ? 'Kubali Kazi' : 'Accept Job';
  String get rejectJobLabel => sw ? 'Kataa Kazi' : 'Reject Job';
  String get markInProgressLabel => sw ? 'Anza Kazi' : 'Mark as In Progress';
  String get markCompleteLabel => sw ? 'Maliza Kazi' : 'Mark Job as Complete';
  String get cancelJobLabel => sw ? 'Ghairi Kazi' : 'Cancel Job';
  String get updatingLabel => sw ? 'Inasasisha...' : 'Updating...';
  String get couldNotOpenPhone =>
      sw ? 'Imeshindwa kufungua simu' : 'Could not open phone app';
  String get couldNotOpenWhatsapp =>
      sw ? 'Imeshindwa kufungua WhatsApp' : 'Could not open WhatsApp';
  String get clientPending =>
      sw ? 'Mteja Anasubiri' : 'Client Pending';
  String get fundiPending => sw ? 'Fundi Anasubiri' : 'Fundi Pending';
  String get clientPendingLabel =>
      sw ? 'Mteja Anasubiri' : 'Client Pending';
  String get fundiPendingLabel =>
      sw ? 'Fundi Anasubiri' : 'Fundi Pending';
  String get clientAgreedLabel => sw ? 'Mteja Amekubali' : 'Client Agreed';
  String get fundiAgreedLabel => sw ? 'Fundi Amekubali' : 'Fundi Agreed';

  // ── Edit profile ───────────────────────────────────────────────────────
  String get editYourProfile => sw ? 'Hariri Wasifu Wako' : 'Edit Profile';

  // ── Help ─────────────────────────────────────────────────────────────
  String get whatsappSupport =>
      sw ? 'Msaada kupitia WhatsApp' : 'WhatsApp Support';
  String get emailSupport => sw ? 'Barua Pepe ya Msaada' : 'Email Support';
  String get faq => sw ? 'Maswali Yanayoulizwa Mara Kwa Mara' : 'FAQ';
  String get faqQ1 =>
      sw ? 'Ninawezaje kupata na kuajiri fundi?'
          : 'How do I find and hire a fundi?';
  String get faqA1 =>
      sw ? 'Tafuta fundi kwa jina, kazi, au eneo. Gonga kadi yake ili uone wasifu kamili, kisha bonyeza "Omba Kazi".'
          : 'Search by name, skill, or location. Tap a fundi card to view their full profile, then tap "Book Now".';
  String get faqQ2 =>
      sw ? 'Nawezaje kuwasiliana na fundi baada ya booking?'
          : 'How do I contact a fundi after booking?';
  String get faqA2 =>
      sw ? 'Baada ya fundi kukubali, sehemu ya mazungumzo na nambari ya simu/WhatsApp inafunguliwa moja kwa moja kwenye ukurasa wa booking.'
          : 'Once the fundi accepts, the in-app chat and phone/WhatsApp contact unlock automatically on the booking detail page.';
  String get faqQ3 =>
      sw ? 'Je, ninaweza kuacha tathmini baada ya kazi?'
          : 'Can I leave a review after the job?';
  String get faqA3 =>
      sw ? 'Ndiyo! Baada ya kazi kukamilika, nenda kwenye booking yako na bonyeza "Wasilisha Tathmini". Ukadiriaji wa nyota unatosha — maoni ni ya hiari.'
          : 'Yes! After the job is completed, tap "Submit Review" on your booking. A star rating alone is enough — a written comment is optional.';
  String get faqQ4 =>
      sw ? 'Nifanye nini ikiwa kuna tatizo na fundi?'
          : 'What if there is a problem with a fundi?';
  String get faqA4 =>
      sw ? 'Bonyeza kitufe cha ripoti kwenye wasifu wa fundi au booking, au wasiliana na msaada wetu moja kwa moja kupitia WhatsApp au barua pepe.'
          : 'Tap the Report button on the fundi profile or booking, or contact our support team directly via WhatsApp or email.';
  String get faqQ5 =>
      sw ? 'Je, FundiHub ina ada ya usajili?'
          : 'Does FundiHub charge subscription fees?';
  String get faqA5 =>
      sw ? 'Hapana. FundiHub ni bure kabisa kwa wateja. Fundis wanaweza kupokea kazi bila ada ya kila mwezi.'
          : 'No. FundiHub is completely free for clients. Fundis can accept unlimited jobs with no monthly subscription required.';
  String get faqQ6 =>
      sw ? 'Reels na portfolio ya fundi zinafanya kazi vipi?'
          : 'How do fundi reels and portfolio work?';
  String get faqA6 =>
      sw ? 'Fundis wanaweza kupakia video fupi na picha za kazi zao. Tazama, penda, hifadhi, na toa maoni kwenye kichupo cha Discover.'
          : 'Fundis upload short work-showcase videos and portfolio images. Browse, like, save, and comment in the Discover tab.';
  String get faqQ7 =>
      sw ? 'Ninapataje msaada ikiwa nina tatizo?'
          : 'How do I get support if I have a problem?';
  String get faqA7 =>
      sw ? 'Piga WhatsApp +255754967156 au tuma barua pepe kwa tztech26@gmail.com. Timu yetu iko tayari kukusaidia.'
          : 'WhatsApp us at +255754967156 or email tztech26@gmail.com. Our team is ready to help.';

  // ── Share ─────────────────────────────────────────────────────────────
  String get shareMessage =>
      sw ? 'Pakua FundiHub — pata mafundi wa kuaminika karibu nawe kwa urahisi! 🔧\n'
           'https://play.google.com/store/apps/details?id=com.fundihub.app'
          : 'Download FundiHub — find trusted skilled professionals near you! 🔧\n'
           'https://play.google.com/store/apps/details?id=com.fundihub.app';

  // ── Splash ────────────────────────────────────────────────────────────
  String get appTagline =>
      sw ? 'Inakuunganisha na wataalamu mahiri'
          : 'Connecting you with skilled professionals';

  // ── Plan strings (kept for compat) ────────────────────────────────────
  String get premiumFundiLabel => sw ? 'Fundi Premium' : 'Premium Fundi';
  String get freePlanLabel => sw ? 'Mpango Bure' : 'Free Plan';
  String get freePlanSub =>
      sw ? 'Omba kazi bila kikwazo' : 'Accept unlimited jobs freely';
  String get daysRemaining => sw ? 'siku zilizobaki' : 'days remaining';
  String get upgradePremiumBtn =>
      sw ? 'Panda kwa Premium — Tsh 35,000/mwezi'
          : 'Upgrade to Premium — Tsh 35,000/mo';
  String get amountDue => sw ? 'Kiasi kinachostahili' : 'Amount due';

  // ── Payment submit ─────────────────────────────────────────────────────
  String get mockPaymentSuccess =>
      sw ? 'Malipo ya Majaribio Yamefanikiwa' : 'Mock Payment Successful';
  String get afterMockPayment =>
      sw ? 'Baada ya malipo ya majaribio:' : 'After mock payment:';
  String get perMonth => sw ? '/mwezi' : '/month';
  String get forDays => sw ? 'kwa siku' : 'for';
  String get days => sw ? 'siku' : 'days';

  // ── Auth (missing) ─────────────────────────────────────────────────────
  String get signInSubtitle =>
      sw ? 'Ingia ili uendelee kutumia FundiHub' : 'Sign in to continue using FundiHub';
  String get emailAddress => sw ? 'Anwani ya Barua Pepe' : 'Email Address';
  String get emailHint => sw ? 'wewe@mfano.com' : 'you@example.com';
  String get password => sw ? 'Nywila' : 'Password';
  String get passwordHint => sw ? 'Ingiza nywila yako' : 'Enter your password';
  String get rememberMe => sw ? 'Nikumbuke' : 'Remember Me';
  String get dontHaveAccount => sw ? 'Huna akaunti?' : "Don't have an account?";
  String get createAccountSubtitle =>
      sw ? 'Jisajili ili uanze kutumia FundiHub' : 'Create an account to get started with FundiHub';
  String get passwordMin => sw ? 'Angalau herufi 8' : 'At least 8 characters';
  String get confirmPassword => sw ? 'Thibitisha Nywila' : 'Confirm Password';
  String get confirmPasswordHint => sw ? 'Rudia nywila yako' : 'Repeat your password';
  String get alreadyHaveAccount => sw ? 'Una akaunti tayari?' : 'Already have an account?';
  String get passwordRequirements => sw ? 'Mahitaji ya Nywila' : 'Password Requirements';
  String get reqMinLength => sw ? 'Angalau herufi 8' : 'At least 8 characters';
  String get reqUppercase => sw ? 'Herufi moja kubwa (A-Z)' : 'One uppercase letter (A-Z)';
  String get reqNumber => sw ? 'Nambari moja (0-9)' : 'One number (0-9)';

  // ── Role selection (missing) ────────────────────────────────────────────
  String get roleSelectionTitle => sw ? 'Wewe ni Nani?' : 'Who Are You?';
  String get roleSelectionSubtitle =>
      sw ? 'Chagua jukumu lako ili kuendelea' : 'Select your role to continue';
  String get iAmClient => sw ? 'Mimi ni Mteja' : 'I\'m a Client';
  String get iAmClientSub =>
      sw ? 'Ninatafuta mafundi wa kuajiri' : 'I\'m looking to hire fundis';
  String get iAmFundi => sw ? 'Mimi ni Fundi' : 'I\'m a Fundi';
  String get iAmFundiSub =>
      sw ? 'Ninatoa huduma za fundi' : 'I offer professional services';

  // ── Filter / search (missing) ──────────────────────────────────────────
  String get filterFundis => sw ? 'Chuja Mafundi' : 'Filter Fundis';
  String get allRegions => sw ? 'Mikoa Yote' : 'All Regions';
  String get minimumRating => sw ? 'Ukadiriaji wa Chini' : 'Minimum Rating';

  // ── Edit profile (missing) ─────────────────────────────────────────────
  String get fullName => sw ? 'Jina Kamili' : 'Full Name';
  String get phoneNumber => sw ? 'Nambari ya Simu' : 'Phone Number';
  String get bio => sw ? 'Maelezo Mafupi' : 'Bio';
  String get location => sw ? 'Mahali' : 'Location';
  String get jobPortfolio => sw ? 'Picha za Kazi' : 'Job Portfolio';

  // ── Notifications (missing) ────────────────────────────────────────────
  String get markAllRead => sw ? 'Weka Zote Kusomwa' : 'Mark All as Read';
  String get noNotifications => sw ? 'Hakuna Arifa' : 'No Notifications';

  // ── Booking card (missing) ─────────────────────────────────────────────
  String get clientLabel => sw ? 'Mteja' : 'Client';
  String get fundiLabel => sw ? 'Fundi' : 'Fundi';

  // ── Onboarding / register extras (missing) ────────────────────────────
  String get selectCategory => sw ? 'Chagua Kategoria' : 'Select Category';
  String get selectRegion => sw ? 'Chagua Mkoa' : 'Select Region';
  String get selectDistrict => sw ? 'Chagua Wilaya' : 'Select District';
  String get experienceLabel => sw ? 'Uzoefu' : 'Experience';
  String get experienceHint =>
      sw ? 'mf. Miaka 3 ya upigaji bomba' : 'e.g. 3 years of plumbing';
  String get skillsLabel => sw ? 'Ujuzi' : 'Skills';
  String get skillsHint =>
      sw ? 'Bonyeza + kuongeza ujuzi' : 'Tap + to add skills';
  String get areaLabel => sw ? 'Mtaa / Eneo' : 'Area / Neighborhood';
  String get areaHint => sw ? 'mf. Kariakoo, Kinondoni' : 'e.g. Kariakoo, Kinondoni';
  String get iAgreeToTerms => sw ? 'Nakubali masharti' : 'I agree to the terms';
  String get termsAndConditions => sw ? 'Masharti na Hali' : 'Terms & Conditions';
  String get signUpFundi => sw ? 'Jisajili kama Fundi' : 'Sign Up as Fundi';
  String get signUpClient => sw ? 'Jisajili kama Mteja' : 'Sign Up as Client';

  // ── Status extras (missing) ────────────────────────────────────────────
  String get accepted => sw ? 'Imekubaliwa' : 'Accepted';
  String get cancelled => sw ? 'Imeghairiwa' : 'Cancelled';
  String get rejected => sw ? 'Imekataliwa' : 'Rejected';
  String get inProgress => sw ? 'Inafanywa' : 'In Progress';
  String get agreed => sw ? 'Imekubaliwa' : 'Agreed';
  String get free => sw ? 'Bure' : 'Free';
  String get opening => sw ? 'Inafunguliwa...' : 'Opening...';
  String get all => sw ? 'Zote' : 'All';
  String get boosted => sw ? 'imeboostwa' : 'boosted';

  // ── Auth extras (missing) ──────────────────────────────────────────────
  String get resetPassword => sw ? 'Weka Upya Nenosiri' : 'Reset Password';
  String get enterEmail => sw ? 'Weka barua pepe yako' : 'Enter your email';

  // ── Role selection extras (missing) ────────────────────────────────────
  String get roleClient => sw ? 'Mteja' : 'Client';
  String get roleFundi => sw ? 'Fundi / Mtaalam' : 'Fundi / Technician';
  String get clientSubtitle =>
      sw ? 'Nataka kuajiri fundi au mtaalamu' : 'I need to hire a fundi or technician';
  String get fundiSubtitle =>
      sw ? 'Ninatoa huduma za kitaalamu' : 'I offer professional services';
  String get clientFeature1 => sw ? 'Tafuta mafundi karibu nawe' : 'Search for fundis near you';
  String get clientFeature2 => sw ? 'Panga huduma kwa urahisi' : 'Book services easily';
  String get clientFeature3 => sw ? 'Mazungumzo salama na mafundi' : 'Secure chat with fundis';
  String get clientFeature4 => sw ? 'Acha maoni baada ya kazi' : 'Leave reviews after jobs';
  String get fundiFeature1 => sw ? 'Pokea maombi ya kazi' : 'Receive job bookings';
  String get fundiFeature2 => sw ? 'Simamia ratiba yako ya kazi' : 'Manage your work schedule';
  String get fundiFeature3 => sw ? 'Jenga sifa yako' : 'Build your reputation';
  String get fundiFeature4 => sw ? 'Kukuza biashara yako' : 'Grow your business';
  String get createMyAccount => sw ? 'Fungua Akaunti Yangu' : 'Create My Account';
  String get roleWarning =>
      sw ? 'Jukumu haliwezi kubadilishwa baada ya kusajiliwa.'
          : 'Your role cannot be changed after registration.';

  // ── Profile / settings (missing) ──────────────────────────────────────
  String get editProfile => sw ? 'Hariri Wasifu' : 'Edit Profile';
  String get helpSupport => sw ? 'Msaada' : 'Help & Support';
  String get blockedUsers => sw ? 'Watumiaji Waliozuiwa' : 'Blocked Users';
  String get accountSettings => sw ? 'Mipangilio' : 'Account Settings';
  String get language => sw ? 'Lugha' : 'Language';
  String get english => sw ? 'Kiingereza' : 'English';
  String get swahili => sw ? 'Kiswahili' : 'Swahili';
  String get switchLanguage => sw ? 'Badilisha Lugha' : 'Switch Language';
  String get jobsCompleted => sw ? 'Kazi Zilizokamilika' : 'Jobs Completed';
  String get bioHint =>
      sw ? 'Elezea huduma unazotoa, uzoefu wako, na kinachokufanya uwe mzuri...'
          : 'Describe the services you offer, your experience, and what makes you great...';
  String get notSet => sw ? 'Haijawekwa' : 'Not set';
  String get updateInfoPhoto =>
      sw ? 'Sasisha taarifa na picha yako' : 'Update your info and photo';
  String get manageBlocked =>
      sw ? 'Simamia watumiaji uliowazuia' : 'Manage blocked users';
  String get inviteFriends =>
      sw ? 'Alika marafiki FundiHub' : 'Invite friends to FundiHub';
  String get viewNotifications =>
      sw ? 'Angalia arifa zako' : 'View your notifications';
  String get takePhoto => sw ? 'Piga Picha' : 'Take Photo';
  String get chooseGallery => sw ? 'Chagua kutoka Picha' : 'Choose from Gallery';

  // ── Dashboard extras (missing) ─────────────────────────────────────────
  String get findProfessionals =>
      sw ? 'Pata wataalamu\nkaribu nawe' : 'Find skilled professionals\nnear you';
  String get browseCategory => sw ? 'Tafuta kwa Aina' : 'Browse by Category';
  String get featuredFundis => sw ? 'Mafundi Waliopo Juu' : 'Featured Fundis';
  String get recommended => sw ? 'Wanapendekezwa' : 'Recommended Fundis';
  String get searchHint => sw ? 'Tafuta fundi au huduma...' : 'Search for a fundi or service...';
  String get overview => sw ? 'Muhtasari' : 'Overview';
  String get recentJobs => sw ? 'Kazi za Hivi Karibuni' : 'Recent Jobs';

  // ── Bookings / Jobs screens (missing) ─────────────────────────────────
  String get myBookings => sw ? 'Maombi Yangu' : 'My Bookings';
  String get myJobs => sw ? 'Kazi Zangu' : 'My Jobs';
  String get requests => sw ? 'Maombi' : 'Requests';
  String get history => sw ? 'Historia' : 'History';
  String get noBookings => sw ? 'Hakuna Maombi' : 'No Bookings';
  String get noJobs => sw ? 'Hakuna Kazi' : 'No Jobs';
  String get noJobsSubtitle =>
      sw ? 'Maombi mapya ya kazi yataonekana hapa.\nHakikisha wasifu wako umekamilika.'
          : 'New job requests will appear here.\nMake sure your profile is complete.';
  String get bookingRequestsAppear =>
      sw ? 'Maombi mapya yataonekana hapa.' : 'Your booking requests will appear here.';
  String get newRequestsAppear =>
      sw ? 'Maombi mapya ya kazi yataonekana hapa.' : 'New booking requests will appear here.';
  String get acceptedJobsAppear =>
      sw ? 'Kazi zilizokubaliwa zitaonekana hapa.' : 'Accepted jobs will appear here.';
  String get historyJobsAppear =>
      sw ? 'Kazi zilizokamilika, kukataliwa, au kughairiwa zitaonekana hapa.'
          : 'Completed, rejected, or cancelled jobs will appear here.';
  String get rejectBookingTitle => sw ? 'Kataa ombi?' : 'Reject booking?';
  String get bookingRejected => sw ? 'Ombi limekataliwa.' : 'Booking rejected.';
  String get bookingAcceptedChat =>
      sw ? 'Ombi limekubaliwa. Mazungumzo yamefunguliwa!' : 'Booking accepted. Chat opened.';
  String get acceptChat => sw ? 'Kubali & Fungua Mazungumzo' : 'Accept & Chat';

  // ── Booking detail (missing) ───────────────────────────────────────────
  String get bookingDetail => sw ? 'Maelezo ya Ombi' : 'Booking Detail';
  String get serviceDescription => sw ? 'Maelezo ya Huduma' : 'Service Description';
  String get jobLocation => sw ? 'Mahali pa Kazi' : 'Job Location';
  String get timeline => sw ? 'Mfululizo' : 'Timeline';
  String get agreement => sw ? 'Makubaliano' : 'Agreement';
  String get startJob => sw ? 'Anza Kazi' : 'Start Job';
  String get completeJob => sw ? 'Maliza Kazi' : 'Complete Job';
  String get cancelBooking => sw ? 'Ghairi Ombi' : 'Cancel Booking';
  String get cancelBookingTitle => sw ? 'Ghairi Ombi?' : 'Cancel Booking?';
  String get cancelBookingBody =>
      sw ? 'Je, una uhakika unataka kughairi ombi hili?' : 'Are you sure you want to cancel this booking?';
  String get agreeToJob =>
      sw ? 'Kagua maelezo ya kazi na bonyeza Kubali unapokuwa tayari.'
          : 'Review the job details and tap Agree when you are ready.';
  String get iAgreeToJob => sw ? 'Nakubali Kazi Hii' : 'I Agree to This Job';
  String get contactUnlocked =>
      sw ? 'Mawasiliano na maendeleo ya kazi yamefunguliwa.'
          : 'Contact and job progress controls are now unlocked.';
  String get contactWaiting =>
      sw ? 'Umekubali. Unasubiri mtu mwingine.' : "You've agreed. Waiting for the other party.";
  String get contactUnlockedAfterAgreement =>
      sw ? 'Mawasiliano yanafunguliwa pande zote zinapokubaliana.'
          : 'Contact unlocks once both parties agree.';
  String get leaveReview => sw ? 'Acha Maoni' : 'Leave a Review';
  String get reviewSubmitted => sw ? 'Maoni yamepelekwa' : 'Review submitted';
  String get reportFundi => sw ? 'Ripoti Fundi' : 'Report Fundi';
  String get reportClient => sw ? 'Ripoti Mteja' : 'Report Client';

  // ── Chat (missing) ─────────────────────────────────────────────────────
  String get noMessages => sw ? 'Hakuna Ujumbe' : 'No Messages Yet';
  String get noMessagesSubtitle =>
      sw ? 'Mazungumzo yako yataonekana hapa baada ya kuomba fundi.'
          : 'Your conversations will appear here after booking a fundi.';
  String get typeMessage => sw ? 'Andika ujumbe...' : 'Type a message...';
  String get chatLocked => sw ? 'Mazungumzo Yamefungwa' : 'Chat Locked';
  String get chatLockedSub =>
      sw ? 'Mazungumzo yanafunguliwa baada ya kukubali ombi.'
          : 'Chat unlocks after the booking is accepted.';
  String get readAllChats => sw ? 'Soma Zote' : 'Read all';
  String get allCaughtUp => sw ? 'Umesoma kila kitu! 🎉' : "You're all caught up! 🎉";

  // ── Search / filter (missing) ──────────────────────────────────────────
  String get noFundisFound => sw ? 'Hakuna Fundi' : 'No Fundis Found';
  String get noFundisSubtitle =>
      sw ? 'Hakuna fundi wa aina hii. Jaribu aina nyingine.' : 'No fundis found for this category. Try another.';
  String get noFundisSearchSubtitle =>
      sw ? 'Hakuna fundi anayelingana na utafutaji wako.' : 'No fundis match your search.';
  String get clearFilters => sw ? 'Ondoa Vichujio' : 'Clear Filters';

  // ── Payments (missing) ─────────────────────────────────────────────────
  String get noPaymentsSubtitle =>
      sw ? 'Historia yako ya malipo itaonekana hapa.' : 'Your payment history will appear here.';
  String get feeDue => sw ? 'Ada Inadaiwa' : 'Fee Due';
  String get payBeforeUnlock =>
      sw ? 'Lipa kabla kazi yako ijayo haijafunguliwa.' : 'Pay before your next job unlocks.';
  String get payNow => sw ? 'Lipa Sasa' : 'Pay Now';
  String get unlimitedJobs =>
      sw ? 'Kazi bila kikwazo • Bila ada za kazi • Orodha ya kipaumbele'
          : 'Unlimited jobs • No per-job fees • Priority listing';
  String get unlimitedJobsNofees =>
      sw ? 'Kazi bila kikwazo • Bila ada • Orodha ya kipaumbele'
          : 'Unlimited jobs • No per-job fees • Priority listing';
  String get tshFeePerJob =>
      sw ? 'Ada Tsh 2,500 kwa kazi • Kazi 1 kwa wakati mmoja'
          : 'Tsh 2,500 fee per job • 1 job at a time';
  String get premiumFundi => sw ? 'Fundi Premium' : 'Premium Fundi';
  String get rate => sw ? 'Kadiria' : 'Rate';
  String get whatsapp => sw ? 'WhatsApp' : 'WhatsApp';
  String get report => sw ? 'Ripoti' : 'Report';

  // ── AppButton/AppDropdown widget extras (missing) ──────────────────────
  // These come from widget constructors that use leadingIcon not icon
  // No l10n keys needed — these are widget API mismatches, not l10n issues.
}
