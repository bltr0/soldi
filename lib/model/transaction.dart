import 'package:flutter/material.dart';

import '../constants/style.dart';
import 'base_entity.dart';
import 'category_transaction.dart';

const String transactionTable = 'transaction';

class TransactionFields extends BaseEntityFields {
  static String id = BaseEntityFields.getId;
  static String date = 'date';
  static String amount = 'amount';
  static String type = 'type';
  static String note = 'note';
  static String idCategory = 'idCategory'; // FK
  static String categoryName = 'categoryName';
  static String categoryColor = 'categoryColor';
  static String categorySymbol = 'categorySymbol';
  static String categoryParent = 'categoryParent';
  static String idBankAccount = 'idBankAccount'; // FK
  static String bankAccountName = 'bankAccountName';
  static String idBankAccountTransfer = 'idBankAccountTransfer';
  static String bankAccountTransferName = 'bankAccountTransferName';
  static String peopleConcerned = 'peopleConcerned';
  static String reimbursementDue = 'reimbursementDue';
  static String recurring = 'recurring';
  static String idRecurringTransaction = 'idRecurringTransaction';
  static String createdAt = BaseEntityFields.getCreatedAt;
  static String updatedAt = BaseEntityFields.getUpdatedAt;

  static final List<String> allFields = [
    BaseEntityFields.id,
    date,
    amount,
    type,
    note,
    idCategory,
    idBankAccount,
    idBankAccountTransfer,
    peopleConcerned,
    reimbursementDue,
    recurring,
    idRecurringTransaction,
    BaseEntityFields.createdAt,
    BaseEntityFields.updatedAt,
  ];
}

enum TransactionType {
  income,
  expense,
  transfer,
  adjustment;

  static const List<TransactionType> userSelectable = [
    TransactionType.income,
    TransactionType.expense,
    TransactionType.transfer,
  ];

  String get code => switch (this) {
    TransactionType.income => "IN",
    TransactionType.expense => "OUT",
    TransactionType.transfer => "TRSF",
    TransactionType.adjustment => "ADJ",
  };

  CategoryTransactionType? get categoryType => switch (this) {
    TransactionType.income => CategoryTransactionType.income,
    TransactionType.expense => CategoryTransactionType.expense,
    TransactionType.transfer => null,
    TransactionType.adjustment => null,
  };

  String get prefix => switch (this) {
    TransactionType.expense => "-",
    _ => "",
  };

  Color toColor({Brightness brightness = Brightness.light}) {
    switch (this) {
      case TransactionType.income:
        return green;
      case TransactionType.expense:
        return red;
      case TransactionType.transfer:
        if (brightness == Brightness.light) {
          return blue3;
        }
        return darkBlue6;
      case TransactionType.adjustment:
        return brightness == Brightness.light ? grey1 : darkGrey1;
    }
  }

  static TransactionType fromJson(String code) =>
      TransactionType.values.firstWhere((e) => e.code == code);

  String toJson() => code;
}

class Transaction extends BaseEntity {
  // This is to allow to manually set a null value to id field.
  static const _unset = Object();

  final DateTime date;
  final num amount;
  final TransactionType type;
  final String? note;
  final int? idCategory;
  final String? categoryName;
  final int? categoryColor;
  final String? categorySymbol;
  final int? categoryParent;
  final int idBankAccount;
  final String? bankAccountName;
  final int? idBankAccountTransfer;
  final String? bankAccountTransferName;
  final int peopleConcerned;

  /// True when this expense was paid for other people and they have not
  /// paid it back yet.
  final bool reimbursementDue;
  final bool recurring;
  final int? idRecurringTransaction;

  const Transaction({
    super.id,
    required this.date,
    required this.amount,
    required this.type,
    this.note,
    this.idCategory,
    this.categoryName,
    this.categoryColor,
    this.categorySymbol,
    this.categoryParent,
    required this.idBankAccount,
    this.bankAccountName,
    this.idBankAccountTransfer,
    this.bankAccountTransferName,
    this.peopleConcerned = 1,
    this.reimbursementDue = false,
    required this.recurring,
    this.idRecurringTransaction,
    super.createdAt,
    super.updatedAt,
  });

