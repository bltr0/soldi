/// Display-only catalogue of currencies an account can be held in.
///
/// Amounts are never converted between currencies: the code and symbol are
/// only used to label what an account holds. ISO 4217 codes, plus a few
/// common crypto and precious-metal units.
class CurrencyInfo {
  const CurrencyInfo(this.code, this.symbol, this.name);

  /// ISO 4217 code, e.g. `EUR`.
  final String code;

  /// Short symbol shown next to amounts, e.g. `€`.
  final String symbol;

  /// English name, e.g. `Euro`.
  final String name;
}

class CurrencyCatalog {
  CurrencyCatalog._();

  static const List<CurrencyInfo> all = [
    CurrencyInfo('AED', 'د.إ', 'UAE Dirham'),
    CurrencyInfo('AFN', '؋', 'Afghan Afghani'),
    CurrencyInfo('ALL', 'L', 'Albanian Lek'),
    CurrencyInfo('AMD', '֏', 'Armenian Dram'),
    CurrencyInfo('ANG', 'ƒ', 'Netherlands Antillean Guilder'),
    CurrencyInfo('AOA', 'Kz', 'Angolan Kwanza'),
    CurrencyInfo('ARS', '\$', 'Argentine Peso'),
    CurrencyInfo('AUD', 'A\$', 'Australian Dollar'),
    CurrencyInfo('AWG', 'ƒ', 'Aruban Florin'),
    CurrencyInfo('AZN', '₼', 'Azerbaijani Manat'),
    CurrencyInfo('BAM', 'KM', 'Bosnia-Herzegovina Mark'),
    CurrencyInfo('BBD', 'Bds\$', 'Barbadian Dollar'),
    CurrencyInfo('BDT', '৳', 'Bangladeshi Taka'),
    CurrencyInfo('BGN', 'лв', 'Bulgarian Lev'),
    CurrencyInfo('BHD', 'BD', 'Bahraini Dinar'),
    CurrencyInfo('BIF', 'FBu', 'Burundian Franc'),
    CurrencyInfo('BMD', '\$', 'Bermudian Dollar'),
    CurrencyInfo('BND', 'B\$', 'Brunei Dollar'),
    CurrencyInfo('BOB', 'Bs.', 'Bolivian Boliviano'),
    CurrencyInfo('BRL', 'R\$', 'Brazilian Real'),
    CurrencyInfo('BSD', 'B\$', 'Bahamian Dollar'),
    CurrencyInfo('BTN', 'Nu.', 'Bhutanese Ngultrum'),
    CurrencyInfo('BWP', 'P', 'Botswana Pula'),
    CurrencyInfo('BYN', 'Br', 'Belarusian Ruble'),
    CurrencyInfo('BZD', 'BZ\$', 'Belize Dollar'),
    CurrencyInfo('CAD', 'C\$', 'Canadian Dollar'),
    CurrencyInfo('CDF', 'FC', 'Congolese Franc'),
    CurrencyInfo('CHF', 'CHF', 'Swiss Franc'),
    CurrencyInfo('CLP', '\$', 'Chilean Peso'),
    CurrencyInfo('CNY', '¥', 'Chinese Yuan'),
    CurrencyInfo('COP', '\$', 'Colombian Peso'),
    CurrencyInfo('CRC', '₡', 'Costa Rican Colón'),
    CurrencyInfo('CUP', '\$', 'Cuban Peso'),
    CurrencyInfo('CVE', 'Esc', 'Cape Verdean Escudo'),
    CurrencyInfo('CZK', 'Kč', 'Czech Koruna'),
    CurrencyInfo('DJF', 'Fdj', 'Djiboutian Franc'),
    CurrencyInfo('DKK', 'kr', 'Danish Krone'),
    CurrencyInfo('DOP', 'RD\$', 'Dominican Peso'),
    CurrencyInfo('DZD', 'DA', 'Algerian Dinar'),
    CurrencyInfo('EGP', 'E£', 'Egyptian Pound'),
    CurrencyInfo('ERN', 'Nfk', 'Eritrean Nakfa'),
    CurrencyInfo('ETB', 'Br', 'Ethiopian Birr'),
    CurrencyInfo('EUR', '€', 'Euro'),
    CurrencyInfo('FJD', 'FJ\$', 'Fijian Dollar'),
    CurrencyInfo('FKP', '£', 'Falkland Islands Pound'),
    CurrencyInfo('GBP', '£', 'British Pound'),
    CurrencyInfo('GEL', '₾', 'Georgian Lari'),
    CurrencyInfo('GHS', 'GH₵', 'Ghanaian Cedi'),
    CurrencyInfo('GIP', '£', 'Gibraltar Pound'),
    CurrencyInfo('GMD', 'D', 'Gambian Dalasi'),
    CurrencyInfo('GNF', 'FG', 'Guinean Franc'),
    CurrencyInfo('GTQ', 'Q', 'Guatemalan Quetzal'),
    CurrencyInfo('GYD', 'G\$', 'Guyanese Dollar'),
    CurrencyInfo('HKD', 'HK\$', 'Hong Kong Dollar'),
    CurrencyInfo('HNL', 'L', 'Honduran Lempira'),
    CurrencyInfo('HTG', 'G', 'Haitian Gourde'),
    CurrencyInfo('HUF', 'Ft', 'Hungarian Forint'),
    CurrencyInfo('IDR', 'Rp', 'Indonesian Rupiah'),
    CurrencyInfo('ILS', '₪', 'Israeli New Shekel'),
    CurrencyInfo('INR', '₹', 'Indian Rupee'),
    CurrencyInfo('IQD', 'ع.د', 'Iraqi Dinar'),
    CurrencyInfo('IRR', '﷼', 'Iranian Rial'),
    CurrencyInfo('ISK', 'kr', 'Icelandic Króna'),
    CurrencyInfo('JMD', 'J\$', 'Jamaican Dollar'),
    CurrencyInfo('JOD', 'JD', 'Jordanian Dinar'),
    CurrencyInfo('JPY', '¥', 'Japanese Yen'),
    CurrencyInfo('KES', 'KSh', 'Kenyan Shilling'),
    CurrencyInfo('KGS', 'сом', 'Kyrgyzstani Som'),
    CurrencyInfo('KHR', '៛', 'Cambodian Riel'),
    CurrencyInfo('KMF', 'CF', 'Comorian Franc'),
    CurrencyInfo('KPW', '₩', 'North Korean Won'),
    CurrencyInfo('KRW', '₩', 'South Korean Won'),
    CurrencyInfo('KWD', 'KD', 'Kuwaiti Dinar'),
    CurrencyInfo('KYD', 'CI\$', 'Cayman Islands Dollar'),
    CurrencyInfo('KZT', '₸', 'Kazakhstani Tenge'),
    CurrencyInfo('LAK', '₭', 'Lao Kip'),
    CurrencyInfo('LBP', 'L£', 'Lebanese Pound'),
    CurrencyInfo('LKR', 'Rs', 'Sri Lankan Rupee'),
    CurrencyInfo('LRD', 'L\$', 'Liberian Dollar'),
    CurrencyInfo('LSL', 'L', 'Lesotho Loti'),
    CurrencyInfo('LYD', 'LD', 'Libyan Dinar'),
    CurrencyInfo('MAD', 'DH', 'Moroccan Dirham'),
    CurrencyInfo('MDL', 'L', 'Moldovan Leu'),
    CurrencyInfo('MGA', 'Ar', 'Malagasy Ariary'),
    CurrencyInfo('MKD', 'ден', 'Macedonian Denar'),
    CurrencyInfo('MMK', 'K', 'Myanmar Kyat'),
    CurrencyInfo('MNT', '₮', 'Mongolian Tögrög'),
    CurrencyInfo('MOP', 'MOP\$', 'Macanese Pataca'),
    CurrencyInfo('MRU', 'UM', 'Mauritanian Ouguiya'),
    CurrencyInfo('MUR', '₨', 'Mauritian Rupee'),
    CurrencyInfo('MVR', 'Rf', 'Maldivian Rufiyaa'),
    CurrencyInfo('MWK', 'MK', 'Malawian Kwacha'),
    CurrencyInfo('MXN', 'Mex\$', 'Mexican Peso'),
    CurrencyInfo('MYR', 'RM', 'Malaysian Ringgit'),
    CurrencyInfo('MZN', 'MT', 'Mozambican Metical'),
    CurrencyInfo('NAD', 'N\$', 'Namibian Dollar'),
    CurrencyInfo('NGN', '₦', 'Nigerian Naira'),
    CurrencyInfo('NIO', 'C\$', 'Nicaraguan Córdoba'),
    CurrencyInfo('NOK', 'kr', 'Norwegian Krone'),
    CurrencyInfo('NPR', 'Rs', 'Nepalese Rupee'),
    CurrencyInfo('NZD', 'NZ\$', 'New Zealand Dollar'),
    CurrencyInfo('OMR', '﷼', 'Omani Rial'),
    CurrencyInfo('PAB', 'B/.', 'Panamanian Balboa'),
    CurrencyInfo('PEN', 'S/', 'Peruvian Sol'),
    CurrencyInfo('PGK', 'K', 'Papua New Guinean Kina'),
    CurrencyInfo('PHP', '₱', 'Philippine Peso'),
    CurrencyInfo('PKR', 'Rs', 'Pakistani Rupee'),
    CurrencyInfo('PLN', 'zł', 'Polish Złoty'),
    CurrencyInfo('PYG', '₲', 'Paraguayan Guaraní'),
    CurrencyInfo('QAR', 'QR', 'Qatari Riyal'),
    CurrencyInfo('RON', 'lei', 'Romanian Leu'),
    CurrencyInfo('RSD', 'din', 'Serbian Dinar'),
    CurrencyInfo('RUB', '₽', 'Russian Ruble'),
    CurrencyInfo('RWF', 'FRw', 'Rwandan Franc'),
    CurrencyInfo('SAR', 'SR', 'Saudi Riyal'),
    CurrencyInfo('SBD', 'SI\$', 'Solomon Islands Dollar'),
    CurrencyInfo('SCR', 'SR', 'Seychellois Rupee'),
    CurrencyInfo('SDG', '£SD', 'Sudanese Pound'),
    CurrencyInfo('SEK', 'kr', 'Swedish Krona'),
    CurrencyInfo('SGD', 'S\$', 'Singapore Dollar'),
    CurrencyInfo('SHP', '£', 'Saint Helena Pound'),
    CurrencyInfo('SLE', 'Le', 'Sierra Leonean Leone'),
    CurrencyInfo('SOS', 'Sh', 'Somali Shilling'),
    CurrencyInfo('SRD', '\$', 'Surinamese Dollar'),
    CurrencyInfo('SSP', 'SS£', 'South Sudanese Pound'),
    CurrencyInfo('STN', 'Db', 'São Tomé and Príncipe Dobra'),
    CurrencyInfo('SYP', '£S', 'Syrian Pound'),
    CurrencyInfo('SZL', 'E', 'Eswatini Lilangeni'),
    CurrencyInfo('THB', '฿', 'Thai Baht'),
    CurrencyInfo('TJS', 'SM', 'Tajikistani Somoni'),
    CurrencyInfo('TMT', 'm', 'Turkmenistani Manat'),
    CurrencyInfo('TND', 'DT', 'Tunisian Dinar'),
    CurrencyInfo('TOP', 'T\$', 'Tongan Paʻanga'),
    CurrencyInfo('TRY', '₺', 'Turkish Lira'),
    CurrencyInfo('TTD', 'TT\$', 'Trinidad and Tobago Dollar'),
    CurrencyInfo('TWD', 'NT\$', 'New Taiwan Dollar'),
    CurrencyInfo('TZS', 'TSh', 'Tanzanian Shilling'),
    CurrencyInfo('UAH', '₴', 'Ukrainian Hryvnia'),
    CurrencyInfo('UGX', 'USh', 'Ugandan Shilling'),
    CurrencyInfo('USD', '\$', 'US Dollar'),
    CurrencyInfo('UYU', '\$U', 'Uruguayan Peso'),
    CurrencyInfo('UZS', 'soʻm', 'Uzbekistani Som'),
    CurrencyInfo('VES', 'Bs.S', 'Venezuelan Bolívar'),
    CurrencyInfo('VND', '₫', 'Vietnamese Đồng'),
    CurrencyInfo('VUV', 'VT', 'Vanuatu Vatu'),
    CurrencyInfo('WST', 'WS\$', 'Samoan Tālā'),
    CurrencyInfo('XAF', 'FCFA', 'Central African CFA Franc'),
    CurrencyInfo('XCD', 'EC\$', 'East Caribbean Dollar'),
    CurrencyInfo('XOF', 'CFA', 'West African CFA Franc'),
    CurrencyInfo('XPF', '₣', 'CFP Franc'),
    CurrencyInfo('YER', '﷼', 'Yemeni Rial'),
    CurrencyInfo('ZAR', 'R', 'South African Rand'),
    CurrencyInfo('ZMW', 'ZK', 'Zambian Kwacha'),
    CurrencyInfo('ZWG', 'ZiG', 'Zimbabwe Gold'),
    CurrencyInfo('BTC', '₿', 'Bitcoin'),
    CurrencyInfo('ETH', 'Ξ', 'Ether'),
    CurrencyInfo('XAU', 'XAU', 'Gold (troy ounce)'),
    CurrencyInfo('XAG', 'XAG', 'Silver (troy ounce)'),
  ];

  static final Map<String, CurrencyInfo> _byCode = {
    for (final currency in all) currency.code: currency,
  };

  /// The catalogue entry for [code], or null when the code is unknown.
  static CurrencyInfo? byCode(String? code) =>
      code == null ? null : _byCode[code.toUpperCase()];

  /// Currencies without a minor unit in everyday use (no cents).
  static const Set<String> _zeroDecimal = {
    'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF',
    'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF',
  };

  /// Number of decimals amounts in [code] are shown with.
  static int decimalsFor(String? code) =>
      code != null && _zeroDecimal.contains(code.toUpperCase()) ? 0 : 2;

  /// Symbol for [code]; unknown codes are shown as the code itself.
  static String symbolFor(String code) => byCode(code)?.symbol ?? code;

  /// Entries whose code or name contains [query], case-insensitively.
  static List<CurrencyInfo> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q) ||
              c.symbol.toLowerCase() == q,
        )
        .toList();
  }
}
