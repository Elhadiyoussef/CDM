# Upscaler 4K

Une application web qui améliore et agrandit une image en 4K **directement sur l'appareil** (ordinateur ou téléphone) : sans serveur et sans API. L'image ne quitte jamais l'appareil.

Il y a deux moteurs :

- **IA locale** (par défaut) : le modèle open source [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) (`realesr-general-x4v3`, licence BSD-3) tourne dans le navigateur grâce à [onnxruntime-web](https://github.com/microsoft/onnxruntime) (licence MIT). Il supprime le bruit et rend les contours nets. Comptez environ 1 minute sur ordinateur et quelques minutes sur téléphone pour une image en 4K.
- **Classique** : interpolation Lanczos, bicubique, etc., sans aucune IA. Le résultat est instantané.

Dans les deux modes, une **correction automatique** de la lumière et des couleurs (balance des blancs, niveaux, saturation) est proposée.

> ⚠️ Avec l'IA, la page doit être servie par un serveur web : GitHub Pages, Netlify, ou `python3 -m http.server` dans ce dossier. Un double-clic sur le fichier ne suffit pas, car le navigateur refuse alors de charger les fichiers du modèle. Le mode classique, lui, fonctionne aussi avec un simple double-clic.

## Utilisation

1. Ouvrez la page dans un navigateur (Chrome, Firefox, Edge ou Safari), servie par un serveur web (voir ci-dessus).
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

## Fichiers

- `index.html` : l'application.
- `ort/` : le moteur onnxruntime-web (WebAssembly).
- `models/realesrgan-{leger,moyen,fort}.onnx.wasm` : Real-ESRGAN converti en ONNX. L'extension `.onnx.wasm` sert seulement à contourner les hébergeurs qui refusent `.onnx` : ce n'est pas du WebAssembly, avec trois niveaux de débruitage obtenus par interpolation des poids `realesr-general-x4v3` et `realesr-general-wdn-x4v3`.

## Limite

En mode classique, l'algorithme **n'invente pas de détails** : il calcule les pixels manquants à partir des pixels voisins. Le résultat est bien en 4K et reste propre, mais il ne contient pas plus d'information que l'image d'origine.

L'IA locale nettoie beaucoup mieux une photo floue ou bruitée, mais elle ne régénère pas complètement une image comme le font les grosses IA génératives (de type Stable Diffusion), qui demandent une carte graphique puissante.

## Publier en ligne (facultatif)

Le dossier ne contient que des fichiers statiques (environ 30 Mo avec le modèle). Vous pouvez le mettre sur GitHub Pages, Netlify ou n'importe quel hébergement de fichiers.
