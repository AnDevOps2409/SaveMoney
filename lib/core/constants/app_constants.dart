class AppConstants {
  // App Info
  static const String appName = 'SaveMoney';
  static const String appVersion = '1.0.0';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String walletsCollection = 'wallets';
  static const String transactionsCollection = 'transactions';
  static const String categoriesCollection = 'categories';
  static const String budgetsCollection = 'budgets';
  static const String remindersCollection = 'reminders';

  // Transaction Types
  static const String typeExpense = 'expense';
  static const String typeIncome = 'income';
  static const String typeTransfer = 'transfer';

  // Wallet Types
  static const String walletCash = 'cash';
  static const String walletBank = 'bank';
  static const String walletEwallet = 'ewallet';
  static const String walletCreditCard = 'credit_card';

  // Default currency
  static const String defaultCurrency = 'VND';
  static const String defaultLocale = 'vi_VN';

  // Periods
  static const String periodDay = 'day';
  static const String periodWeek = 'week';
  static const String periodMonth = 'month';
  static const String periodYear = 'year';
}
