import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight, dependency-free app localization.
///
/// Deliberately map-based rather than `gen_l10n`/ARB codegen: the CI builds the
/// native project fresh with no generated sources checked in, so a plain Dart
/// lookup table is the safest, most reliable way to ship translations here. Add
/// a language by adding its code to [kSupportedLangs] and a column to [_t];
/// missing keys fall back to English, then to the key itself, so a partial
/// translation never blanks the UI.
///
/// NOTE: these are first-pass translations for the core UI and should get a
/// native-speaker review before a wide store rollout (tracked in qa-audit).

class AppLang {
  final String code; // ISO-639-1
  final String english; // English name
  final String native; // endonym (shown in the picker)
  const AppLang(this.code, this.english, this.native);
}

/// Languages offered in Settings → Language. GlobalMaterialLocalizations ships
/// built-in support for every code here (so dates, pickers, RTL just work).
const List<AppLang> kSupportedLangs = [
  AppLang('en', 'English', 'English'),
  AppLang('hi', 'Hindi', 'हिन्दी'),
  AppLang('bn', 'Bengali', 'বাংলা'),
  AppLang('es', 'Spanish', 'Español'),
  AppLang('pt', 'Portuguese', 'Português'),
  AppLang('fr', 'French', 'Français'),
  AppLang('de', 'German', 'Deutsch'),
  AppLang('ru', 'Russian', 'Русский'),
  AppLang('ar', 'Arabic', 'العربية'),
  AppLang('zh', 'Chinese', '中文'),
  AppLang('ja', 'Japanese', '日本語'),
  AppLang('id', 'Indonesian', 'Indonesia'),
];

List<Locale> get kSupportedLocales =>
    kSupportedLangs.map((l) => Locale(l.code)).toList();

/// Global current-locale controller (persisted). The whole app is wrapped in a
/// listener on this in main.dart, so changing it re-renders every screen.
class LocaleController {
  LocaleController._();
  static const _key = 'kk_lang';
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_key);
      if (c != null && kSupportedLangs.any((l) => l.code == c)) {
        locale.value = Locale(c);
      }
    } catch (_) {/* fall back to English */}
  }

  static Future<void> set(String code) async {
    locale.value = Locale(code);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, code);
    } catch (_) {}
  }
}

/// Translate [key] into the current language (English/​key fallback).
String tr(String key) {
  final code = LocaleController.locale.value.languageCode;
  return _t[code]?[key] ??
      _extra[code]?[key] ??
      _notif[code]?[key] ??
      _repeat[code]?[key] ??
      _voice[code]?[key] ??
      _filter[code]?[key] ??
      _t['en']?[key] ??
      _extra['en']?[key] ??
      _notif['en']?[key] ??
      _repeat['en']?[key] ??
      _voice['en']?[key] ??
      _filter['en']?[key] ??
      key;
}

