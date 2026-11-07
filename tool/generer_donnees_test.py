#!/usr/bin/env python3
"""Génère un fichier JSON de test riche pour Ma Retraite (format schemaVersion 1).

Usage : python3 tool/generer_donnees_test.py [fichier_sortie]
Les données sont fictives et respectent les règles de l'application :
montants en centimes, opérations en attente non comptées, rachats partiels
<= 50 % et <= 4 par contrat, une seule demande de rachat en attente,
rachat total = capital puis contrat clôturé.
"""
import json, random, sys, uuid
from datetime import date, datetime, timezone

random.seed(20261107)
TODAY = date(2026, 11, 7)
NOW = "2026-11-07T19:00:00.000Z"

def uid(): return str(uuid.UUID(int=random.getrandbits(128), version=4))
def add_months(d, n):
    m = d.month - 1 + n; y = d.year + m // 12; m = m % 12 + 1
    import calendar
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))
def dh(x): return int(round(x * 100))

PRODUITS = ["Assur'Retraite individuelle", "Assur'Retraite Multisupport", "Autre produit retraite"]
PERIODES = {"mensuelle": 1, "trimestrielle": 3, "semestrielle": 6, "annuelle": 12}

# reference, produit, debut, echeance, cotisation DH, periodicite, objectif DH, scenario, beneficiaires
CONTRATS = [
    ("AR-2010-000877", 2, date(2010, 2, 10), date(2027, 6, 30), 2000, "mensuelle", 900000, "proche_retraite",
     [("Fatima Zahra Bennani", "Conjointe", 50), ("Omar Bennani", "Enfant", 25), ("Lina Bennani", "Enfant", 25)]),
    ("AR-2012-001245", 0, date(2012, 3, 1), date(2038, 3, 1), 1000, "mensuelle", 600000, "rachats_partiels",
     [("Nadia Alaoui", "Conjointe", 100)]),
    ("AR-2014-003310", 0, date(2014, 9, 15), date(2040, 9, 15), 6000, "semestrielle", 300000, "rachat_total",
     [("Hicham Tazi", "Frère", 100)]),
    ("AR-2016-007831", 1, date(2016, 1, 20), date(2042, 12, 31), 4500, "trimestrielle", 800000, "multisupport",
     [("Salma El Amrani", "Conjointe", 60), ("Yanis El Amrani", "Enfant", 40)]),
    ("AR-2019-004587", 0, date(2019, 11, 5), date(2044, 6, 30), 1500, "mensuelle", 500000, "standard",
     [("Salma El Amrani", "Conjointe", 60), ("Yanis El Amrani", "Enfant", 40)]),
    ("AR-2021-010422", 1, date(2021, 4, 1), date(2046, 4, 1), 24000, "annuelle", 700000, "suspendu",
     [("Rachid Idrissi", "Père", 30), ("Amina Idrissi", "Mère", 30), ("Sara Idrissi", "Sœur", 40)]),
    ("AR-2023-015560", 0, date(2023, 2, 28), date(2055, 2, 28), 300, "mensuelle", 150000, "rejets", []),
    ("AR-2025-019901", 0, date(2025, 9, 1), date(2058, 9, 1), 200, "mensuelle", 100000, "debutant",
     [("Youssef Chraibi", "Conjoint", 100)]),
]

TAUX = {2010: 3.6, 2011: 3.5, 2012: 3.4, 2013: 3.3, 2014: 3.2, 2015: 3.0, 2016: 2.9, 2017: 2.8, 2018: 2.7,
        2019: 2.6, 2020: 2.4, 2021: 2.5, 2022: 2.9, 2023: 3.3, 2024: 3.4, 2025: 3.2}
UC = {2016: 6.1, 2017: 8.4, 2018: -4.2, 2019: 9.7, 2020: 1.8, 2021: 7.9, 2022: -6.5, 2023: 5.4, 2024: 6.8, 2025: 4.1}

contrats, operations = [], []

