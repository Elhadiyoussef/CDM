# Évolution V2 — Produits, taux annuels, saisie de masse et récapitulatif annuel

**Statut :** proposition de conception, rien n'est encore développé
**Date :** 7 novembre 2026
**Version actuelle de l'application :** format de données `schemaVersion: 1`

---

## 1. Ce qui existe déjà dans l'application

| # | Besoin demandé | Existe aujourd'hui ? | Ce qu'il y a dans le code |
|---|---|---|---|
| 1 | Table des **taux de commission par année** | ❌ Non | Aucune notion de commission. Les frais sont saisis à la main, opération par opération (type `frais`). |
| 2 | Table des **taux de rendement de l'assureur par année** | ❌ Non | Les revalorisations sont saisies à la main (type `revalorisation`, montant libre). Le simulateur a un taux unique réglable, sans historique par année. |
| 3 | **Saisie de masse** des cotisations par année | ❌ Non | Une seule opération à la fois (`lib/screens/operation_form.dart`). Les cotisations répétitives ne sont pas générées. |
| 4 | **Table de référence des produits** | ⚠️ Partiel | Une liste figée de 3 noms dans le code (`ReglesProduit.produits`, `lib/models/regles.dart`). Elle n'est ni modifiable dans l'application, ni enregistrée dans le JSON. Les règles (200 DH minimum, 4 rachats, 50 %) sont les mêmes pour tous les produits. |
| 5 | **Récapitulatif** : épargne brute, épargne nette, commissions par année, rendement net par année, totaux | ⚠️ Partiel | L'accueil affiche le capital, le total versé et un écart de valorisation global. Il n'y a pas de vue par année, de distinction brut / net, ni de total des commissions. |

**Conclusion :** les 5 points sont à développer. Les points 4 et 5 peuvent s'appuyer sur ce qui existe déjà : la liste des produits, les calculs de `AppState` et les cartes du tableau de bord.

---

## 2. Définitions de calcul proposées

Ces définitions sont à **valider avant de développer** (voir les questions de la section 9).

| Terme | Définition proposée |
|---|---|
| **Épargne brute** de l'année | Cotisations + versements libres **exécutés** dans l'année |
| **Commission** de l'année | Épargne brute de l'année × taux de commission de l'année (frais sur versements) |
| **Épargne nette** de l'année | Épargne brute − commission |
| **Rendement brut** de l'année | Capital au 1er janvier × taux, plus chaque versement net × taux × (jours restants jusqu'au 31/12 ÷ 365) |
| **Rendement net** de l'année | Rendement brut (les éventuels frais de gestion sont déduits, voir question 9-B) |
| **Capital fin d'année** | Capital au 1er janvier + épargne nette + rendement net − rachats − frais |
| **Totaux** | Somme de chaque colonne sur toutes les années |

Le rendement est calculé au **prorata temporis** : un versement fait en novembre ne rapporte qu'environ 2 mois d'intérêts sur l'année. C'est la méthode habituelle des contrats d'épargne retraite.

**Exemple :** un taux de commission de 3 % et un rendement de 3,2 % en 2025, pour 18 000 DH de cotisations versées chaque 5 du mois et 100 000 DH de capital au 1er janvier :

| | Montant |
|---|---|
| Épargne brute | 18 000,00 DH |
| Commission (3 %) | −540,00 DH |
| Épargne nette | 17 460,00 DH |
| Rendement sur le capital de départ (100 000 × 3,2 %) | 3 200,00 DH |
| Rendement sur les versements nets (prorata) | ≈ 296,20 DH |
| **Capital au 31/12/2025** | **≈ 120 956,20 DH** |

---

## 3. Évolution du modèle de données (fichier JSON)

Le format passe de `schemaVersion: 1` à **`schemaVersion: 2`**. Un fichier v1 sera **migré automatiquement** au chargement et à l'import : aucune donnée perdue, et les anciennes sauvegardes restent importables.

### 3.1 Nouvelle table `produits` (point 4)