// ── Translation table ────────────────────────────────────────────────────────
// Keep keys in sync with usages; English is the source of truth.
const Map<String, Map<String, String>> _t = {
  'en': {
    'settings': 'Settings',
    'workspace': 'Workspace',
    'workspace_sub': 'Switch between your companies',
    'theme': 'Theme',
    'system_default': 'System default',
    'light': 'Light',
    'dark': 'Dark',
    'language': 'Language',
    'language_sub': 'Choose your language',
    'export_data': 'Export my data',
    'export_data_sub': 'Download your Kuklabs account data',
    'terms': 'Terms of Use',
    'privacy_policy': 'Privacy Policy',
    'version': 'Version',
    'log_out': 'Log out',
    'delete_account': 'Delete account',
    'delete_account_sub': 'Permanently delete your Kuklabs account',
    'notes': 'Note',
    'search_notes': 'Search notes',
    'start_note': 'Start a note',
    'tpl_blank': 'Blank note',
    'tpl_todo': 'To-do list',
    'tpl_shopping': 'Shopping list',
    'tpl_meeting': 'Meeting notes',
    'tpl_journal': 'Daily journal',
    'tpl_goals': 'Goal & plan',
    'cancel': 'Cancel',
    'close': 'Close',
    'copy': 'Copy',
  },
  'hi': {
    'settings': 'सेटिंग्स',
    'workspace': 'वर्कस्पेस',
    'workspace_sub': 'अपनी कंपनियों के बीच बदलें',
    'theme': 'थीम',
    'system_default': 'सिस्टम डिफ़ॉल्ट',
    'light': 'लाइट',
    'dark': 'डार्क',
    'language': 'भाषा',
    'language_sub': 'अपनी भाषा चुनें',
    'export_data': 'मेरा डेटा निर्यात करें',
    'export_data_sub': 'अपने Kuklabs खाते का डेटा डाउनलोड करें',
    'terms': 'उपयोग की शर्तें',
    'privacy_policy': 'गोपनीयता नीति',
    'version': 'संस्करण',
    'log_out': 'लॉग आउट',
    'delete_account': 'खाता हटाएं',
    'delete_account_sub': 'अपना Kuklabs खाता स्थायी रूप से हटाएं',
    'notes': 'नोट',
    'search_notes': 'नोट खोजें',
    'start_note': 'नया नोट शुरू करें',
    'tpl_blank': 'खाली नोट',
    'tpl_todo': 'कार्य सूची',
    'tpl_shopping': 'खरीदारी सूची',
    'tpl_meeting': 'मीटिंग नोट्स',
    'tpl_journal': 'दैनिक डायरी',
    'tpl_goals': 'लक्ष्य और योजना',
    'cancel': 'रद्द करें',
    'close': 'बंद करें',
    'copy': 'कॉपी करें',
  },
  'bn': {
    'settings': 'সেটিংস',
    'workspace': 'ওয়ার্কস্পেস',
    'workspace_sub': 'আপনার কোম্পানিগুলির মধ্যে পরিবর্তন করুন',
    'theme': 'থিম',
    'system_default': 'সিস্টেম ডিফল্ট',
    'light': 'লাইট',
    'dark': 'ডার্ক',
    'language': 'ভাষা',
    'language_sub': 'আপনার ভাষা নির্বাচন করুন',
    'export_data': 'আমার ডেটা রপ্তানি করুন',
    'export_data_sub': 'আপনার Kuklabs অ্যাকাউন্টের ডেটা ডাউনলোড করুন',
    'terms': 'ব্যবহারের শর্তাবলী',
    'privacy_policy': 'গোপনীয়তা নীতি',
    'version': 'সংস্করণ',
    'log_out': 'লগ আউট',
    'delete_account': 'অ্যাকাউন্ট মুছুন',
    'delete_account_sub': 'আপনার Kuklabs অ্যাকাউন্ট স্থায়ীভাবে মুছুন',
    'notes': 'নোট',
    'search_notes': 'নোট খুঁজুন',
    'start_note': 'নতুন নোট শুরু করুন',
    'tpl_blank': 'খালি নোট',
    'tpl_todo': 'করণীয় তালিকা',
    'tpl_shopping': 'কেনাকাটার তালিকা',
    'tpl_meeting': 'মিটিং নোট',
    'tpl_journal': 'দৈনিক ডায়েরি',
    'tpl_goals': 'লক্ষ্য ও পরিকল্পনা',
    'cancel': 'বাতিল',
    'close': 'বন্ধ',
    'copy': 'কপি',
  },
  'es': {
    'settings': 'Ajustes',
    'workspace': 'Espacio de trabajo',
    'workspace_sub': 'Cambia entre tus empresas',
    'theme': 'Tema',
    'system_default': 'Predeterminado del sistema',
    'light': 'Claro',
    'dark': 'Oscuro',
    'language': 'Idioma',
    'language_sub': 'Elige tu idioma',
    'export_data': 'Exportar mis datos',
    'export_data_sub': 'Descarga los datos de tu cuenta Kuklabs',
    'terms': 'Términos de uso',
    'privacy_policy': 'Política de privacidad',
    'version': 'Versión',
    'log_out': 'Cerrar sesión',
    'delete_account': 'Eliminar cuenta',
    'delete_account_sub': 'Elimina permanentemente tu cuenta Kuklabs',
    'notes': 'Nota',
    'search_notes': 'Buscar notas',
    'start_note': 'Crear una nota',
    'tpl_blank': 'Nota en blanco',
    'tpl_todo': 'Lista de tareas',
    'tpl_shopping': 'Lista de compras',
    'tpl_meeting': 'Notas de reunión',
    'tpl_journal': 'Diario',
    'tpl_goals': 'Objetivo y plan',
    'cancel': 'Cancelar',
    'close': 'Cerrar',
    'copy': 'Copiar',
  },
  'pt': {
    'settings': 'Configurações',
    'workspace': 'Espaço de trabalho',
    'workspace_sub': 'Alterne entre suas empresas',
    'theme': 'Tema',
    'system_default': 'Padrão do sistema',
    'light': 'Claro',
    'dark': 'Escuro',
    'language': 'Idioma',
    'language_sub': 'Escolha seu idioma',
    'export_data': 'Exportar meus dados',
    'export_data_sub': 'Baixe os dados da sua conta Kuklabs',
    'terms': 'Termos de uso',
    'privacy_policy': 'Política de privacidade',
    'version': 'Versão',
    'log_out': 'Sair',
    'delete_account': 'Excluir conta',
    'delete_account_sub': 'Exclua permanentemente sua conta Kuklabs',
    'notes': 'Nota',
    'search_notes': 'Pesquisar notas',
    'start_note': 'Criar uma nota',
    'tpl_blank': 'Nota em branco',
    'tpl_todo': 'Lista de tarefas',
    'tpl_shopping': 'Lista de compras',
    'tpl_meeting': 'Notas de reunião',
    'tpl_journal': 'Diário',
    'tpl_goals': 'Meta e plano',
    'cancel': 'Cancelar',
    'close': 'Fechar',
    'copy': 'Copiar',
  },
  'fr': {
    'settings': 'Paramètres',
    'workspace': 'Espace de travail',
    'workspace_sub': 'Basculez entre vos entreprises',
    'theme': 'Thème',
    'system_default': 'Par défaut du système',
    'light': 'Clair',
    'dark': 'Sombre',
    'language': 'Langue',
    'language_sub': 'Choisissez votre langue',
    'export_data': 'Exporter mes données',
    'export_data_sub': 'Téléchargez les données de votre compte Kuklabs',
    'terms': "Conditions d'utilisation",
    'privacy_policy': 'Politique de confidentialité',
    'version': 'Version',
    'log_out': 'Se déconnecter',
    'delete_account': 'Supprimer le compte',
    'delete_account_sub': 'Supprimez définitivement votre compte Kuklabs',
    'notes': 'Note',
    'search_notes': 'Rechercher des notes',
    'start_note': 'Créer une note',
    'tpl_blank': 'Note vierge',
    'tpl_todo': 'Liste de tâches',
    'tpl_shopping': 'Liste de courses',
    'tpl_meeting': 'Notes de réunion',
    'tpl_journal': 'Journal quotidien',
    'tpl_goals': 'Objectif et plan',
    'cancel': 'Annuler',
    'close': 'Fermer',
    'copy': 'Copier',
  },
  'de': {
    'settings': 'Einstellungen',
    'workspace': 'Arbeitsbereich',
    'workspace_sub': 'Zwischen Ihren Unternehmen wechseln',
    'theme': 'Design',
    'system_default': 'Systemstandard',
    'light': 'Hell',
    'dark': 'Dunkel',
    'language': 'Sprache',
    'language_sub': 'Wählen Sie Ihre Sprache',
    'export_data': 'Meine Daten exportieren',
    'export_data_sub': 'Laden Sie Ihre Kuklabs-Kontodaten herunter',
    'terms': 'Nutzungsbedingungen',
    'privacy_policy': 'Datenschutzrichtlinie',
    'version': 'Version',
    'log_out': 'Abmelden',
    'delete_account': 'Konto löschen',
    'delete_account_sub': 'Löschen Sie Ihr Kuklabs-Konto dauerhaft',
    'notes': 'Notiz',
    'search_notes': 'Notizen suchen',
    'start_note': 'Notiz beginnen',
    'tpl_blank': 'Leere Notiz',
    'tpl_todo': 'Aufgabenliste',
    'tpl_shopping': 'Einkaufsliste',
    'tpl_meeting': 'Besprechungsnotizen',
    'tpl_journal': 'Tägliches Tagebuch',
    'tpl_goals': 'Ziel & Plan',
    'cancel': 'Abbrechen',
    'close': 'Schließen',
    'copy': 'Kopieren',
  },
  'ru': {
    'settings': 'Настройки',
    'workspace': 'Рабочее пространство',
    'workspace_sub': 'Переключайтесь между вашими компаниями',
    'theme': 'Тема',
    'system_default': 'Системная по умолчанию',
    'light': 'Светлая',
    'dark': 'Тёмная',
    'language': 'Язык',
    'language_sub': 'Выберите язык',
    'export_data': 'Экспорт моих данных',
    'export_data_sub': 'Скачать данные вашего аккаунта Kuklabs',
    'terms': 'Условия использования',
    'privacy_policy': 'Политика конфиденциальности',
    'version': 'Версия',
    'log_out': 'Выйти',
    'delete_account': 'Удалить аккаунт',
    'delete_account_sub': 'Безвозвратно удалить ваш аккаунт Kuklabs',
    'notes': 'Заметка',
    'search_notes': 'Поиск заметок',
    'start_note': 'Создать заметку',
    'tpl_blank': 'Пустая заметка',
    'tpl_todo': 'Список дел',
    'tpl_shopping': 'Список покупок',
    'tpl_meeting': 'Заметки о встрече',
    'tpl_journal': 'Ежедневный дневник',
    'tpl_goals': 'Цель и план',
    'cancel': 'Отмена',
    'close': 'Закрыть',
    'copy': 'Копировать',
  },
  'ar': {
    'settings': 'الإعدادات',
    'workspace': 'مساحة العمل',
    'workspace_sub': 'التبديل بين شركاتك',
    'theme': 'المظهر',
    'system_default': 'إعداد النظام الافتراضي',
    'light': 'فاتح',
    'dark': 'داكن',
    'language': 'اللغة',
    'language_sub': 'اختر لغتك',
    'export_data': 'تصدير بياناتي',
    'export_data_sub': 'قم بتنزيل بيانات حساب Kuklabs الخاص بك',
    'terms': 'شروط الاستخدام',
    'privacy_policy': 'سياسة الخصوصية',
    'version': 'الإصدار',
    'log_out': 'تسجيل الخروج',
    'delete_account': 'حذف الحساب',
    'delete_account_sub': 'احذف حساب Kuklabs الخاص بك نهائيًا',
    'notes': 'ملاحظة',
    'search_notes': 'البحث في الملاحظات',
    'start_note': 'إنشاء ملاحظة',
    'tpl_blank': 'ملاحظة فارغة',
    'tpl_todo': 'قائمة المهام',
    'tpl_shopping': 'قائمة التسوق',
    'tpl_meeting': 'ملاحظات الاجتماع',
    'tpl_journal': 'يوميات',
    'tpl_goals': 'الهدف والخطة',
    'cancel': 'إلغاء',
    'close': 'إغلاق',
    'copy': 'نسخ',
  },
  'zh': {
    'settings': '设置',
    'workspace': '工作区',
    'workspace_sub': '在你的公司之间切换',
    'theme': '主题',
    'system_default': '系统默认',
    'light': '浅色',
    'dark': '深色',
    'language': '语言',
    'language_sub': '选择你的语言',
    'export_data': '导出我的数据',
    'export_data_sub': '下载你的 Kuklabs 账户数据',
    'terms': '使用条款',
    'privacy_policy': '隐私政策',
    'version': '版本',
    'log_out': '退出登录',
    'delete_account': '删除账户',
    'delete_account_sub': '永久删除你的 Kuklabs 账户',
    'notes': '笔记',
    'search_notes': '搜索笔记',
    'start_note': '新建笔记',
    'tpl_blank': '空白笔记',
    'tpl_todo': '待办清单',
    'tpl_shopping': '购物清单',
    'tpl_meeting': '会议记录',
    'tpl_journal': '每日日记',
    'tpl_goals': '目标与计划',
    'cancel': '取消',
    'close': '关闭',
    'copy': '复制',
  },
  'ja': {
    'settings': '設定',
    'workspace': 'ワークスペース',
    'workspace_sub': '会社を切り替える',
    'theme': 'テーマ',
    'system_default': 'システムのデフォルト',
    'light': 'ライト',
    'dark': 'ダーク',
    'language': '言語',
    'language_sub': '言語を選択',
    'export_data': 'データをエクスポート',
    'export_data_sub': 'Kuklabs アカウントのデータをダウンロード',
    'terms': '利用規約',
    'privacy_policy': 'プライバシーポリシー',
    'version': 'バージョン',
    'log_out': 'ログアウト',
    'delete_account': 'アカウントを削除',
    'delete_account_sub': 'Kuklabs アカウントを完全に削除します',
    'notes': 'メモ',
    'search_notes': 'メモを検索',
    'start_note': 'メモを作成',
    'tpl_blank': '空白のメモ',
    'tpl_todo': 'ToDo リスト',
    'tpl_shopping': '買い物リスト',
    'tpl_meeting': '会議メモ',
    'tpl_journal': '日記',
    'tpl_goals': '目標と計画',
    'cancel': 'キャンセル',
    'close': '閉じる',
    'copy': 'コピー',
  },
  'id': {
    'settings': 'Pengaturan',
    'workspace': 'Ruang kerja',
    'workspace_sub': 'Beralih antar perusahaan Anda',
    'theme': 'Tema',
    'system_default': 'Bawaan sistem',
    'light': 'Terang',
    'dark': 'Gelap',
    'language': 'Bahasa',
    'language_sub': 'Pilih bahasa Anda',
    'export_data': 'Ekspor data saya',
    'export_data_sub': 'Unduh data akun Kuklabs Anda',
    'terms': 'Ketentuan Penggunaan',
    'privacy_policy': 'Kebijakan Privasi',
    'version': 'Versi',
    'log_out': 'Keluar',
    'delete_account': 'Hapus akun',
    'delete_account_sub': 'Hapus akun Kuklabs Anda secara permanen',
    'notes': 'Catatan',
    'search_notes': 'Cari catatan',
    'start_note': 'Mulai catatan',
    'tpl_blank': 'Catatan kosong',
    'tpl_todo': 'Daftar tugas',
    'tpl_shopping': 'Daftar belanja',
    'tpl_meeting': 'Catatan rapat',
    'tpl_journal': 'Jurnal harian',
    'tpl_goals': 'Tujuan & rencana',
    'cancel': 'Batal',
    'close': 'Tutup',
    'copy': 'Salin',
  },
};

