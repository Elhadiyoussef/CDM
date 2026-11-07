# Ma Retraite — application locale (Flutter)

Application de suivi d'épargne retraite **100 % locale**, pour **mobile et desktop** (Android, iOS, Windows, macOS, Linux).
Les données sont enregistrées dans **un fichier JSON** sur l'appareil, et peuvent être **exportées / importées** pour être utilisées sur un autre appareil.

![Accueil desktop](docs/captures/desktop-accueil.png)

| Mobile | Simulateur | Saisie d'opération |
|---|---|---|
| ![](docs/captures/mobile-accueil.png) | ![](docs/captures/desktop-simulateur.png) | ![](docs/captures/desktop-operation.png) |

## Fonctionnalités

- **Accueil** : capital constitué, total versé, écart de valorisation, prochaine cotisation, progression vers l'objectif, courbe d'évolution, actions rapides.
- **Contrats** : création / modification, périodicité, échéance, objectif, bénéficiaires (quotes-parts contrôlées à 100 %), fiche détaillée.
- **Opérations** : cotisations, versements, revalorisations, frais, rachats partiels et total ; statuts *en attente / exécutée / rejetée / annulée* ; filtres et regroupement par mois.
- **Règles métier** (paramétrables par produit dans *Paramètres → Produits d’assurance*) :
  - une opération en attente n'est **jamais** comptée dans le capital ;
  - rachat partiel limité à 50 % de l'épargne et à 4 rachats ;
  - détection d'une demande de rachat déjà en attente ;
  - un rachat total exécuté **clôture** le contrat, qui n'accepte plus d'opération.
- **Récapitulatif annuel** : épargne brute, commissions retenues, épargne nette, rendement net et capital au 31/12, par année et au total ; graphique ; détail des intérêts par cotisation ; export CSV pour Excel. Deux modes : *selon la table des taux* (recalcul) ou *selon les opérations saisies* (pour repérer un écart avec l'assureur).
- **Référentiels** (Paramètres) :
  - **produits d'assurance** avec leurs règles (cotisation minimale, nombre et plafond des rachats) ;
  - **taux annuels** de commission et de rendement, par produit ou propres à un contrat, saisis comme un tableur, collés depuis Excel ou importés en CSV.
- **Saisie de masse** des cotisations : génération d'une ou plusieurs années, grille modifiable, copier-coller Excel, import CSV, détection des doublons et annulation du lot en un clic.
- **Calcul des rendements** comme un compte sur carnet (par quinzaine) ou au prorata des jours ; estimation paramétrable de l'année en cours ; génération des opérations « Commission » et « Rendement » de fin d'année.
- **Simulateur** : scénarios prudent / central / favorable, graphique, retrait mensuel indicatif.
- **Paramètres** : export, partage (mobile), import, thème clair / sombre, données de démonstration.

## Données et transfert entre appareils

| Plateforme | Emplacement du fichier `ma_retraite.json` |
|---|---|
| Android / iOS | dossier privé de l'application |
| Windows | `%APPDATA%\ma.cdm\ma_retraite\` |
| macOS | `~/Library/Application Support/ma.cdm.maRetraite/` |
| Linux | `~/.local/share/ma.cdm.ma_retraite/` |

- **Écriture sûre** : écriture dans un fichier temporaire, puis remplacement ; la version précédente est gardée en `.bak` et restaurée automatiquement si le fichier est endommagé.
- **Export** : *Paramètres → Exporter (.json)* (ou *Partager* sur mobile : e-mail, WhatsApp, Drive, Bluetooth…).
- **Import** : *Paramètres → Importer*, avec aperçu du contenu puis choix :
  - **Fusionner** : ajoute les nouveaux éléments ; pour un même identifiant, la version modifiée le plus récemment l'emporte ;
  - **Remplacer** : remplace toutes les données de l'appareil.
- **Montants** stockés en **centimes entiers** et **taux** en **points de base** (`320` = 3,20 %) : jamais de nombres à virgule ; **identifiants UUID** pour fusionner sans conflit.
- Les fichiers de l'ancien format (`schemaVersion: 1`) sont **convertis automatiquement** à l'ouverture et à l'import.
- Un fichier de test complet est fourni : `docs/donnees-test/ma_retraite_test.json` (8 contrats, 752 opérations, 4 produits, 49 taux), régénérable avec `python3 tool/generer_donnees_test.py`.

Exemple de fichier :

```json
{
  "app": "ma_retraite_cdm",
  "schemaVersion": 2,
  "updatedAt": "2026-11-07T10:00:00.000Z",
  "profil": { "nom": "Karim", "theme": "system" },
  "parametres": { "methodeInteret": "quinzaines", "estimerAnneeEnCours": true, "tauxEstimation": null, "dateRevalorisation": "12-31" },
  "produits": [
    { "id": "prod-ar-ind", "code": "AR-IND", "nom": "Assur'Retraite individuelle", "assureur": "Sanlam Maroc", "type": "euro",
      "cotisationMinimale": 20000, "rachatsPartielsMax": 4, "plafondRachatPourcent": 50, "actif": true, "updatedAt": "…" }
  ],
  "tauxAnnuels": [
    { "id": "…", "produitId": "prod-ar-ind", "annee": 2025, "tauxCommission": 250, "tauxRendement": 320, "commentaire": "", "updatedAt": "…" },
    { "id": "…", "contratId": "6f1c…", "annee": 2025, "tauxCommission": 150, "tauxRendement": null, "commentaire": "Taux négocié", "updatedAt": "…" }
  ],
  "contrats": [
    {
      "id": "6f1c…", "reference": "AR-2019-004587", "produitId": "prod-ar-ind",
      "dateEffet": "2019-11-05", "dateEcheance": "2044-06-30",
      "cotisation": 150000, "periodicite": "mensuelle", "objectif": 50000000,
      "statut": "actif", "beneficiaires": [], "updatedAt": "…"
    }
  ],
  "operations": [
    {
      "id": "a9e2…", "contratId": "6f1c…", "type": "cotisation", "montant": 150000,
      "date": "2026-11-05", "statut": "executee", "libelle": "Prélèvement mensuel", "updatedAt": "…"
    }
  ]
}
```

## Lancer le projet

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) (stable, Dart ≥ 3.10).

```bash
flutter pub get
flutter run -d windows      # ou macos, linux, android, ios, chrome
flutter test                # tests des règles métier et de l'export / import
```

Construire :

```bash
flutter build apk           # Android
flutter build windows       # Windows (à lancer sous Windows)
flutter build macos         # macOS (à lancer sous macOS)
flutter build ios           # iOS (macOS + Xcode)
flutter build linux         # Linux
```

## Structure

```
lib/
  main.dart                 point d'entrée, thème, localisation FR
  models/                   Contrat, Operation, Produit, TauxAnnuel, ParametresCalcul, AppData (format JSON)
  services/calcul_annuel.dart  commissions, intérêts (quinzaines / jours), récapitulatif annuel
  data/                     stockage JSON (fichier / navigateur), export-import
  utils/tableur.dart        lecture copier-coller Excel / CSV
  state/app_state.dart      logique métier, calculs, fusion à l'import
  theme/app_theme.dart      identité visuelle (Material 3, clair / sombre)
  widgets/                  composants réutilisables (cartes, graphiques, formulaires)
  screens/                  Accueil, Contrats, Opérations, Récap, Simulateur, Paramètres,
                            Produits, Taux annuels, Saisie de masse
test/                       tests unitaires
```

> Application de démonstration non officielle. Les règles produit et les simulations sont indicatives et ne constituent pas un engagement d'un assureur ou d'une banque.