```json
"produits": [
  {
    "id": "prod-ar-indiv",
    "code": "AR-IND",
    "nom": "Assur'Retraite individuelle",
    "assureur": "Sanlam Maroc",
    "type": "euro",
    "cotisationMinimale": 20000,
    "rachatsPartielsMax": 4,
    "plafondRachatPourcent": 50,
    "actif": true,
    "updatedAt": "2026-11-07T19:00:00Z"
  }
]
```

- `type` : `euro` (fonds garanti) ou `multisupport` (unités de compte).
- Les règles qui sont aujourd'hui les mêmes pour tous (`ReglesProduit`) deviennent **propres à chaque produit**.
- Un contrat référence un produit par **`produitId`**, au lieu du nom en texte libre actuel.

### 3.2 Nouvelle table `tauxAnnuels` (points 1 et 2)

Une seule table, avec une ligne par **produit et par année** :

```json
"tauxAnnuels": [
  {
    "id": "…uuid…",
    "produitId": "prod-ar-indiv",
    "annee": 2025,
    "tauxCommission": 300,
    "tauxRendement": 320,
    "commentaire": "Taux communiqué par l'assureur le 15/01/2026",
    "updatedAt": "2026-11-07T19:00:00Z"
  }
]
```

- **Les taux sont stockés en points de base** (1/100 de %), donc des entiers : `300` = 3,00 %, `320` = 3,20 %. C'est la même logique que les montants en centimes : jamais de nombre à virgule.
- Les taux sont **par produit** : deux produits peuvent avoir des taux différents la même année.
- **Option (si validée) :** un taux propre à un contrat, qui remplace celui du produit (`contratId` facultatif).
- Si un taux manque pour une année, le récapitulatif l'indique (« taux 2026 non renseigné ») au lieu d'inventer une valeur.

### 3.3 Changements sur les tables existantes

| Table | Changement |
|---|---|
| `contrats` | `produit` (texte) devient `produitId`. Le nom reste lisible dans le JSON pour compatibilité. |
| `operations` | Nouveau champ facultatif `origine` : `manuelle`, `saisieMasse` ou `calculAnnuel`, pour savoir d'où vient chaque ligne. Nouveau type **`commission`** (débit). |

### 3.4 Migration v1 → v2

1. Créer les 3 produits actuels dans la table `produits`, avec les règles actuelles.
2. Relier chaque contrat à son produit par le nom (ou à « Autre produit retraite » si aucun nom ne correspond).
3. Laisser `tauxAnnuels` vide : l'utilisateur la remplit, ou importe un fichier qui la contient.
4. Les opérations existantes ne changent pas.

---

## 4. Nouveaux écrans

### 4.1 « Référentiels » (nouvel onglet dans Paramètres)

```
Paramètres
 └── Référentiels
      ├── Produits             liste, ajouter, modifier, désactiver
      └── Taux annuels         grille par produit
```

**Écran « Taux annuels » (points 1 et 2)**, une grille modifiable :

| Année | Commission | Rendement assureur | Commentaire |
|---|---|---|---|
| 2026 | 3,00 % | — *(à saisir)* | |
| 2025 | 3,00 % | 3,20 % | Courrier du 15/01/2026 |
| 2024 | 3,00 % | 3,40 % | |
| … | | | |

- Choix du produit en haut de l'écran.
- Bouton « **Ajouter l'année suivante** », qui recopie les taux de l'année précédente.
- Contrôles :
  - commission entre 0 et 10 % ;
  - rendement entre −30 % et +30 % (négatif possible en multisupport) ;
  - une seule ligne par produit et par année.
- Sur mobile, une liste de cartes ; sur desktop, un vrai tableau.

### 4.2 « Saisie de masse » des cotisations (point 3)

Accès depuis la fiche contrat → bouton **« Saisie de masse »**.

1. **Choix** de l'année (ou d'une plage, par ex. 2020 → 2025).
2. **Paramètres préremplis** depuis le contrat, modifiables :
   - montant de la cotisation, date de prélèvement (jour du mois), périodicité ;
   - statut par défaut : « exécutée ».
