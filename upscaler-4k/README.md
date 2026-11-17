# Upscaler 4K

Une application web qui agrandit une image en 4K **directement dans le navigateur** : sans serveur, sans API, sans IA. L'image ne quitte jamais l'appareil.

## Utilisation

1. Ouvrez `index.html` dans un navigateur (Chrome, Firefox, Edge ou Safari) : un double-clic suffit.
2. Glissez une image dans la zone, ou cliquez pour la choisir.
3. Choisissez les options, puis cliquez sur **Convertir en 4K**.
4. Comparez avant et après avec le curseur, puis cliquez sur **Télécharger**.

## Options

| Option | Choix |
|---|---|
| Taille de sortie | 4K UHD (tenir dans 3840×2160), côté long = 3840, 4K DCI (4096×2160), ×2, ×4 |
| Méthode | Lanczos-3 (recommandé), Lanczos-2, bicubique, bilinéaire, plus proche voisin (pixel art) |
| Netteté | Masque flou (unsharp mask) de 0 à 2 |
| Réduction du bruit | 0 à 3, préserve les contours |
| Format | PNG (sans perte), JPG ou WebP (qualité 95 %) |

## Fonctionnement

- Redimensionnement séparable (horizontal puis vertical) avec le noyau choisi, codé en JavaScript.
- Calcul de l'alpha prémultiplié, pour éviter les halos sombres autour des zones transparentes.
- Débruitage léger qui préserve les contours, puis netteté avec un seuil pour ne pas amplifier le bruit.
- Tout tourne dans un Web Worker, donc la page reste fluide.

## Limite

Sans IA, l'algorithme **n'invente pas de détails** : il calcule les pixels manquants à partir des pixels voisins. Le résultat est bien en 4K et reste propre, mais il ne contient pas plus d'information que l'image d'origine.

## Publier en ligne (facultatif)

Le dossier ne contient qu'un seul fichier statique. Vous pouvez le mettre sur GitHub Pages, Netlify ou n'importe quel hébergement de fichiers.