// Additional keys (Settings sections, notifications, editor, OTP). Kept in a
// second table so it can grow without touching the block above.
const Map<String, Map<String, String>> _extra = {
  'en': {
    'account': 'Account', 'notifications': 'Notifications', 'data_privacy': 'Data & Privacy', 'about': 'About',
    'reminders': 'Reminders', 'reminders_sub': 'Show reminder notifications',
    'manage_account': 'Manage account', 'manage_account_sub': 'Manage or delete your account on the web',
    'save': 'Save', 'discard': 'Discard', 'discard_changes': 'Discard changes?', 'keep_editing': 'Keep editing',
    'verify': 'Verify', 'resend_code': 'Resend code',
  },
  'hi': {
    'account': 'खाता', 'notifications': 'सूचनाएं', 'data_privacy': 'डेटा और गोपनीयता', 'about': 'परिचय',
    'reminders': 'रिमाइंडर', 'reminders_sub': 'रिमाइंडर सूचनाएं दिखाएं',
    'manage_account': 'खाता प्रबंधित करें', 'manage_account_sub': 'वेब पर अपना खाता प्रबंधित या हटाएं',
    'save': 'सहेजें', 'discard': 'छोड़ें', 'discard_changes': 'बदलाव छोड़ें?', 'keep_editing': 'संपादन जारी रखें',
    'verify': 'सत्यापित करें', 'resend_code': 'कोड फिर भेजें',
  },
  'bn': {
    'account': 'অ্যাকাউন্ট', 'notifications': 'বিজ্ঞপ্তি', 'data_privacy': 'ডেটা ও গোপনীয়তা', 'about': 'সম্পর্কে',
    'reminders': 'রিমাইন্ডার', 'reminders_sub': 'রিমাইন্ডার বিজ্ঞপ্তি দেখান',
    'manage_account': 'অ্যাকাউন্ট পরিচালনা', 'manage_account_sub': 'ওয়েবে আপনার অ্যাকাউন্ট পরিচালনা বা মুছুন',
    'save': 'সংরক্ষণ', 'discard': 'বাতিল', 'discard_changes': 'পরিবর্তন বাতিল করবেন?', 'keep_editing': 'সম্পাদনা চালিয়ে যান',
    'verify': 'যাচাই করুন', 'resend_code': 'কোড আবার পাঠান',
  },
  'es': {
    'account': 'Cuenta', 'notifications': 'Notificaciones', 'data_privacy': 'Datos y privacidad', 'about': 'Acerca de',
    'reminders': 'Recordatorios', 'reminders_sub': 'Mostrar notificaciones de recordatorio',
    'manage_account': 'Gestionar cuenta', 'manage_account_sub': 'Gestiona o elimina tu cuenta en la web',
    'save': 'Guardar', 'discard': 'Descartar', 'discard_changes': '¿Descartar cambios?', 'keep_editing': 'Seguir editando',
    'verify': 'Verificar', 'resend_code': 'Reenviar código',
  },
  'pt': {
    'account': 'Conta', 'notifications': 'Notificações', 'data_privacy': 'Dados e privacidade', 'about': 'Sobre',
    'reminders': 'Lembretes', 'reminders_sub': 'Mostrar notificações de lembrete',
    'manage_account': 'Gerenciar conta', 'manage_account_sub': 'Gerencie ou exclua sua conta na web',
    'save': 'Salvar', 'discard': 'Descartar', 'discard_changes': 'Descartar alterações?', 'keep_editing': 'Continuar editando',
    'verify': 'Verificar', 'resend_code': 'Reenviar código',
  },
  'fr': {
    'account': 'Compte', 'notifications': 'Notifications', 'data_privacy': 'Données et confidentialité', 'about': 'À propos',
    'reminders': 'Rappels', 'reminders_sub': 'Afficher les notifications de rappel',
    'manage_account': 'Gérer le compte', 'manage_account_sub': 'Gérez ou supprimez votre compte sur le web',
    'save': 'Enregistrer', 'discard': 'Abandonner', 'discard_changes': 'Abandonner les modifications ?', 'keep_editing': 'Continuer',
    'verify': 'Vérifier', 'resend_code': 'Renvoyer le code',
  },
  'de': {
    'account': 'Konto', 'notifications': 'Benachrichtigungen', 'data_privacy': 'Daten & Datenschutz', 'about': 'Über',
    'reminders': 'Erinnerungen', 'reminders_sub': 'Erinnerungsbenachrichtigungen anzeigen',
    'manage_account': 'Konto verwalten', 'manage_account_sub': 'Konto im Web verwalten oder löschen',
    'save': 'Speichern', 'discard': 'Verwerfen', 'discard_changes': 'Änderungen verwerfen?', 'keep_editing': 'Weiter bearbeiten',
    'verify': 'Bestätigen', 'resend_code': 'Code erneut senden',
  },
  'ru': {
    'account': 'Аккаунт', 'notifications': 'Уведомления', 'data_privacy': 'Данные и конфиденциальность', 'about': 'О приложении',
    'reminders': 'Напоминания', 'reminders_sub': 'Показывать уведомления-напоминания',
    'manage_account': 'Управление аккаунтом', 'manage_account_sub': 'Управляйте или удалите аккаунт в вебе',
    'save': 'Сохранить', 'discard': 'Отменить', 'discard_changes': 'Отменить изменения?', 'keep_editing': 'Продолжить',
    'verify': 'Подтвердить', 'resend_code': 'Отправить код повторно',
  },
  'ar': {
    'account': 'الحساب', 'notifications': 'الإشعارات', 'data_privacy': 'البيانات والخصوصية', 'about': 'حول',
    'reminders': 'التذكيرات', 'reminders_sub': 'إظهار إشعارات التذكير',
    'manage_account': 'إدارة الحساب', 'manage_account_sub': 'أدر حسابك أو احذفه على الويب',
    'save': 'حفظ', 'discard': 'تجاهل', 'discard_changes': 'تجاهل التغييرات؟', 'keep_editing': 'متابعة التعديل',
    'verify': 'تحقق', 'resend_code': 'إعادة إرسال الرمز',
  },
  'zh': {
    'account': '账户', 'notifications': '通知', 'data_privacy': '数据与隐私', 'about': '关于',
    'reminders': '提醒', 'reminders_sub': '显示提醒通知',
    'manage_account': '管理账户', 'manage_account_sub': '在网页上管理或删除你的账户',
    'save': '保存', 'discard': '放弃', 'discard_changes': '放弃更改？', 'keep_editing': '继续编辑',
    'verify': '验证', 'resend_code': '重新发送验证码',
  },
  'ja': {
    'account': 'アカウント', 'notifications': '通知', 'data_privacy': 'データとプライバシー', 'about': 'このアプリについて',
    'reminders': 'リマインダー', 'reminders_sub': 'リマインダー通知を表示',
    'manage_account': 'アカウント管理', 'manage_account_sub': 'ウェブでアカウントを管理または削除',
    'save': '保存', 'discard': '破棄', 'discard_changes': '変更を破棄しますか？', 'keep_editing': '編集を続ける',
    'verify': '確認', 'resend_code': 'コードを再送信',
  },
  'id': {
    'account': 'Akun', 'notifications': 'Notifikasi', 'data_privacy': 'Data & Privasi', 'about': 'Tentang',
    'reminders': 'Pengingat', 'reminders_sub': 'Tampilkan notifikasi pengingat',
    'manage_account': 'Kelola akun', 'manage_account_sub': 'Kelola atau hapus akun Anda di web',
    'save': 'Simpan', 'discard': 'Buang', 'discard_changes': 'Buang perubahan?', 'keep_editing': 'Lanjut mengedit',
    'verify': 'Verifikasi', 'resend_code': 'Kirim ulang kode',
  },
};