3. **Aperçu en grille** des échéances générées (12 lignes par an en mensuel) :

   | ☑ | Date | Montant | Statut |
   |---|---|---|---|
   | ☑ | 05/01/2025 | 1 500,00 | Exécutée |
   | ☑ | 05/02/2025 | 1 500,00 | Exécutée |
   | ☐ | 05/04/2025 | 1 500,00 | Rejetée |

   On peut décocher une ligne, changer un montant ou marquer un rejet avant de valider.
4. **Contrôle des doublons** : si une cotisation existe déjà à la même date pour ce contrat, la ligne est signalée et décochée par défaut.
5. **Validation** : toutes les lignes sont enregistrées en une seule fois, avec `origine: "saisieMasse"`.
6. **Option « Calculer la fin d'année »** : génère en plus l'opération de commission et la revalorisation de l'année à partir de la table des taux.
7. **Annulation** : un bouton « Annuler cette saisie de masse » supprime d'un coup toutes les lignes créées par ce lot.

### 4.3 « Récapitulatif annuel » (point 5)

Nouvel onglet dans la navigation (Accueil, Contrats, Opérations, **Récap**, Simulateur, Paramètres), avec un filtre : tous les contrats ou un seul.

**Cartes de synthèse en haut :**

| Épargne brute totale | Commissions totales | Épargne nette totale | Rendement net total | Capital actuel |
|---|---|---|---|---|

**Tableau par année :**

| Année | Épargne brute | Commission | Épargne nette | Taux rend. | Rendement net | Rachats / frais | Capital au 31/12 |
|---|---|---|---|---|---|---|---|
| 2023 | 18 000 | −540 | 17 460 | 3,30 % | 3 012 | 0 | 112 300 |
| 2024 | 18 000 | −540 | 17 460 | 3,40 % | 4 110 | 0 | 133 870 |
| 2025 | 18 000 | −540 | 17 460 | 3,20 % | 4 571 | 0 | 155 901 |
| **Total** | **54 000** | **−1 620** | **52 380** | | **11 693** | **0** | |

- Un graphique en barres empilées par année : épargne nette, commission et rendement.
- Les années sans taux renseigné sont signalées par une icône d'avertissement.
- Bouton **« Exporter le récapitulatif (CSV) »**, à ouvrir dans Excel.
- **Deux modes de calcul**, en toggle :
  - **« Selon les opérations saisies »** : le récapitulatif additionne les commissions et revalorisations réellement enregistrées ;
  - **« Selon la table des taux »** : il recalcule à partir des taux annuels, pour comparer avec les relevés de l'assureur.

  L'écart entre les deux modes permet de **détecter une erreur** de l'assureur ou de saisie.

L'accueil gagne aussi deux cartes : **Épargne nette** et **Commissions retenues**.

---

## 5. Changements dans le code

| Fichier | Changement |
|---|---|
| `lib/models/produit.dart` | **Nouveau** : classe `Produit` (JSON, règles propres) |
| `lib/models/taux_annuel.dart` | **Nouveau** : classe `TauxAnnuel` (points de base) |
| `lib/models/app_data.dart` | Tables `produits` et `tauxAnnuels`, `schemaVersion = 2`, **migration v1 → v2** |
| `lib/models/contrat.dart` | `produitId` ; lecture de l'ancien champ `produit` |
| `lib/models/operation.dart` | Type `commission`, champs `origine` et `lotId` |
| `lib/models/regles.dart` | Supprimé, remplacé par les règles portées par `Produit` |
| `lib/services/calcul_annuel.dart` | **Nouveau** : calcul brut, commission, net et rendement prorata, année par année (logique pure, testable) |
| `lib/state/app_state.dart` | CRUD produits et taux, `saisieMasse()`, `annulerLot()`, `recapAnnuel()`, fusion des nouvelles tables à l'import |
| `lib/screens/referentiels_screen.dart` | **Nouveau** : produits et taux annuels |
| `lib/screens/saisie_masse_screen.dart` | **Nouveau** : assistant en 3 étapes |
| `lib/screens/recap_screen.dart` | **Nouveau** : tableau, graphique, export CSV |
| `lib/screens/home_shell.dart` | Ajout de l'onglet « Récap » |
| `lib/screens/contrat_form.dart` | Choix du produit dans le référentiel (et non plus dans la liste figée) |
| `tool/generer_donnees_test.py` | Génère aussi les produits et les taux 2010 → 2026 |
| `test/` | Nouveaux tests (section 7) |

