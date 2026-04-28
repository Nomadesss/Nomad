import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In es, this message translates to:
  /// **'Siéntete más cerca de tu casa'**
  String get appTagline;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithPhone.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión con número de celular'**
  String get continueWithPhone;

  /// No description provided for @noAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tenés cuenta? '**
  String get noAccount;

  /// No description provided for @registerHere.
  ///
  /// In es, this message translates to:
  /// **'Registrate aquí'**
  String get registerHere;

  /// No description provided for @loginError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión. Intentá de nuevo.'**
  String get loginError;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settings;

  /// No description provided for @settingsAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get settingsAccount;

  /// No description provided for @settingsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get settingsNotifications;

  /// No description provided for @settingsPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get settingsPassword;

  /// No description provided for @settingsLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @settingsActiveDevices.
  ///
  /// In es, this message translates to:
  /// **'Dispositivos activos'**
  String get settingsActiveDevices;

  /// No description provided for @settingsPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get settingsPrivacy;

  /// No description provided for @settingsAccountPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad de la cuenta'**
  String get settingsAccountPrivacy;

  /// No description provided for @settingsBlockedUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios bloqueados'**
  String get settingsBlockedUsers;

  /// No description provided for @settingsSupport.
  ///
  /// In es, this message translates to:
  /// **'Soporte'**
  String get settingsSupport;

  /// No description provided for @settingsHelpCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro de ayuda'**
  String get settingsHelpCenter;

  /// No description provided for @settingsAbout.
  ///
  /// In es, this message translates to:
  /// **'Acerca de Nomad'**
  String get settingsAbout;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @languageSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar idioma'**
  String get languageSheetTitle;

  /// No description provided for @languageAutomatic.
  ///
  /// In es, this message translates to:
  /// **'Automático (según tu dispositivo)'**
  String get languageAutomatic;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePortuguese.
  ///
  /// In es, this message translates to:
  /// **'Português'**
  String get languagePortuguese;

  /// No description provided for @languageFrench.
  ///
  /// In es, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In es, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageItalian.
  ///
  /// In es, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @languageTurkish.
  ///
  /// In es, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @languageRussian.
  ///
  /// In es, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageHindi.
  ///
  /// In es, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// No description provided for @cancelButton.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelButton;

  /// No description provided for @continueButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueButton;

  /// No description provided for @deleteButton.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteButton;

  /// No description provided for @recommended.
  ///
  /// In es, this message translates to:
  /// **'Recomendado'**
  String get recommended;

  /// No description provided for @seeMore.
  ///
  /// In es, this message translates to:
  /// **'ver más'**
  String get seeMore;

  /// No description provided for @seeLess.
  ///
  /// In es, this message translates to:
  /// **'ver menos'**
  String get seeLess;

  /// No description provided for @viewComments.
  ///
  /// In es, this message translates to:
  /// **'Ver comentarios'**
  String get viewComments;

  /// No description provided for @pinned.
  ///
  /// In es, this message translates to:
  /// **'Fijado'**
  String get pinned;

  /// No description provided for @takePhoto.
  ///
  /// In es, this message translates to:
  /// **'Tomar foto'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de galería'**
  String get chooseFromGallery;

  /// No description provided for @deleteCurrentPhoto.
  ///
  /// In es, this message translates to:
  /// **'Eliminar foto actual'**
  String get deleteCurrentPhoto;

  /// No description provided for @now.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get now;

  /// No description provided for @gallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get camera;

  /// No description provided for @preview.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get preview;

  /// No description provided for @send.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @publish.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get publish;

  /// No description provided for @skip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get skip;

  /// No description provided for @use.
  ///
  /// In es, this message translates to:
  /// **'Usar'**
  String get use;

  /// No description provided for @regTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get regTitle;

  /// No description provided for @regSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Completá tus datos para unirte a Nomad'**
  String get regSubtitle;

  /// No description provided for @regFirstNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre/s'**
  String get regFirstNameLabel;

  /// No description provided for @regFirstNameHint.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre'**
  String get regFirstNameHint;

  /// No description provided for @regLastNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Apellido/s'**
  String get regLastNameLabel;

  /// No description provided for @regLastNameHint.
  ///
  /// In es, this message translates to:
  /// **'Tu apellido'**
  String get regLastNameHint;

  /// No description provided for @regBirthdateLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get regBirthdateLabel;

  /// No description provided for @regBirthdatePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Seleccioná tu fecha'**
  String get regBirthdatePlaceholder;

  /// No description provided for @regEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get regEmailLabel;

  /// No description provided for @regEmailHint.
  ///
  /// In es, this message translates to:
  /// **'tu@email.com'**
  String get regEmailHint;

  /// No description provided for @regPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get regPasswordLabel;

  /// No description provided for @regPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get regPasswordHint;

  /// No description provided for @regConfirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmá tu contraseña'**
  String get regConfirmPasswordLabel;

  /// No description provided for @regConfirmPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Repetí la contraseña'**
  String get regConfirmPasswordHint;

  /// No description provided for @regReqLength.
  ///
  /// In es, this message translates to:
  /// **'8 caracteres'**
  String get regReqLength;

  /// No description provided for @regReqUppercase.
  ///
  /// In es, this message translates to:
  /// **'Mayúscula'**
  String get regReqUppercase;

  /// No description provided for @regReqSymbol.
  ///
  /// In es, this message translates to:
  /// **'Símbolo'**
  String get regReqSymbol;

  /// No description provided for @regCreateButton.
  ///
  /// In es, this message translates to:
  /// **'Crear mi cuenta'**
  String get regCreateButton;

  /// No description provided for @regDateConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get regDateConfirm;

  /// No description provided for @regErrorFirstName.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu nombre'**
  String get regErrorFirstName;

  /// No description provided for @regErrorFirstNameMin.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 2 caracteres'**
  String get regErrorFirstNameMin;

  /// No description provided for @regErrorLastName.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu apellido'**
  String get regErrorLastName;

  /// No description provided for @regErrorEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu email'**
  String get regErrorEmail;

  /// No description provided for @regErrorEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Email inválido'**
  String get regErrorEmailInvalid;

  /// No description provided for @regErrorPassword.
  ///
  /// In es, this message translates to:
  /// **'Ingresá una contraseña'**
  String get regErrorPassword;

  /// No description provided for @regErrorPasswordMin.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get regErrorPasswordMin;

  /// No description provided for @regErrorPasswordUppercase.
  ///
  /// In es, this message translates to:
  /// **'Debe incluir al menos una mayúscula'**
  String get regErrorPasswordUppercase;

  /// No description provided for @regErrorPasswordSymbol.
  ///
  /// In es, this message translates to:
  /// **'Debe incluir al menos un símbolo'**
  String get regErrorPasswordSymbol;

  /// No description provided for @regErrorConfirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirmá tu contraseña'**
  String get regErrorConfirmPassword;

  /// No description provided for @regErrorPasswordMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get regErrorPasswordMismatch;

  /// No description provided for @regErrorSelectBirthdate.
  ///
  /// In es, this message translates to:
  /// **'Seleccioná tu fecha de nacimiento'**
  String get regErrorSelectBirthdate;

  /// No description provided for @phoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu número de celular'**
  String get phoneTitle;

  /// No description provided for @phoneSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un código de verificación por SMS'**
  String get phoneSubtitle;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In es, this message translates to:
  /// **'Número de teléfono'**
  String get phoneNumberLabel;

  /// No description provided for @phoneCountrySheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Seleccioná tu país'**
  String get phoneCountrySheetTitle;

  /// No description provided for @phoneCountrySearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar país...'**
  String get phoneCountrySearchHint;

  /// No description provided for @phoneErrorEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu número de teléfono'**
  String get phoneErrorEmpty;

  /// No description provided for @phoneErrorTooShort.
  ///
  /// In es, this message translates to:
  /// **'Número demasiado corto'**
  String get phoneErrorTooShort;

  /// No description provided for @phoneErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Número de teléfono inválido'**
  String get phoneErrorInvalid;

  /// No description provided for @phoneErrorTooManyAttempts.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Esperá unos minutos.'**
  String get phoneErrorTooManyAttempts;

  /// No description provided for @phoneErrorNoConnection.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Verificá tu internet.'**
  String get phoneErrorNoConnection;

  /// No description provided for @phoneErrorSend.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar el código. Intentá de nuevo.'**
  String get phoneErrorSend;

  /// No description provided for @phoneSendButton.
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get phoneSendButton;

  /// No description provided for @phoneInstruction.
  ///
  /// In es, this message translates to:
  /// **'Ingresá solo el número sin el prefijo de país.'**
  String get phoneInstruction;

  /// No description provided for @phoneVerifTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificá tu número'**
  String get phoneVerifTitle;

  /// No description provided for @phoneVerifCodeSent.
  ///
  /// In es, this message translates to:
  /// **'Ingresá el código que enviamos a {phone}'**
  String phoneVerifCodeSent(String phone);

  /// No description provided for @phoneVerifErrorDigits.
  ///
  /// In es, this message translates to:
  /// **'Ingresá los 6 dígitos del código'**
  String get phoneVerifErrorDigits;

  /// No description provided for @phoneVerifErrorWrong.
  ///
  /// In es, this message translates to:
  /// **'Código incorrecto. Revisá el SMS.'**
  String get phoneVerifErrorWrong;

  /// No description provided for @phoneVerifErrorExpired.
  ///
  /// In es, this message translates to:
  /// **'El código expiró. Solicitá uno nuevo.'**
  String get phoneVerifErrorExpired;

  /// No description provided for @phoneVerifErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Error al verificar. Intentá de nuevo.'**
  String get phoneVerifErrorGeneric;

  /// No description provided for @phoneVerifErrorUnexpected.
  ///
  /// In es, this message translates to:
  /// **'Error inesperado. Intentá de nuevo.'**
  String get phoneVerifErrorUnexpected;

  /// No description provided for @phoneVerifNoCode.
  ///
  /// In es, this message translates to:
  /// **'¿No recibiste el código? '**
  String get phoneVerifNoCode;

  /// No description provided for @phoneVerifResendIn.
  ///
  /// In es, this message translates to:
  /// **'Reenviar en {seconds}s'**
  String phoneVerifResendIn(int seconds);

  /// No description provided for @phoneVerifResend.
  ///
  /// In es, this message translates to:
  /// **'Reenviar'**
  String get phoneVerifResend;

  /// No description provided for @phoneVerifResendError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reenviar el código. Intentá de nuevo.'**
  String get phoneVerifResendError;

  /// No description provided for @phoneVerifResendSuccess.
  ///
  /// In es, this message translates to:
  /// **'Código reenviado'**
  String get phoneVerifResendSuccess;

  /// No description provided for @phoneVerifButton.
  ///
  /// In es, this message translates to:
  /// **'Verificar código'**
  String get phoneVerifButton;

  /// No description provided for @biometricAuthWelcome.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido de nuevo'**
  String get biometricAuthWelcome;

  /// No description provided for @biometricAuthErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No se pudo verificar'**
  String get biometricAuthErrorTitle;

  /// No description provided for @biometricAuthErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'La verificación falló. Intentá de nuevo o usá otra opción.'**
  String get biometricAuthErrorMessage;

  /// No description provided for @biometricAuthInstruction.
  ///
  /// In es, this message translates to:
  /// **'Confirmá tu identidad con {biometric} para ingresar'**
  String biometricAuthInstruction(String biometric);

  /// No description provided for @biometricAuthRetry.
  ///
  /// In es, this message translates to:
  /// **'Intentar de nuevo'**
  String get biometricAuthRetry;

  /// No description provided for @biometricAuthUse.
  ///
  /// In es, this message translates to:
  /// **'Usar {biometric}'**
  String biometricAuthUse(String biometric);

  /// No description provided for @biometricAuthOtherAccount.
  ///
  /// In es, this message translates to:
  /// **'Usar otra cuenta'**
  String get biometricAuthOtherAccount;

  /// No description provided for @biometricSetupTitle.
  ///
  /// In es, this message translates to:
  /// **'Activar {biometric}'**
  String biometricSetupTitle(String biometric);

  /// No description provided for @biometricSetupDescription.
  ///
  /// In es, this message translates to:
  /// **'Hacé tus próximos ingresos más rápidos y seguros. Solo necesitás tu {biometric} para verificar tu identidad.'**
  String biometricSetupDescription(String biometric);

  /// No description provided for @biometricSetupBenefit1Title.
  ///
  /// In es, this message translates to:
  /// **'Acceso instantáneo'**
  String get biometricSetupBenefit1Title;

  /// No description provided for @biometricSetupBenefit1Desc.
  ///
  /// In es, this message translates to:
  /// **'Sin contraseñas, sin esperas'**
  String get biometricSetupBenefit1Desc;

  /// No description provided for @biometricSetupBenefit2Title.
  ///
  /// In es, this message translates to:
  /// **'Más seguro'**
  String get biometricSetupBenefit2Title;

  /// No description provided for @biometricSetupBenefit2Desc.
  ///
  /// In es, this message translates to:
  /// **'Tu identidad no viaja por internet'**
  String get biometricSetupBenefit2Desc;

  /// No description provided for @biometricSetupBenefit3Title.
  ///
  /// In es, this message translates to:
  /// **'Funciona offline'**
  String get biometricSetupBenefit3Title;

  /// No description provided for @biometricSetupBenefit3Desc.
  ///
  /// In es, this message translates to:
  /// **'No necesitás señal ni SMS'**
  String get biometricSetupBenefit3Desc;

  /// No description provided for @biometricSetupActivate.
  ///
  /// In es, this message translates to:
  /// **'Activar {biometric}'**
  String biometricSetupActivate(String biometric);

  /// No description provided for @biometricSetupSkip.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get biometricSetupSkip;

  /// No description provided for @termsTitle.
  ///
  /// In es, this message translates to:
  /// **'Antes de comenzar'**
  String get termsTitle;

  /// No description provided for @termsCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Aceptar términos'**
  String get termsCardTitle;

  /// No description provided for @termsCardDescription.
  ///
  /// In es, this message translates to:
  /// **'Para usar Nomad necesitamos que aceptes nuestros términos y política de privacidad.'**
  String get termsCardDescription;

  /// No description provided for @termsAcceptPrefix.
  ///
  /// In es, this message translates to:
  /// **'Acepto los '**
  String get termsAcceptPrefix;

  /// No description provided for @termsOfUse.
  ///
  /// In es, this message translates to:
  /// **'Términos de uso'**
  String get termsOfUse;

  /// No description provided for @termsAnd.
  ///
  /// In es, this message translates to:
  /// **' y la '**
  String get termsAnd;

  /// No description provided for @termsPrivacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get termsPrivacyPolicy;

  /// No description provided for @termsAcceptButton.
  ///
  /// In es, this message translates to:
  /// **'Aceptar y continuar'**
  String get termsAcceptButton;

  /// No description provided for @termsFooter.
  ///
  /// In es, this message translates to:
  /// **'Puedes revisar estos documentos más tarde en configuración.'**
  String get termsFooter;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu feed está vacío por ahora'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Seguí a otros nomads o activá\ntu ubicación para ver posts cercanos'**
  String get feedEmptyMessage;

  /// No description provided for @postStepPhotos.
  ///
  /// In es, this message translates to:
  /// **'Elegí tus fotos'**
  String get postStepPhotos;

  /// No description provided for @postStepWrite.
  ///
  /// In es, this message translates to:
  /// **'Contá algo'**
  String get postStepWrite;

  /// No description provided for @postStepMusic.
  ///
  /// In es, this message translates to:
  /// **'Música'**
  String get postStepMusic;

  /// No description provided for @postStepPreview.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get postStepPreview;

  /// No description provided for @postPhotosCounter.
  ///
  /// In es, this message translates to:
  /// **'Hasta 5 fotos • {count}/5'**
  String postPhotosCounter(int count);

  /// No description provided for @postPhotosInfo.
  ///
  /// In es, this message translates to:
  /// **'Podés subir hasta 5 fotos. El orden podrá editarse próximamente.'**
  String get postPhotosInfo;

  /// No description provided for @postDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get postDescriptionLabel;

  /// No description provided for @postDescriptionHint.
  ///
  /// In es, this message translates to:
  /// **'Contá algo sobre este momento...'**
  String get postDescriptionHint;

  /// No description provided for @postLocationLabel.
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get postLocationLabel;

  /// No description provided for @postLocationHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Montevideo, Uruguay'**
  String get postLocationHint;

  /// No description provided for @postMoodLabel.
  ///
  /// In es, this message translates to:
  /// **'Elegí el mood de tu post'**
  String get postMoodLabel;

  /// No description provided for @postMoodChill.
  ///
  /// In es, this message translates to:
  /// **'Chill'**
  String get postMoodChill;

  /// No description provided for @postMoodTravel.
  ///
  /// In es, this message translates to:
  /// **'Viaje'**
  String get postMoodTravel;

  /// No description provided for @postMoodFocus.
  ///
  /// In es, this message translates to:
  /// **'Focus'**
  String get postMoodFocus;

  /// No description provided for @postMoodRomance.
  ///
  /// In es, this message translates to:
  /// **'Romance'**
  String get postMoodRomance;

  /// No description provided for @postMoodEnergy.
  ///
  /// In es, this message translates to:
  /// **'Energía'**
  String get postMoodEnergy;

  /// No description provided for @postMoodParty.
  ///
  /// In es, this message translates to:
  /// **'Fiesta'**
  String get postMoodParty;

  /// No description provided for @postSearchMusicLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar canción'**
  String get postSearchMusicLabel;

  /// No description provided for @postSearchMusicHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Coldplay'**
  String get postSearchMusicHint;

  /// No description provided for @postNoResults.
  ///
  /// In es, this message translates to:
  /// **'No encontramos resultados'**
  String get postNoResults;

  /// No description provided for @postSpotifyNoPreview.
  ///
  /// In es, this message translates to:
  /// **'Spotify no tiene preview para esta canción'**
  String get postSpotifyNoPreview;

  /// No description provided for @postErrorNoPhoto.
  ///
  /// In es, this message translates to:
  /// **'Agregá al menos una foto'**
  String get postErrorNoPhoto;

  /// No description provided for @eventAppBarTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear evento'**
  String get eventAppBarTitle;

  /// No description provided for @eventCoverLabel.
  ///
  /// In es, this message translates to:
  /// **'Foto de portada (opcional)'**
  String get eventCoverLabel;

  /// No description provided for @eventCoverPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Sumá una portada'**
  String get eventCoverPlaceholder;

  /// No description provided for @eventCoverPlaceholderSub.
  ///
  /// In es, this message translates to:
  /// **'Hace tu evento más atractivo'**
  String get eventCoverPlaceholderSub;

  /// No description provided for @eventTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo de evento'**
  String get eventTypeLabel;

  /// No description provided for @eventTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get eventTitleLabel;

  /// No description provided for @eventTitleHint.
  ///
  /// In es, this message translates to:
  /// **'ej: Asado de nomads en Palermo'**
  String get eventTitleHint;

  /// No description provided for @eventTitleError.
  ///
  /// In es, this message translates to:
  /// **'El título es obligatorio'**
  String get eventTitleError;

  /// No description provided for @eventDescLabel.
  ///
  /// In es, this message translates to:
  /// **'Sobre el evento'**
  String get eventDescLabel;

  /// No description provided for @eventDescHint.
  ///
  /// In es, this message translates to:
  /// **'Contá de qué se trata el evento...'**
  String get eventDescHint;

  /// No description provided for @eventDateLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha y hora'**
  String get eventDateLabel;

  /// No description provided for @eventLocationLabel.
  ///
  /// In es, this message translates to:
  /// **'Lugar'**
  String get eventLocationLabel;

  /// No description provided for @eventLocationHint.
  ///
  /// In es, this message translates to:
  /// **'ej: Parque Centenario, CABA'**
  String get eventLocationHint;

  /// No description provided for @eventCapacityLabel.
  ///
  /// In es, this message translates to:
  /// **'Capacidad máxima (opcional)'**
  String get eventCapacityLabel;

  /// No description provided for @eventCapacityHint.
  ///
  /// In es, this message translates to:
  /// **'ej: 30'**
  String get eventCapacityHint;

  /// No description provided for @eventPickDate.
  ///
  /// In es, this message translates to:
  /// **'Elegir fecha'**
  String get eventPickDate;

  /// No description provided for @eventPickTime.
  ///
  /// In es, this message translates to:
  /// **'Elegir hora'**
  String get eventPickTime;

  /// No description provided for @eventCreateButton.
  ///
  /// In es, this message translates to:
  /// **'Crear evento'**
  String get eventCreateButton;

  /// No description provided for @eventSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Evento creado!'**
  String get eventSuccess;

  /// No description provided for @eventErrorDateTime.
  ///
  /// In es, this message translates to:
  /// **'Elegí fecha y hora del evento'**
  String get eventErrorDateTime;

  /// No description provided for @communityTitle.
  ///
  /// In es, this message translates to:
  /// **'Mensaje a la comunidad'**
  String get communityTitle;

  /// No description provided for @communityBanner.
  ///
  /// In es, this message translates to:
  /// **'Compartí información útil con nomads cerca tuyo'**
  String get communityBanner;

  /// No description provided for @communityCategoryLabel.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get communityCategoryLabel;

  /// No description provided for @communityMsgTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título (opcional)'**
  String get communityMsgTitleLabel;

  /// No description provided for @communityMsgTitleHint.
  ///
  /// In es, this message translates to:
  /// **'ej: ¡Reunión de nomads este sábado!'**
  String get communityMsgTitleHint;

  /// No description provided for @communityMsgLabel.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get communityMsgLabel;

  /// No description provided for @communityMsgHint.
  ///
  /// In es, this message translates to:
  /// **'Escribí tu aviso para la comunidad...'**
  String get communityMsgHint;

  /// No description provided for @communityPreviewLabel.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get communityPreviewLabel;

  /// No description provided for @communityMsgError.
  ///
  /// In es, this message translates to:
  /// **'Escribí un mensaje para la comunidad'**
  String get communityMsgError;

  /// No description provided for @communitySendButton.
  ///
  /// In es, this message translates to:
  /// **'Enviar a la comunidad'**
  String get communitySendButton;

  /// No description provided for @communitySuccessMsg.
  ///
  /// In es, this message translates to:
  /// **'¡Mensaje enviado a la comunidad!'**
  String get communitySuccessMsg;

  /// No description provided for @communityErrorMsg.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar. Intentá de nuevo.'**
  String get communityErrorMsg;

  /// No description provided for @communityCatInfo.
  ///
  /// In es, this message translates to:
  /// **'Info'**
  String get communityCatInfo;

  /// No description provided for @communityCatUrgent.
  ///
  /// In es, this message translates to:
  /// **'Urgente'**
  String get communityCatUrgent;

  /// No description provided for @communityCatQuestion.
  ///
  /// In es, this message translates to:
  /// **'Pregunta'**
  String get communityCatQuestion;

  /// No description provided for @communityCatOffer.
  ///
  /// In es, this message translates to:
  /// **'Oferta'**
  String get communityCatOffer;

  /// No description provided for @communityCatAlert.
  ///
  /// In es, this message translates to:
  /// **'Alerta'**
  String get communityCatAlert;

  /// No description provided for @searchPeople.
  ///
  /// In es, this message translates to:
  /// **'Personas'**
  String get searchPeople;

  /// No description provided for @searchEvents.
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get searchEvents;

  /// No description provided for @searchPlaces.
  ///
  /// In es, this message translates to:
  /// **'Lugares'**
  String get searchPlaces;

  /// No description provided for @searchCommunities.
  ///
  /// In es, this message translates to:
  /// **'Comunidades'**
  String get searchCommunities;

  /// No description provided for @searchTips.
  ///
  /// In es, this message translates to:
  /// **'Tips'**
  String get searchTips;

  /// No description provided for @searchJobs.
  ///
  /// In es, this message translates to:
  /// **'Trabajos'**
  String get searchJobs;

  /// No description provided for @mapMigrants.
  ///
  /// In es, this message translates to:
  /// **'Migrantes'**
  String get mapMigrants;

  /// No description provided for @mapConsulates.
  ///
  /// In es, this message translates to:
  /// **'Consulados'**
  String get mapConsulates;

  /// No description provided for @mapRestaurants.
  ///
  /// In es, this message translates to:
  /// **'Restaurantes'**
  String get mapRestaurants;

  /// No description provided for @mapShops.
  ///
  /// In es, this message translates to:
  /// **'Tiendas'**
  String get mapShops;

  /// No description provided for @mapCultural.
  ///
  /// In es, this message translates to:
  /// **'Cultural'**
  String get mapCultural;

  /// No description provided for @mapHelp.
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get mapHelp;

  /// No description provided for @mapBorders.
  ///
  /// In es, this message translates to:
  /// **'Pasos'**
  String get mapBorders;

  /// No description provided for @catAll.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get catAll;

  /// No description provided for @catGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get catGeneral;

  /// No description provided for @catVisas.
  ///
  /// In es, this message translates to:
  /// **'Visas'**
  String get catVisas;

  /// No description provided for @catHousing.
  ///
  /// In es, this message translates to:
  /// **'Alojamiento'**
  String get catHousing;

  /// No description provided for @catWork.
  ///
  /// In es, this message translates to:
  /// **'Trabajo'**
  String get catWork;

  /// No description provided for @catHealth.
  ///
  /// In es, this message translates to:
  /// **'Salud'**
  String get catHealth;

  /// No description provided for @catLanguages.
  ///
  /// In es, this message translates to:
  /// **'Idiomas'**
  String get catLanguages;

  /// No description provided for @catSocial.
  ///
  /// In es, this message translates to:
  /// **'Social'**
  String get catSocial;

  /// No description provided for @catTips.
  ///
  /// In es, this message translates to:
  /// **'Consejos'**
  String get catTips;

  /// No description provided for @profileNoPostsTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no publicaste nada'**
  String get profileNoPostsTitle;

  /// No description provided for @profileNoPostsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Compartí tu experiencia migrante'**
  String get profileNoPostsSubtitle;

  /// No description provided for @profileNoEventsTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin eventos creados'**
  String get profileNoEventsTitle;

  /// No description provided for @profileNoEventsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Organizá encuentros para la comunidad'**
  String get profileNoEventsSubtitle;

  /// No description provided for @profileNoMessagesTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin mensajes aún'**
  String get profileNoMessagesTitle;

  /// No description provided for @profileNoMessagesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Compartí tips, preguntas o experiencias'**
  String get profileNoMessagesSubtitle;

  /// No description provided for @profileEditButton.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEditButton;

  /// No description provided for @profileViewComments.
  ///
  /// In es, this message translates to:
  /// **'Ver comentarios'**
  String get profileViewComments;

  /// No description provided for @profileDeletePostTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar publicación'**
  String get profileDeletePostTitle;

  /// No description provided for @profileDeletePostContent.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro? Esta acción no se puede deshacer.'**
  String get profileDeletePostContent;

  /// No description provided for @profileEditCover.
  ///
  /// In es, this message translates to:
  /// **'Editar portada'**
  String get profileEditCover;

  /// No description provided for @setupLocationPermTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Podemos ver tu ubicación?'**
  String get setupLocationPermTitle;

  /// No description provided for @setupLocationPermDesc.
  ///
  /// In es, this message translates to:
  /// **'Nomad usa tu ubicación para conectarte con compatriotas cercanos. Nunca compartimos tu posición exacta con otros usuarios.'**
  String get setupLocationPermDesc;

  /// No description provided for @setupTrustScoreImpact.
  ///
  /// In es, this message translates to:
  /// **'Impacto en tu Score de Confianza'**
  String get setupTrustScoreImpact;

  /// No description provided for @setupLocationOnlyWhenUsing.
  ///
  /// In es, this message translates to:
  /// **'Permitir solo al usar'**
  String get setupLocationOnlyWhenUsing;

  /// No description provided for @setupLocationAlways.
  ///
  /// In es, this message translates to:
  /// **'Permitir siempre'**
  String get setupLocationAlways;

  /// No description provided for @setupLocationDeny.
  ///
  /// In es, this message translates to:
  /// **'No permitir ahora'**
  String get setupLocationDeny;

  /// No description provided for @setupStepOf.
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de 4'**
  String setupStepOf(int step);

  /// No description provided for @setupUsernameTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige tu nombre de usuario'**
  String get setupUsernameTitle;

  /// No description provided for @setupUsernameSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Este será tu nombre único en Nomad'**
  String get setupUsernameSubtitle;

  /// No description provided for @setupUsernameAvailable.
  ///
  /// In es, this message translates to:
  /// **'Username disponible'**
  String get setupUsernameAvailable;

  /// No description provided for @setupUsernameErrorFormat.
  ///
  /// In es, this message translates to:
  /// **'Entre 6 y 15 caracteres, solo letras, números y _'**
  String get setupUsernameErrorFormat;

  /// No description provided for @setupUsernameErrorMin.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres, solo letras, números y _'**
  String get setupUsernameErrorMin;

  /// No description provided for @setupUsernameTaken.
  ///
  /// In es, this message translates to:
  /// **'Username ya utilizado'**
  String get setupUsernameTaken;

  /// No description provided for @setupNationalityTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cuál es tu nacionalidad?'**
  String get setupNationalityTitle;

  /// No description provided for @setupNationalitySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Conectate con tu gente'**
  String get setupNationalitySubtitle;

  /// No description provided for @setupLocationTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu ubicación actual'**
  String get setupLocationTitle;

  /// No description provided for @setupLocationSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Acercate a tus compatriotas'**
  String get setupLocationSubtitle;

  /// No description provided for @setupLocationError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener la ubicación'**
  String get setupLocationError;

  /// No description provided for @setupGoalsTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué buscás en Nomad?'**
  String get setupGoalsTitle;

  /// No description provided for @setupGoalsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Podés elegir más de una opción'**
  String get setupGoalsSubtitle;

  /// No description provided for @setupGoalFriendship.
  ///
  /// In es, this message translates to:
  /// **'Amistad'**
  String get setupGoalFriendship;

  /// No description provided for @setupGoalDating.
  ///
  /// In es, this message translates to:
  /// **'Citas'**
  String get setupGoalDating;

  /// No description provided for @setupGoalServices.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get setupGoalServices;

  /// No description provided for @setupGoalForums.
  ///
  /// In es, this message translates to:
  /// **'Foros'**
  String get setupGoalForums;

  /// No description provided for @setupTrustScoreDesc.
  ///
  /// In es, this message translates to:
  /// **'Tu score valida tu identidad frente a otros Nomads. Compartir ubicación es uno de los factores que más sube tu score — sin él, tu perfil tendrá menor visibilidad y credibilidad en la comunidad.'**
  String get setupTrustScoreDesc;

  /// No description provided for @setupPermissionInUseSub.
  ///
  /// In es, this message translates to:
  /// **'+Score · Solo cuando Nomad está abierta'**
  String get setupPermissionInUseSub;

  /// No description provided for @setupPermissionRecommended.
  ///
  /// In es, this message translates to:
  /// **'Recomendado'**
  String get setupPermissionRecommended;

  /// No description provided for @setupPermissionAlwaysSub.
  ///
  /// In es, this message translates to:
  /// **'+Score máximo · Acceso completo en todo momento'**
  String get setupPermissionAlwaysSub;

  /// No description provided for @setupPermissionDenySub.
  ///
  /// In es, this message translates to:
  /// **'−Score · Podrás activarlo más tarde desde tu perfil'**
  String get setupPermissionDenySub;

  /// No description provided for @setupLocationDetecting.
  ///
  /// In es, this message translates to:
  /// **'Detectando...'**
  String get setupLocationDetecting;

  /// No description provided for @setupLocationPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Permiso denegado'**
  String get setupLocationPermissionDenied;

  /// No description provided for @setupLocationUpdate.
  ///
  /// In es, this message translates to:
  /// **'Actualizar ubicación'**
  String get setupLocationUpdate;

  /// No description provided for @setupLocationGeolocate.
  ///
  /// In es, this message translates to:
  /// **'GEOLOCALIZAR'**
  String get setupLocationGeolocate;

  /// No description provided for @setupGoalFriendshipDesc.
  ///
  /// In es, this message translates to:
  /// **'Conoce compatriotas'**
  String get setupGoalFriendshipDesc;

  /// No description provided for @setupGoalDatingDesc.
  ///
  /// In es, this message translates to:
  /// **'Conecta romanticamante'**
  String get setupGoalDatingDesc;

  /// No description provided for @setupGoalServicesDesc.
  ///
  /// In es, this message translates to:
  /// **'Empleo y trámites'**
  String get setupGoalServicesDesc;

  /// No description provided for @setupGoalForumsDesc.
  ///
  /// In es, this message translates to:
  /// **'Únete a la charla'**
  String get setupGoalForumsDesc;

  /// No description provided for @setupSearchCountry.
  ///
  /// In es, this message translates to:
  /// **'Buscar país...'**
  String get setupSearchCountry;

  /// No description provided for @setupSelectCountry.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar país'**
  String get setupSelectCountry;

  /// No description provided for @setupNoResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get setupNoResults;

  /// No description provided for @setupUnknownCity.
  ///
  /// In es, this message translates to:
  /// **'Ciudad desconocida'**
  String get setupUnknownCity;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'pt',
    'ru',
    'tr',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