// Notification / reminder-diagnostics strings (Settings → Notifications).
const Map<String, Map<String, String>> _notif = {
  'en': {'notification_sound': 'Notification sound', 'sound_settings': 'Sound & tone', 'test_reminder': 'Send a test notification', 'test_reminder_sent': 'Sent — one now, one in ~10s (with sound)', 'fix_reminders': 'Reminders not arriving?', 'notifications_blocked': 'Notifications are off — turn them on for Kuk Keep'},
  'hi': {'notification_sound': 'नोटिफ़िकेशन ध्वनि', 'sound_settings': 'ध्वनि और टोन', 'test_reminder': 'टेस्ट नोटिफ़िकेशन भेजें', 'test_reminder_sent': 'भेजा — एक अभी, एक ~10 सेकंड में (ध्वनि के साथ)', 'fix_reminders': 'रिमाइंडर नहीं आ रहे?', 'notifications_blocked': 'नोटिफ़िकेशन बंद हैं — Kuk Keep के लिए चालू करें'},
  'bn': {'notification_sound': 'বিজ্ঞপ্তির শব্দ', 'sound_settings': 'শব্দ ও টোন', 'test_reminder': 'টেস্ট রিমাইন্ডার পাঠান', 'test_reminder_sent': '~৫ সেকেন্ডে টেস্ট রিমাইন্ডার', 'fix_reminders': 'রিমাইন্ডার আসছে না?'},
  'es': {'notification_sound': 'Sonido de notificación', 'sound_settings': 'Sonido y tono', 'test_reminder': 'Enviar recordatorio de prueba', 'test_reminder_sent': 'Recordatorio de prueba en ~5 s', 'fix_reminders': '¿No llegan los recordatorios?'},
  'pt': {'notification_sound': 'Som da notificação', 'sound_settings': 'Som e tom', 'test_reminder': 'Enviar lembrete de teste', 'test_reminder_sent': 'Lembrete de teste em ~5 s', 'fix_reminders': 'Lembretes não chegam?'},
  'fr': {'notification_sound': 'Son de notification', 'sound_settings': 'Son et tonalité', 'test_reminder': 'Envoyer un rappel test', 'test_reminder_sent': 'Rappel test dans ~5 s', 'fix_reminders': 'Rappels non reçus ?'},
  'de': {'notification_sound': 'Benachrichtigungston', 'sound_settings': 'Ton & Klang', 'test_reminder': 'Test-Erinnerung senden', 'test_reminder_sent': 'Test-Erinnerung in ~5 s', 'fix_reminders': 'Erinnerungen kommen nicht an?'},
  'ru': {'notification_sound': 'Звук уведомления', 'sound_settings': 'Звук и сигнал', 'test_reminder': 'Отправить тест-напоминание', 'test_reminder_sent': 'Тест-напоминание через ~5 с', 'fix_reminders': 'Напоминания не приходят?'},
  'ar': {'notification_sound': 'صوت الإشعار', 'sound_settings': 'الصوت والنغمة', 'test_reminder': 'إرسال تذكير تجريبي', 'test_reminder_sent': 'تذكير تجريبي خلال ~5 ثوانٍ', 'fix_reminders': 'التذكيرات لا تصل؟'},
  'zh': {'notification_sound': '通知声音', 'sound_settings': '声音与铃声', 'test_reminder': '发送测试提醒', 'test_reminder_sent': '约5秒后发送测试提醒', 'fix_reminders': '提醒收不到？'},
  'ja': {'notification_sound': '通知音', 'sound_settings': 'サウンドと音', 'test_reminder': 'テスト通知を送信', 'test_reminder_sent': '約5秒後にテスト通知', 'fix_reminders': '通知が届かない？'},
  'id': {'notification_sound': 'Suara notifikasi', 'sound_settings': 'Suara & nada', 'test_reminder': 'Kirim pengingat uji', 'test_reminder_sent': 'Pengingat uji dalam ~5 dtk', 'fix_reminders': 'Pengingat tidak muncul?'},
};