**Fusion à l'import :** les produits et les taux sont fusionnés comme les contrats (par identifiant, la version la plus récente l'emporte). Pour les taux, deux lignes du même produit et de la même année venant de deux appareils sont considérées comme identiques, et la plus récente gagne.

---

## 6. Plan de développement

| Étape | Contenu | Résultat visible |
|---|---|---|
| **1** | Modèles `Produit` et `TauxAnnuel`, schéma v2, migration, tests | Les anciens fichiers s'ouvrent toujours |
| **2** | Écran « Référentiels » (produits et taux) | Point 4, puis points 1 et 2 |
| **3** | Service de calcul annuel et tests | Les calculs sont fiables |
| **4** | Écran « Récapitulatif annuel » et export CSV | Point 5 |
| **5** | Assistant de saisie de masse et annulation par lot | Point 3 |
| **6** | Données de test v2, APK, mise à jour du README | Prêt à tester sur téléphone |

Chaque étape est livrée par un commit séparé, et l'APK est recompilé automatiquement par GitHub Actions.

---

## 7. Tests prévus

- **Migration :** un fichier v1 (dont `docs/donnees-test/ma_retraite_test.json`) est chargé en v2 sans perte.
- **Calcul :** l'exemple de la section 2 donne exactement les montants attendus, au centime près.
- **Prorata :** un versement au 31/12 ne rapporte rien ; un versement au 1/01 rapporte une année pleine.
- **Taux manquant :** l'année est signalée et aucun rendement n'est inventé.
- **Saisie de masse :**
  - 12 cotisations générées pour une année en mensuel, 4 en trimestriel ;
  - les doublons sont détectés ;
  - l'annulation du lot supprime exactement ses lignes.
- **Rendement négatif** (multisupport) : correctement soustrait.
- **Import / fusion** : les produits et les taux venant d'un autre appareil sont fusionnés sans doublon.
- **Récapitulatif :** la somme des colonnes annuelles est égale aux totaux, et le capital du récapitulatif est égal au capital de l'accueil (mode « opérations »).

---

## 8. Ce qui ne change pas

- L'application reste **100 % locale**, avec un seul fichier JSON et l'export / import actuel.
- Les montants restent en centimes entiers ; les taux sont en points de base entiers.
- Les règles actuelles restent en place : les opérations en attente ne sont pas comptées, les rachats partiels sont plafonnés, un rachat total clôture le contrat.

---

## 9. Questions à valider avant de développer

| # | Question | Proposition par défaut |
|---|---|---|
| A | La commission s'applique-t-elle **sur chaque versement** (frais d'entrée) ou **sur l'encours** chaque année (frais de gestion) ? | Sur chaque versement ; un 2e taux « frais de gestion sur encours » peut être ajouté plus tard |
| B | Le taux de rendement communiqué par l'assureur est-il **déjà net** des frais de gestion ? | Oui, il est considéré comme net |
| C | Les taux sont-ils **par produit** ou peuvent-ils **différer par contrat** ? | Par produit, avec un remplacement possible par contrat |
| D | La revalorisation est-elle versée **au 31 décembre** ou à une autre date ? | Au 31/12 |
| E | Le rendement de l'année en cours (non encore publié) doit-il être **estimé** avec le taux de l'année précédente ? | Oui, affiché en italique avec la mention « estimé » |
| F | La saisie de masse doit-elle pouvoir importer un **fichier Excel / CSV** de cotisations ? | Pas dans cette version ; peut être ajouté à l'étape 5 si besoin |
