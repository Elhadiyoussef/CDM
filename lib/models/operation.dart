import '../utils/dates.dart';
import 'enums.dart';

class Operation {
  Operation({
    required this.id,
    required this.contratId,
    required this.type,
    required this.montant,
    required this.date,
    this.statut = StatutOperation.executee,
    this.libelle = '',
    required this.updatedAt,
  });

  final String id;
  final String contratId;
  final TypeOperation type;

  /// Montant positif en centimes ; le sens est donné par [type].
  final int montant;
  final DateTime date;
  final StatutOperation statut;
  final String libelle;
  final DateTime updatedAt;

  bool get estExecutee => statut == StatutOperation.executee;

  /// Impact signé sur le capital (0 si non exécutée).
  int get impact => !estExecutee ? 0 : (type.credit ? montant : -montant);

  Operation copyWith({StatutOperation? statut, String? libelle}) => Operation(
        id: id,
        contratId: contratId,
        type: type,
        montant: montant,
        date: date,
        statut: statut ?? this.statut,
        libelle: libelle ?? this.libelle,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'contratId': contratId,
        'type': type.name,
        'montant': montant,
        'date': Dates.toIsoDate(date),
        'statut': statut.name,
        'libelle': libelle,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
        id: j['id'] as String,
        contratId: j['contratId'] as String,
        type: TypeOperation.fromName(j['type'] as String?),
        montant: (j['montant'] as num).toInt(),
        date: Dates.fromIsoDate(j['date'] as String),
        statut: StatutOperation.fromName(j['statut'] as String?),
        libelle: (j['libelle'] ?? '') as String,
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