// Reminder + recurrence strings (note editor). tr() falls back to English.
const Map<String, Map<String, String>> _repeat = {
  'en': {'add_reminder': 'Add reminder', 'remove_reminder': 'Remove reminder', 'repeat_none': 'Does not repeat', 'repeat_daily': 'Daily', 'repeat_weekly': 'Weekly', 'repeat_monthly': 'Monthly'},
  'hi': {'add_reminder': 'रिमाइंडर जोड़ें', 'remove_reminder': 'रिमाइंडर हटाएं', 'repeat_none': 'दोहराएं नहीं', 'repeat_daily': 'रोज़ाना', 'repeat_weekly': 'साप्ताहिक', 'repeat_monthly': 'मासिक'},
  'bn': {'add_reminder': 'রিমাইন্ডার যোগ করুন', 'remove_reminder': 'রিমাইন্ডার সরান', 'repeat_none': 'পুনরাবৃত্তি নয়', 'repeat_daily': 'দৈনিক', 'repeat_weekly': 'সাপ্তাহিক', 'repeat_monthly': 'মাসিক'},
  'es': {'add_reminder': 'Añadir recordatorio', 'remove_reminder': 'Quitar recordatorio', 'repeat_none': 'No se repite', 'repeat_daily': 'Diario', 'repeat_weekly': 'Semanal', 'repeat_monthly': 'Mensual'},
  'pt': {'add_reminder': 'Adicionar lembrete', 'remove_reminder': 'Remover lembrete', 'repeat_none': 'Não se repete', 'repeat_daily': 'Diário', 'repeat_weekly': 'Semanal', 'repeat_monthly': 'Mensal'},
  'fr': {'add_reminder': 'Ajouter un rappel', 'remove_reminder': 'Supprimer le rappel', 'repeat_none': 'Ne se répète pas', 'repeat_daily': 'Quotidien', 'repeat_weekly': 'Hebdomadaire', 'repeat_monthly': 'Mensuel'},
  'de': {'add_reminder': 'Erinnerung hinzufügen', 'remove_reminder': 'Erinnerung entfernen', 'repeat_none': 'Wiederholt sich nicht', 'repeat_daily': 'Täglich', 'repeat_weekly': 'Wöchentlich', 'repeat_monthly': 'Monatlich'},
  'ru': {'add_reminder': 'Добавить напоминание', 'remove_reminder': 'Удалить напоминание', 'repeat_none': 'Не повторять', 'repeat_daily': 'Ежедневно', 'repeat_weekly': 'Еженедельно', 'repeat_monthly': 'Ежемесячно'},
  'ar': {'add_reminder': 'إضافة تذكير', 'remove_reminder': 'إزالة التذكير', 'repeat_none': 'لا يتكرر', 'repeat_daily': 'يوميًا', 'repeat_weekly': 'أسبوعيًا', 'repeat_monthly': 'شهريًا'},
  'zh': {'add_reminder': '添加提醒', 'remove_reminder': '移除提醒', 'repeat_none': '不重复', 'repeat_daily': '每天', 'repeat_weekly': '每周', 'repeat_monthly': '每月'},
  'ja': {'add_reminder': 'リマインダーを追加', 'remove_reminder': 'リマインダーを削除', 'repeat_none': '繰り返さない', 'repeat_daily': '毎日', 'repeat_weekly': '毎週', 'repeat_monthly': '毎月'},
  'id': {'add_reminder': 'Tambah pengingat', 'remove_reminder': 'Hapus pengingat', 'repeat_none': 'Tidak berulang', 'repeat_daily': 'Harian', 'repeat_weekly': 'Mingguan', 'repeat_monthly': 'Bulanan'},
};

