/// Currency model for product pricing
class Currency {
  final String code;      // USD, TRY, YER, SAR, EUR
  final String symbol;    // $, ₺, ﷼, ﷳ, €
  final String name;      // Display name
  final int id;           // Database ID

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.id,
  });

  @override
  String toString() => '$symbol $name';

  static const Map<int, Currency> currencies = {
    1: Currency(code: 'USD', symbol: '\$', name: 'US Dollar', id: 1),
    2: Currency(code: 'TRY', symbol: '₺', name: 'Turkish Lira', id: 2),
    3: Currency(code: 'YER', symbol: '﷼', name: 'Yemeni Rial', id: 3),
    4: Currency(code: 'SAR', symbol: 'ر.س', name: 'Saudi Riyal', id: 4),
    5: Currency(code: 'EUR', symbol: '€', name: 'Euro', id: 5),
  };

  static Currency? fromCode(String code) {
    try {
      return currencies.values.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  static Currency? fromId(int id) => currencies[id];

  static List<Currency> getAll() => currencies.values.toList();
}
