import 'data/api_client.dart';
import 'data/entry_prefs_repository.dart';
import 'data/fake_api_client.dart';
import 'data/history_fields.dart';
import 'data/history_repository.dart';
import 'data/local_entry_prefs_repository.dart';
import 'data/local_history_repository.dart';

class AppServices {
  AppServices._();

  static final ApiClient api = FakeApiClient();
  static final EntryPrefsRepository entryPrefs = LocalEntryPrefsRepository();
  static final HistoryRepository history = LocalHistoryRepository(
    seed: {
      /// -----------------------------
      /// DEFAULT DESCRIPTIONS
      /// -----------------------------
      HistoryField.description: [
        'Grocery Store',
        'Gas Station',
        'Coffee Shop',
        'Restaurant',
        'Takeout / Delivery',
        'Convenience Store',
        'Utility Bill',
        'Internet Bill',
        'Phone Bill',
        'Subscription Service',
        'Insurance Payment',
        'Retail Purchase',
        'Online Purchase',
        'Household Supplies',
        'Clothing Purchase',
        'Public Transportation',
        'Parking',
        'Ride Share',
        'Travel Expense',
        'Bank Fee',
        'Service Fee',
        'Membership Fee',
        'Gift',
        'Miscellaneous Expense',
      ],

      /// -----------------------------
      /// DEFAULT CATEGORIES
      /// -----------------------------
      HistoryField.category: [
        'Grocery',
        'Dining',
        'Coffee',
        'Gas',
        'Transportation',
        'Utilities',
        'Rent',
        'Mortgage',
        'Insurance',
        'Internet',
        'Phone',
        'Subscription',
        'Streaming',
        'Software',
        'Retail',
        'Clothing',
        'Electronics',
        'Household',
        'Personal Care',
        'Health',
        'Medical',
        'Pharmacy',
        'Fitness',
        'Entertainment',
        'Travel',
        'Hobbies',
        'Education',
        'Gifts',
        'Charity',
        'Services',
        'Fees',
        'Interest',
        'Other',
      ],

      /// -----------------------------
      /// DEFAULT SOURCES
      /// -----------------------------
      HistoryField.source: [
        'Checking',
        'Savings',
        'Credit Card',
        'Debit Card',
        'Cash',
        'Chase',
        'Bank of America',
        'Wells Fargo',
        'Citi',
        'Capital One',
        'Discover',
        'American Express',
        'Fidelity',
        'Schwab',
        'Vanguard',
        'Apple Pay',
        'Google Pay',
        'PayPal',
        'Venmo',
        'Zelle',
        'Gift Card',
        'Employer',
        'Reimbursement',
        'Other',
      ],
    },
  );
}