  /// Account reset: not cashflow. Includes legacy CSV rows still stored as IN/OUT.
  bool get isBalanceReset =>
      type == TransactionType.adjustment || note == 'Reconciliation';

  /// Equal split of what the other people still owe. A 4 payment shared by
  /// 2 people is due 2, because one share is yours.
  num get splitDue => peopleConcerned <= 1
      ? 0
      : amount * (peopleConcerned - 1) / peopleConcerned;

  Transaction copy({
    Object? id = _unset,
    DateTime? date,
    num? amount,
    TransactionType? type,
    String? note,
    Object? idCategory = _unset,
    int? idBankAccount,
    Object? idBankAccountTransfer = _unset,
    int? peopleConcerned,
    bool? reimbursementDue,
    bool? recurring,
    int? idRecurringTransaction,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transaction(
    id: id == _unset ? this.id : (id as int?),
    date: date ?? this.date,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    note: note ?? this.note,
    idCategory: idCategory == _unset ? this.idCategory : idCategory as int?,
    idBankAccount: idBankAccount ?? this.idBankAccount,
    idBankAccountTransfer: idBankAccountTransfer == _unset
        ? this.idBankAccountTransfer
        : idBankAccountTransfer as int?,
    peopleConcerned: peopleConcerned ?? this.peopleConcerned,
    reimbursementDue: reimbursementDue ?? this.reimbursementDue,
    recurring: recurring ?? this.recurring,
    idRecurringTransaction:
        idRecurringTransaction ?? this.idRecurringTransaction,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static Transaction fromJson(Map<String, Object?> json) {
    return Transaction(
      id: json[BaseEntityFields.id] as int?,
      date: DateTime.parse(json[TransactionFields.date] as String),
      amount: json[TransactionFields.amount] as num,
      type: TransactionType.fromJson(json[TransactionFields.type] as String),
      note: json[TransactionFields.note] as String?,
      idCategory: json[TransactionFields.idCategory] as int?,
      categoryName: json[TransactionFields.categoryName] as String?,
      categoryColor: json[TransactionFields.categoryColor] as int?,
      categorySymbol: json[TransactionFields.categorySymbol] as String?,
      categoryParent: json[TransactionFields.categoryParent] as int?,
      idBankAccount: json[TransactionFields.idBankAccount] as int,
      bankAccountName: json[TransactionFields.bankAccountName] as String?,
      idBankAccountTransfer:
          json[TransactionFields.idBankAccountTransfer] as int?,
      bankAccountTransferName:
          json[TransactionFields.bankAccountTransferName] as String?,
      peopleConcerned: json[TransactionFields.peopleConcerned] as int? ?? 1,
      reimbursementDue: json[TransactionFields.reimbursementDue] == 1,
      recurring: json[TransactionFields.recurring] == 1,
      idRecurringTransaction:
          json[TransactionFields.idRecurringTransaction] as int?,
      createdAt: DateTime.parse(json[BaseEntityFields.createdAt] as String),
      updatedAt: DateTime.parse(json[BaseEntityFields.updatedAt] as String),
    );
  }

  Map<String, Object?> toJson({bool update = false}) {
    final createdAtDate = update
        ? createdAt?.toIso8601String()
        : DateTime.now().toIso8601String();

    return {
      TransactionFields.id: id,
      TransactionFields.date: date.toIso8601String(),
      TransactionFields.amount: amount,
      TransactionFields.type: type.toJson(),
      TransactionFields.note: note,
      TransactionFields.idCategory: idCategory,
      TransactionFields.idBankAccount: idBankAccount,
      TransactionFields.idBankAccountTransfer: idBankAccountTransfer,
      TransactionFields.peopleConcerned: peopleConcerned,
      TransactionFields.reimbursementDue: reimbursementDue ? 1 : 0,
      TransactionFields.recurring: recurring ? 1 : 0,
      TransactionFields.idRecurringTransaction: idRecurringTransaction,
      BaseEntityFields.createdAt: createdAtDate,
      BaseEntityFields.updatedAt: DateTime.now().toIso8601String(),
    };
  }
}