// Voice-note strings (recorder sheet + audio playback). tr() falls back to English.
const Map<String, Map<String, String>> _voice = {
  'en': {'voice': 'Voice', 'recording': 'Recording…', 'starting': 'Starting…', 'cancel': 'Cancel', 'stop_attach': 'Stop & attach', 'play': 'Play', 'pause': 'Pause'},
  'hi': {'voice': 'आवाज़', 'recording': 'रिकॉर्डिंग…', 'starting': 'शुरू हो रहा है…', 'cancel': 'रद्द करें', 'stop_attach': 'रोकें और जोड़ें', 'play': 'चलाएं', 'pause': 'रोकें'},
  'bn': {'voice': 'ভয়েস', 'recording': 'রেকর্ডিং…', 'starting': 'শুরু হচ্ছে…', 'cancel': 'বাতিল', 'stop_attach': 'থামান ও যোগ করুন', 'play': 'চালান', 'pause': 'বিরতি'},
  'es': {'voice': 'Voz', 'recording': 'Grabando…', 'starting': 'Iniciando…', 'cancel': 'Cancelar', 'stop_attach': 'Detener y adjuntar', 'play': 'Reproducir', 'pause': 'Pausar'},
  'pt': {'voice': 'Voz', 'recording': 'Gravando…', 'starting': 'Iniciando…', 'cancel': 'Cancelar', 'stop_attach': 'Parar e anexar', 'play': 'Reproduzir', 'pause': 'Pausar'},
  'fr': {'voice': 'Voix', 'recording': 'Enregistrement…', 'starting': 'Démarrage…', 'cancel': 'Annuler', 'stop_attach': 'Arrêter et joindre', 'play': 'Lire', 'pause': 'Pause'},
  'de': {'voice': 'Sprache', 'recording': 'Aufnahme…', 'starting': 'Startet…', 'cancel': 'Abbrechen', 'stop_attach': 'Stoppen & anhängen', 'play': 'Abspielen', 'pause': 'Pause'},
  'ru': {'voice': 'Голос', 'recording': 'Запись…', 'starting': 'Запуск…', 'cancel': 'Отмена', 'stop_attach': 'Стоп и прикрепить', 'play': 'Воспроизвести', 'pause': 'Пауза'},
  'ar': {'voice': 'صوت', 'recording': 'جارٍ التسجيل…', 'starting': 'جارٍ البدء…', 'cancel': 'إلغاء', 'stop_attach': 'إيقاف وإرفاق', 'play': 'تشغيل', 'pause': 'إيقاف مؤقت'},
  'zh': {'voice': '语音', 'recording': '录音中…', 'starting': '开始中…', 'cancel': '取消', 'stop_attach': '停止并附加', 'play': '播放', 'pause': '暂停'},
  'ja': {'voice': '音声', 'recording': '録音中…', 'starting': '開始中…', 'cancel': 'キャンセル', 'stop_attach': '停止して添付', 'play': '再生', 'pause': '一時停止'},
  'id': {'voice': 'Suara', 'recording': 'Merekam…', 'starting': 'Memulai…', 'cancel': 'Batal', 'stop_attach': 'Hentikan & lampirkan', 'play': 'Putar', 'pause': 'Jeda'},
};

