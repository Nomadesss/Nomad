// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Feel closer to home';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithPhone => 'Sign in with phone number';

  @override
  String get noAccount => 'Don\'t have an account? ';

  @override
  String get registerHere => 'Register here';

  @override
  String get loginError => 'Could not sign in. Please try again.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPassword => 'Password';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsActiveDevices => 'Active devices';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAccountPrivacy => 'Account privacy';

  @override
  String get settingsBlockedUsers => 'Blocked users';

  @override
  String get settingsSupport => 'Support';

  @override
  String get settingsHelpCenter => 'Help center';

  @override
  String get settingsAbout => 'About Nomad';

  @override
  String get logout => 'Sign out';

  @override
  String get languageSheetTitle => 'Select language';

  @override
  String get languageAutomatic => 'Automatic (based on your device)';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get continueButton => 'Continue';

  @override
  String get deleteButton => 'Delete';

  @override
  String get recommended => 'Recommended';

  @override
  String get seeMore => 'see more';

  @override
  String get seeLess => 'see less';

  @override
  String get viewComments => 'View comments';

  @override
  String get pinned => 'Pinned';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get deleteCurrentPhoto => 'Delete current photo';

  @override
  String get now => 'Now';

  @override
  String get gallery => 'Gallery';

  @override
  String get camera => 'Camera';

  @override
  String get preview => 'Preview';

  @override
  String get send => 'Send';

  @override
  String get next => 'Next';

  @override
  String get publish => 'Publish';

  @override
  String get skip => 'Skip';

  @override
  String get use => 'Use';

  @override
  String get regTitle => 'Create account';

  @override
  String get regSubtitle => 'Fill in your details to join Nomad';

  @override
  String get regFirstNameLabel => 'First name(s)';

  @override
  String get regFirstNameHint => 'Your first name';

  @override
  String get regLastNameLabel => 'Last name(s)';

  @override
  String get regLastNameHint => 'Your last name';

  @override
  String get regBirthdateLabel => 'Date of birth';

  @override
  String get regBirthdatePlaceholder => 'Select your date';

  @override
  String get regEmailLabel => 'Email';

  @override
  String get regEmailHint => 'you@email.com';

  @override
  String get regPasswordLabel => 'Password';

  @override
  String get regPasswordHint => 'Minimum 8 characters';

  @override
  String get regConfirmPasswordLabel => 'Confirm your password';

  @override
  String get regConfirmPasswordHint => 'Repeat your password';

  @override
  String get regReqLength => '8 characters';

  @override
  String get regReqUppercase => 'Uppercase';

  @override
  String get regReqSymbol => 'Symbol';

  @override
  String get regCreateButton => 'Create my account';

  @override
  String get regDateConfirm => 'Confirm';

  @override
  String get regErrorFirstName => 'Enter your first name';

  @override
  String get regErrorFirstNameMin => 'Minimum 2 characters';

  @override
  String get regErrorLastName => 'Enter your last name';

  @override
  String get regErrorEmail => 'Enter your email';

  @override
  String get regErrorEmailInvalid => 'Invalid email';

  @override
  String get regErrorPassword => 'Enter a password';

  @override
  String get regErrorPasswordMin => 'Minimum 8 characters';

  @override
  String get regErrorPasswordUppercase =>
      'Must include at least one uppercase letter';

  @override
  String get regErrorPasswordSymbol => 'Must include at least one symbol';

  @override
  String get regErrorConfirmPassword => 'Confirm your password';

  @override
  String get regErrorPasswordMismatch => 'Passwords do not match';

  @override
  String get regErrorSelectBirthdate => 'Select your date of birth';

  @override
  String get phoneTitle => 'Your phone number';

  @override
  String get phoneSubtitle => 'We\'ll send you a verification code via SMS';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get phoneCountrySheetTitle => 'Select your country';

  @override
  String get phoneCountrySearchHint => 'Search country...';

  @override
  String get phoneErrorEmpty => 'Enter your phone number';

  @override
  String get phoneErrorTooShort => 'Number is too short';

  @override
  String get phoneErrorInvalid => 'Invalid phone number';

  @override
  String get phoneErrorTooManyAttempts =>
      'Too many attempts. Wait a few minutes.';

  @override
  String get phoneErrorNoConnection => 'No connection. Check your internet.';

  @override
  String get phoneErrorSend => 'Error sending code. Please try again.';

  @override
  String get phoneSendButton => 'Send code';

  @override
  String get phoneInstruction =>
      'Enter the number only, without the country prefix.';

  @override
  String get phoneVerifTitle => 'Verify your number';

  @override
  String phoneVerifCodeSent(String phone) {
    return 'Enter the code we sent to $phone';
  }

  @override
  String get phoneVerifErrorDigits => 'Enter the 6-digit code';

  @override
  String get phoneVerifErrorWrong => 'Wrong code. Check your SMS.';

  @override
  String get phoneVerifErrorExpired => 'Code expired. Request a new one.';

  @override
  String get phoneVerifErrorGeneric => 'Verification error. Please try again.';

  @override
  String get phoneVerifErrorUnexpected => 'Unexpected error. Please try again.';

  @override
  String get phoneVerifNoCode => 'Didn\'t receive the code? ';

  @override
  String phoneVerifResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get phoneVerifResend => 'Resend';

  @override
  String get phoneVerifResendError =>
      'Could not resend code. Please try again.';

  @override
  String get phoneVerifResendSuccess => 'Code resent';

  @override
  String get phoneVerifButton => 'Verify code';

  @override
  String get biometricAuthWelcome => 'Welcome back';

  @override
  String get biometricAuthErrorTitle => 'Verification failed';

  @override
  String get biometricAuthErrorMessage =>
      'Verification failed. Try again or use another option.';

  @override
  String biometricAuthInstruction(String biometric) {
    return 'Confirm your identity with $biometric to sign in';
  }

  @override
  String get biometricAuthRetry => 'Try again';

  @override
  String biometricAuthUse(String biometric) {
    return 'Use $biometric';
  }

  @override
  String get biometricAuthOtherAccount => 'Use another account';

  @override
  String biometricSetupTitle(String biometric) {
    return 'Enable $biometric';
  }

  @override
  String biometricSetupDescription(String biometric) {
    return 'Make your next sign-ins faster and more secure. You only need your $biometric to verify your identity.';
  }

  @override
  String get biometricSetupBenefit1Title => 'Instant access';

  @override
  String get biometricSetupBenefit1Desc => 'No passwords, no waiting';

  @override
  String get biometricSetupBenefit2Title => 'More secure';

  @override
  String get biometricSetupBenefit2Desc =>
      'Your identity doesn\'t travel over the internet';

  @override
  String get biometricSetupBenefit3Title => 'Works offline';

  @override
  String get biometricSetupBenefit3Desc => 'No signal or SMS needed';

  @override
  String biometricSetupActivate(String biometric) {
    return 'Enable $biometric';
  }

  @override
  String get biometricSetupSkip => 'Not now';

  @override
  String get termsTitle => 'Before you start';

  @override
  String get termsCardTitle => 'Accept terms';

  @override
  String get termsCardDescription =>
      'To use Nomad, we need you to accept our terms and privacy policy.';

  @override
  String get termsAcceptPrefix => 'I accept the ';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get termsAnd => ' and the ';

  @override
  String get termsPrivacyPolicy => 'Privacy policy';

  @override
  String get termsAcceptButton => 'Accept and continue';

  @override
  String get termsFooter => 'You can review these documents later in settings.';

  @override
  String get feedEmptyTitle => 'Your feed is empty for now';

  @override
  String get feedEmptyMessage =>
      'Follow other nomads or enable\nyour location to see nearby posts';

  @override
  String get postStepPhotos => 'Choose your photos';

  @override
  String get postStepWrite => 'Tell your story';

  @override
  String get postStepMusic => 'Music';

  @override
  String get postStepPreview => 'Preview';

  @override
  String postPhotosCounter(int count) {
    return 'Up to 5 photos • $count/5';
  }

  @override
  String get postPhotosInfo =>
      'You can upload up to 5 photos. Order editing coming soon.';

  @override
  String get postDescriptionLabel => 'Description';

  @override
  String get postDescriptionHint => 'Tell us something about this moment...';

  @override
  String get postLocationLabel => 'Location';

  @override
  String get postLocationHint => 'e.g. New York, USA';

  @override
  String get postMoodLabel => 'Choose the mood of your post';

  @override
  String get postMoodChill => 'Chill';

  @override
  String get postMoodTravel => 'Travel';

  @override
  String get postMoodFocus => 'Focus';

  @override
  String get postMoodRomance => 'Romance';

  @override
  String get postMoodEnergy => 'Energy';

  @override
  String get postMoodParty => 'Party';

  @override
  String get postSearchMusicLabel => 'Search song';

  @override
  String get postSearchMusicHint => 'e.g. Coldplay';

  @override
  String get postNoResults => 'No results found';

  @override
  String get postSpotifyNoPreview => 'Spotify has no preview for this song';

  @override
  String get postErrorNoPhoto => 'Add at least one photo';

  @override
  String get eventAppBarTitle => 'Create event';

  @override
  String get eventCoverLabel => 'Cover photo (optional)';

  @override
  String get eventCoverPlaceholder => 'Add a cover';

  @override
  String get eventCoverPlaceholderSub => 'Make your event more attractive';

  @override
  String get eventTypeLabel => 'Event type';

  @override
  String get eventTitleLabel => 'Title';

  @override
  String get eventTitleHint => 'e.g. Nomads meetup in Central Park';

  @override
  String get eventTitleError => 'Title is required';

  @override
  String get eventDescLabel => 'About the event';

  @override
  String get eventDescHint => 'Describe what this event is about...';

  @override
  String get eventDateLabel => 'Date and time';

  @override
  String get eventLocationLabel => 'Location';

  @override
  String get eventLocationHint => 'e.g. Central Park, New York';

  @override
  String get eventCapacityLabel => 'Max capacity (optional)';

  @override
  String get eventCapacityHint => 'e.g. 30';

  @override
  String get eventPickDate => 'Pick date';

  @override
  String get eventPickTime => 'Pick time';

  @override
  String get eventCreateButton => 'Create event';

  @override
  String get eventSuccess => 'Event created!';

  @override
  String get eventErrorDateTime => 'Choose a date and time for the event';

  @override
  String get communityTitle => 'Community message';

  @override
  String get communityBanner => 'Share useful information with nearby nomads';

  @override
  String get communityCategoryLabel => 'Category';

  @override
  String get communityMsgTitleLabel => 'Title (optional)';

  @override
  String get communityMsgTitleHint => 'e.g. Nomads meetup this Saturday!';

  @override
  String get communityMsgLabel => 'Message';

  @override
  String get communityMsgHint => 'Write your message for the community...';

  @override
  String get communityPreviewLabel => 'Preview';

  @override
  String get communityMsgError => 'Write a message for the community';

  @override
  String get communitySendButton => 'Send to community';

  @override
  String get communitySuccessMsg => 'Message sent to the community!';

  @override
  String get communityErrorMsg => 'Could not send. Please try again.';

  @override
  String get communityCatInfo => 'Info';

  @override
  String get communityCatUrgent => 'Urgent';

  @override
  String get communityCatQuestion => 'Question';

  @override
  String get communityCatOffer => 'Offer';

  @override
  String get communityCatAlert => 'Alert';

  @override
  String get searchPeople => 'People';

  @override
  String get searchEvents => 'Events';

  @override
  String get searchPlaces => 'Places';

  @override
  String get searchCommunities => 'Communities';

  @override
  String get searchTips => 'Tips';

  @override
  String get searchJobs => 'Jobs';

  @override
  String get mapMigrants => 'Migrants';

  @override
  String get mapConsulates => 'Consulates';

  @override
  String get mapRestaurants => 'Restaurants';

  @override
  String get mapShops => 'Shops';

  @override
  String get mapCultural => 'Cultural';

  @override
  String get mapHelp => 'Help';

  @override
  String get mapBorders => 'Border crossings';

  @override
  String get catAll => 'All';

  @override
  String get catGeneral => 'General';

  @override
  String get catVisas => 'Visas';

  @override
  String get catHousing => 'Housing';

  @override
  String get catWork => 'Work';

  @override
  String get catHealth => 'Health';

  @override
  String get catLanguages => 'Languages';

  @override
  String get catSocial => 'Social';

  @override
  String get catTips => 'Tips';

  @override
  String get profileNoPostsTitle => 'Nothing posted yet';

  @override
  String get profileNoPostsSubtitle => 'Share your migrant experience';

  @override
  String get profileNoEventsTitle => 'No events created';

  @override
  String get profileNoEventsSubtitle => 'Organize meetups for the community';

  @override
  String get profileNoMessagesTitle => 'No messages yet';

  @override
  String get profileNoMessagesSubtitle =>
      'Share tips, questions or experiences';

  @override
  String get profileEditButton => 'Edit profile';

  @override
  String get profileViewComments => 'View comments';

  @override
  String get profileDeletePostTitle => 'Delete post';

  @override
  String get profileDeletePostContent =>
      'Are you sure? This action cannot be undone.';

  @override
  String get profileEditCover => 'Edit cover';

  @override
  String get setupLocationPermTitle => 'Can we see your location?';

  @override
  String get setupLocationPermDesc =>
      'Nomad uses your location to connect you with nearby compatriots. We never share your exact position with other users.';

  @override
  String get setupTrustScoreImpact => 'Impact on your Trust Score';

  @override
  String get setupLocationOnlyWhenUsing => 'Allow only while using';

  @override
  String get setupLocationAlways => 'Always allow';

  @override
  String get setupLocationDeny => 'Don\'t allow now';

  @override
  String setupStepOf(int step) {
    return 'Step $step of 4';
  }

  @override
  String get setupUsernameTitle => 'Choose your username';

  @override
  String get setupUsernameSubtitle => 'This will be your unique name on Nomad';

  @override
  String get setupUsernameAvailable => 'Username available';

  @override
  String get setupUsernameErrorFormat =>
      'Between 6 and 15 characters, only letters, numbers and _';

  @override
  String get setupUsernameErrorMin =>
      'Minimum 6 characters, only letters, numbers and _';

  @override
  String get setupUsernameTaken => 'Username already taken';

  @override
  String get setupNationalityTitle => 'What is your nationality?';

  @override
  String get setupNationalitySubtitle => 'Connect with your people';

  @override
  String get setupLocationTitle => 'Your current location';

  @override
  String get setupLocationSubtitle => 'Get closer to your compatriots';

  @override
  String get setupLocationError => 'Could not get location';

  @override
  String get setupGoalsTitle => 'What are you looking for in Nomad?';

  @override
  String get setupGoalsSubtitle => 'You can choose more than one option';

  @override
  String get setupGoalFriendship => 'Friendship';

  @override
  String get setupGoalDating => 'Dating';

  @override
  String get setupGoalServices => 'Services';

  @override
  String get setupGoalForums => 'Forums';

  @override
  String get setupTrustScoreDesc =>
      'Your score validates your identity to other Nomads. Sharing your location is one of the factors that raises your score the most — without it, your profile will have less visibility and credibility in the community.';

  @override
  String get setupPermissionInUseSub => '+Score · Only when Nomad is open';

  @override
  String get setupPermissionRecommended => 'Recommended';

  @override
  String get setupPermissionAlwaysSub =>
      '+Max Score · Full access at all times';

  @override
  String get setupPermissionDenySub =>
      '−Score · You can enable it later from your profile';

  @override
  String get setupLocationDetecting => 'Detecting...';

  @override
  String get setupLocationPermissionDenied => 'Permission denied';

  @override
  String get setupLocationUpdate => 'Update location';

  @override
  String get setupLocationGeolocate => 'GEOLOCATE';

  @override
  String get setupGoalFriendshipDesc => 'Meet compatriots';

  @override
  String get setupGoalDatingDesc => 'Connect romantically';

  @override
  String get setupGoalServicesDesc => 'Jobs and errands';

  @override
  String get setupGoalForumsDesc => 'Join the chat';

  @override
  String get setupSearchCountry => 'Search country...';

  @override
  String get setupSelectCountry => 'Select country';

  @override
  String get setupNoResults => 'No results';

  @override
  String get setupUnknownCity => 'Unknown city';
}