for ref, p, debut, ech, cot, per, obj, sc, benefs in CONTRATS:
    cid = uid(); cap = 0; statut = "actif"; rachats = 0
    ops = []
    def op(t, montant, d, st="executee", lib=""):
        global_cap = None
        ops.append({"id": uid(), "contratId": cid, "type": t, "montant": montant, "date": d.isoformat(),
                    "statut": st, "libelle": lib, "updatedAt": NOW})
    pas = PERIODES[per]
    echeances = []
    i = 0
    while True:
        d = add_months(debut, i * pas)
        if d > TODAY: break
        echeances.append(d); i += 1
    cot_c = dh(cot)
    years = sorted({d.year for d in echeances})
    stop = None
    if sc == "suspendu": stop = date(2025, 3, 1)
    if sc == "rachat_total": stop = date(2024, 6, 1)
    for y in years:
        for d in [e for e in echeances if e.year == y]:
            if stop and d >= stop: break
            # hausse de cotisation pour certains contrats
            montant = cot_c
            if sc == "proche_retraite" and d.year >= 2018: montant = dh(3000)
            if sc == "rachats_partiels" and d.year >= 2020: montant = dh(1250)
            r = random.random()
            taux_rejet = 0.12 if sc == "rejets" else 0.025
            if d == TODAY.replace(day=1) or (TODAY - d).days < 3 and sc == "debutant":
                op("cotisation", montant, d, "enAttente", "Prélèvement en cours de traitement"); continue
            if r < taux_rejet:
                motif = random.choice(["provision insuffisante", "compte clôturé", "opposition du client", "RIB invalide"])
                op("cotisation", montant, d, "rejetee", f"Prélèvement rejeté — {motif}")
                if random.random() < 0.5:
                    d2 = date.fromordinal(d.toordinal() + random.randint(8, 20))
                    if d2 <= TODAY:
                        op("cotisation", montant, d2, "executee", "Régularisation du prélèvement rejeté"); cap += montant
                continue
            op("cotisation", montant, d, "executee", "Prélèvement " + per); cap += montant
        # versements libres
        if sc not in ("debutant", "rejets") and random.random() < 0.55:
            d = date(y, random.randint(1, 6), random.randint(1, 28))  # avant les rachats de juillet
            if d <= TODAY and not (stop and d >= stop):
                m = dh(random.choice([2000, 5000, 7500, 10000, 15000, 20000, 30000, 50000]))
                lib = random.choice(["Versement libre", "Prime annuelle", "Épargne exceptionnelle", "Versement 13e mois"])
                st = random.choices(["executee", "annulee"], [0.93, 0.07])[0]
                op("versement", m, d, st, lib)
                if st == "executee": cap += m
        # rachats partiels
        if sc == "rachats_partiels" and y in (2016, 2019, 2022, 2025) and rachats < 4:
            m = cap * random.choice([15, 20, 30, 45]) // 100
            op("rachatPartiel", m, date(y, 7, 12), "executee",
               random.choice(["Rachat partiel — travaux", "Rachat partiel — études", "Rachat partiel — achat véhicule", "Rachat partiel — santé"]))
            cap -= m; rachats += 1
        if sc == "multisupport" and y == 2021:
            m = cap * 25 // 100; op("rachatPartiel", m, date(2021, 10, 4), "executee", "Rachat partiel — apport immobilier")
            cap -= m; rachats += 1
        if sc == "proche_retraite" and y == 2020:
            m = cap * 10 // 100; op("rachatPartiel", m, date(2020, 5, 18), "rejetee", "Rachat partiel — dossier incomplet")
        if sc == "rachat_total" and y == 2024:
            op("rachatTotal", cap, date(2024, 7, 22), "executee", "Rachat total — clôture du contrat"); cap = 0; statut = "cloture"
            break
        # revalorisation / frais de fin d'année
        fin = date(y, 12, 31)
        if fin < TODAY and cap > 0 and statut == "actif":
            if sc == "multisupport":
                t = UC.get(y, 3.0)
                v = abs(cap * int(t * 10) // 1000)
                if t >= 0: op("revalorisation", v, fin, "executee", f"Valorisation unités de compte {y} (+{t:.1f} %)".replace(".", ",")); cap += v
                else: op("frais", v, fin, "executee", f"Moins-value unités de compte {y} ({t:.1f} %)".replace(".", ",")); cap -= v
                fr = cap * 6 // 1000; op("frais", fr, fin, "executee", f"Frais de gestion {y} (0,6 %)"); cap -= fr
            else:
                t = TAUX.get(y, 3.0)
                v = cap * int(t * 10) // 1000
                op("revalorisation", v, fin, "executee", f"Participation aux bénéfices {y} ({t:.1f} %)".replace(".", ",")); cap += v
                if sc in ("proche_retraite", "rachats_partiels"):
                    fr = cap * 3 // 1000; op("frais", fr, fin, "executee", f"Frais de gestion {y} (0,3 %)"); cap -= fr
    # demandes en cours (dans les limites des règles)
    if sc == "proche_retraite":
        op("rachatPartiel", cap * 20 // 100, date(2026, 10, 28), "enAttente", "Demande de rachat partiel — préparation retraite")
        op("versement", dh(25000), date(2026, 11, 3), "enAttente", "Versement complémentaire")
    if sc == "standard":
        op("versement", dh(5000), date(2026, 11, 7), "enAttente", "Versement complémentaire")
    if sc == "multisupport":
        op("rachatPartiel", cap * 10 // 100, date(2026, 9, 15), "annulee", "Demande de rachat annulée par le client")
    if sc == "suspendu":
        statut = "suspendu"
    contrats.append({
        "id": cid, "reference": ref, "produit": PRODUITS[p], "dateEffet": debut.isoformat(),
        "dateEcheance": ech.isoformat(), "cotisation": cot_c if sc not in ("proche_retraite", "rachats_partiels") else (dh(3000) if sc == "proche_retraite" else dh(1250)),
        "periodicite": per, "objectif": dh(obj), "statut": statut,
        "beneficiaires": [{"id": uid(), "nom": n, "lien": l, "quotePart": q} for n, l, q in benefs],
        "updatedAt": NOW,
    })
    ops.sort(key=lambda o: o["date"])
    operations.extend(ops)

data = {"app": "ma_retraite_cdm", "schemaVersion": 1, "updatedAt": NOW,
        "profil": {"nom": "Karim", "theme": "light"}, "contrats": contrats, "operations": operations}
out = sys.argv[1] if len(sys.argv) > 1 else "ma_retraite_test.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print(out, len(contrats), "contrats", len(operations), "opérations")