// Search-filter strings (filter sheet). tr() falls back to English.
const Map<String, Map<String, String>> _filter = {
  'en': {'filters': 'Filters', 'clear': 'Clear', 'filter_type': 'Type', 'filter_note': 'Note', 'filter_checklist': 'Checklist', 'filter_other': 'Other', 'filter_reminder': 'Has reminder', 'filter_attachment': 'Has attachment'},
  'hi': {'filters': 'फ़िल्टर', 'clear': 'साफ़ करें', 'filter_type': 'प्रकार', 'filter_note': 'नोट', 'filter_checklist': 'चेकलिस्ट', 'filter_other': 'अन्य', 'filter_reminder': 'रिमाइंडर वाले', 'filter_attachment': 'अटैचमेंट वाले'},
  'bn': {'filters': 'ফিল্টার', 'clear': 'সাফ', 'filter_type': 'ধরন', 'filter_note': 'নোট', 'filter_checklist': 'চেকলিস্ট', 'filter_other': 'অন্যান্য', 'filter_reminder': 'রিমাইন্ডার আছে', 'filter_attachment': 'অ্যাটাচমেন্ট আছে'},
  'es': {'filters': 'Filtros', 'clear': 'Borrar', 'filter_type': 'Tipo', 'filter_note': 'Nota', 'filter_checklist': 'Lista', 'filter_other': 'Otros', 'filter_reminder': 'Con recordatorio', 'filter_attachment': 'Con adjunto'},
  'pt': {'filters': 'Filtros', 'clear': 'Limpar', 'filter_type': 'Tipo', 'filter_note': 'Nota', 'filter_checklist': 'Lista', 'filter_other': 'Outros', 'filter_reminder': 'Com lembrete', 'filter_attachment': 'Com anexo'},
  'fr': {'filters': 'Filtres', 'clear': 'Effacer', 'filter_type': 'Type', 'filter_note': 'Note', 'filter_checklist': 'Liste', 'filter_other': 'Autres', 'filter_reminder': 'Avec rappel', 'filter_attachment': 'Avec pièce jointe'},
  'de': {'filters': 'Filter', 'clear': 'Löschen', 'filter_type': 'Typ', 'filter_note': 'Notiz', 'filter_checklist': 'Liste', 'filter_other': 'Andere', 'filter_reminder': 'Mit Erinnerung', 'filter_attachment': 'Mit Anhang'},
  'ru': {'filters': 'Фильтры', 'clear': 'Очистить', 'filter_type': 'Тип', 'filter_note': 'Заметка', 'filter_checklist': 'Список', 'filter_other': 'Другое', 'filter_reminder': 'С напоминанием', 'filter_attachment': 'С вложением'},
  'ar': {'filters': 'عوامل التصفية', 'clear': 'مسح', 'filter_type': 'النوع', 'filter_note': 'ملاحظة', 'filter_checklist': 'قائمة', 'filter_other': 'أخرى', 'filter_reminder': 'بها تذكير', 'filter_attachment': 'بها مرفق'},
  'zh': {'filters': '筛选', 'clear': '清除', 'filter_type': '类型', 'filter_note': '笔记', 'filter_checklist': '清单', 'filter_other': '其他', 'filter_reminder': '有提醒', 'filter_attachment': '有附件'},
  'ja': {'filters': 'フィルター', 'clear': 'クリア', 'filter_type': '種類', 'filter_note': 'メモ', 'filter_checklist': 'チェックリスト', 'filter_other': 'その他', 'filter_reminder': 'リマインダーあり', 'filter_attachment': '添付あり'},
  'id': {'filters': 'Filter', 'clear': 'Hapus', 'filter_type': 'Jenis', 'filter_note': 'Catatan', 'filter_checklist': 'Daftar', 'filter_other': 'Lainnya', 'filter_reminder': 'Ada pengingat', 'filter_attachment': 'Ada lampiran'},
};
