# BRIEF MINDUEL — Illustrations & assets graphiques

Document à transmettre à une IA spécialisée en génération d'illustrations (mobile app, style flat/vectoriel, cohérence de marque).

---

## 1. Contexte projet

**App : Minduel** — une app iOS de culture générale façon Duolingo.  
Concept : un parcours de leçons quotidiennes par thèmes (Histoire, Sciences, Géographie, etc.) + un mode Duel multijoueur contre d'autres joueurs.

Langue : **français**.  
Ambiance : **cocooning, ludique, colorée, légèrement compétitive, positive.** Pas dark, pas sérieux, pas académique. C'est un jeu d'apprentissage, pas une app scolaire.

---

## 2. Identité visuelle actuelle

### 2.1 Palette (obligatoire, hex exacts à respecter)

| Token | Hex | Usage |
|---|---|---|
| Primary / Accent orange | `#FF6B00` | Boutons principaux, flamme série, accents |
| Success vert | `#3DD62C` | Bonnes réponses, validation, victoire |
| Danger rouge | `#FF3B5C` | Erreurs, échec, cooldown |
| Gold / Jaune | `#FFC700` | Récompenses, XP, couronnes, déblocage |
| Rubis (monnaie) | `#D81E3A` | Monnaie premium "Rubis" |
| Background crème | `#FDF8EF` | Fond principal des écrans clairs |
| Carte blanche | `#FFFFFF` | Cartes, sheets, panneaux |
| Ligne séparateurs | `#EAE0D0` | Bordures légères |
| Encre | `#3B2E28` | Texte principal |
| Encre atténuée | `#9B8A7C` | Sous-titres |
| Fond verrouillé | `#E3D9C8` | Éléments non disponibles |

Palette des matières (obligatoire, une couleur par matière) :

| Matière | Hex | Code actuel SF Symbols |
|---|---|---|
| Histoire | `#E8590C` | `building.columns.fill` |
| Sciences | `#7048E8` | `atom` |
| Géographie | `#1C7ED6` | `globe.europe.africa.fill` |
| Littérature | `#0CA678` | `book.fill` |
| Arts & Musique | `#E64980` | `paintpalette.fill` |
| Nature & Animaux | `#2F9E44` | `leaf.fill` |
| Tech & Espace | `#F59F00` | `lightbulb.fill` |
| Football | `#37B24D` | `soccerball.fill` |

Palette additionnelle du parcours (cycle des couleurs des ronds) :
- `#FF6B00` (orange), `#1CB0F6` (bleu ciel), `#3DD62C` (vert flash), `#9B4DFF` (violet), `#FF3D8A` (rose), `#FFC700` (jaune), `#00D1B2` (turquoise).

### 2.2 Ambiance Duel (mode sombre)

| Token | Hex | Usage |
|---|---|---|
| Fond duel | `#141B2E` | Fond principal du mode Duel |
| Carte duel | `#1E2A47` | Cartes sur fond sombre |
| Ligne duel | `#31406B` | Séparateurs |
| Accent duel | `#22D3C5` | Boutons/badges sur fond sombre |

### 2.3 Style graphique

- **Flat design vectoriel**, pas de 3D réaliste, pas de dégradés complexes.
- Formes **rondes, potelées, chunky** : gros boutons, coins très arrondis, cercles, capsules.
- **Ombres douces** uniquement (pas d'ombres dures), ou relief 2D par superposition de deux formes (face claire + base sombre décalée).
- **Contours noirs très épurés**, voire absents : on préfère les bordures colorées ou blanches.
- **Personnages expressifs et mignons**, style cartoon duolinguoïde, corps simples, tête ronde, gros yeux.
- **Fonds transparents** pour les mascottes et icônes isolées. Fonds plein cadre pour les scènes d'onboarding.

### 2.4 Typographie

Police système iOS : `.rounded` (SF Rounded), gras, lourde. Tout est lisible et amical. Les titres sont très gros, les captions petites et rondes.

---

## 3. La mascotte — caractère et style

Minduel a déjà une mascotte. Il faut **strictement respecter le style visuel** pour les nouvelles poses.

### Description actuelle (à observer sur les images existantes) :

La mascotte est une sorte de **petit personnage aux traits ronds, kawaii/chibi** :
- Grande tête ronde, proportionnellement plus grosse que le corps.
- Yeux ronds, très expressifs, sans pupille détaillée (souvent des points noirs ou des formes simples).
- Petites mains rondes / pattes simples.
- Corps compact, très petit, souvent caché ou réduit.
- **Couleurs vives** : on dirait un mélange de teintes pastel/flash (orange, jaune, bleu…). Le personnage ressemble à un petit esprit/cristal ou une goutte de couleur avec un visage.
- Style : illustration plate, vecteur, pas de ligne noire dure, contours colorés doux.
- **Poses actuelles dans l'app** :
  - `MascotWave` : pose de salut/bienvenue.
  - `MascotJump` : pose victorieuse, bras en l'air, dynamique.
  - `MascotRead` : pose étude/lecture.
  - `MascotWink` : pose malicieuse, clin d'œil.

### Poses à générer (même personnage, fond transparent PNG) :

| Nom | Description | Usage |
|---|---|---|
| `mascot_trophy` | Mascotte tenant un trophée ou une coupe, super fier.e, bras levé. | Fin de parcours, palier de série, écran de victoire |
| `mascot_cheer` | Mascotte qui applaudit ou fait un pouce, très encourageant.e. | Écran d'échec léger de leçon, révision |
| `mascot_duel` | Mascotte en position de défi, avec un petit gant/bouclier ou un éclair, légèrement badass mais mignon. | Accueil onglet Duel |
| `mascot_waiting` | Mascotte assis.e ou qui regarde un sablier/montre, patient.e. | Lobby multijoueur, chargement |
| `mascot_shrug` | Mascotte qui hausse les épaules, légèrement désolée mais souriante. | Empty states (pas d'amis, rien à réviser) |
| `mascot_gift` | Mascotte tenant un cadeau ou une pièce/petit sac de rubis. | Écran de déblocage, boutique, récompense |
| `mascot_brain` | Mascotte avec un gros cerveau ou une ampoule au-dessus de la tête. | Révision, questions de culture |
| `mascot_sleep` | Mascotte qui dort ou baille, avec Zzz. | Pas d'activité, cooldown nuit |

**Contraintes techniques** :
- Fond transparent PNG.
- Ratio hauteur ~1:1 ou 4:5.
- Résolution suffisante pour affichage à ~150px de haut sur mobile (générer 512px ou 1024px de haut).
- Style strictement cohérent avec `MascotWave` / `MascotJump` / `MascotWink` / `MascotRead` existants.
- Pas de contour noir dur.
- Couleurs : reprendre les teintes de la mascotte actuelle (pastel flash, orange/jaune dominants).

---

## 4. Écrans et illustrations manquantes

### 4.1 Onboarding (écrans de lancement)

L'onboarding utilise actuellement un fond crème avec des emojis flottants (livres, crayons) en fond. Il faut des **illustrations de scène plein cadre**, 1 par étape clé, dans le style flat vectoriel de l'app.

| Nom | Format | Description | Couleurs |
|---|---|---|---|
| `onboarding_welcome` | Plein cadre, ratio 9:16, fond transparent ou crème | Scène "bienvenue" : mascotte qui salue, livres flottants, bulles de questions, éléments ludiques liés au savoir. | Crème `#FDF8EF`, orange `#FF6B00`, bleu `#1CB0F6`, vert `#3DD62C` |
| `onboarding_topics` | Plein cadre | Mascotte entouré.e de petites icônes thématiques (globe, livre, atome, musique, etc.) | Palette des matières |
| `onboarding_goal` | Plein cadre | Mascotte avec un calendrier, une flamme et une horloge : symbolise l'objectif quotidien et la série. | Orange `#FF6B00`, jaune `#FFC700` |
| `onboarding_diagnostic_result` | Plein cadre | Mascotte devant un tableau de bord avec des barres/jauges : "on évalue ton niveau". | Vert `#3DD62C`, violet `#9B4DFF` |

Contraintes : pas de texte dans les images. Laisser la place au centre/bas pour les textes et boutons. Fond clair, doux, pas de détails trop denses.

### 4.2 Écrans de leçon (fin de session)

| Nom | Format | Description | Usage |
|---|---|---|---|
| `lesson_success` | Plein cadre ou transparent | Célébration : confettis, étoiles, mascotte `mascot_trophy`, couronne, jetons XP. Fond clair. | `LessonCompleteView` |
| `lesson_failure` | Plein cadre ou transparent | Mascotte `mascot_cheer` avec un bandeau "On réessaye !" ou une petite larme stylisée. Ton encourageant, pas triste. | `LessonFailureView` hero |
| `session_streak` | Plein cadre | Grosse flamme stylisée + mascotte + calendrier de la semaine. Fond clair. | `StreakCelebrationView` |
| `unlock_celebration` | Plein cadre | Mascotte `mascot_gift`, rubis, cadeau, déverrouillage d'un cadenas qui s'ouvre. | `UnlockCelebrationView` |

### 4.3 Icônes illustrées par matière (pour les cartes Thèmes)

Actuellement les cartes Thèmes utilisent des icônes SF Symbols. Remplacer par des **illustrations rondes, simples, monochromes blanches sur le fond coloré de la carte**.

| Nom | Description | Couleur de fond associée |
|---|---|---|
| `theme_icon_histoire` | Bâtiments antiques, colonnes, temple, pyramide stylisée | `#E8590C` |
| `theme_icon_sciences` | Atome, fiole, planète, microscope stylisé | `#7048E8` |
| `theme_icon_geographie` | Globe terrestre avec continents, boussole, carte | `#1C7ED6` |
| `theme_icon_litterature` | Livre ouvert, plume, pile de livres | `#0CA678` |
| `theme_icon_arts` | Palette de peinture, pinceaux, notes de musique | `#E64980` |
| `theme_icon_nature` | Feuille, arbre, patte d'animal, papillon | `#2F9E44` |
| `theme_icon_technologie` | Ampoule, fusée, engrenage, planète | `#F59F00` |
| `theme_icon_football` | Ballon de foot, terrain, trophée | `#37B24D` |

Contraintes :
- Fond transparent PNG.
- Style linéaire/flat blanc, lisible en petit (60×60pt affiché).
- Pas de détails microscopiques.
- Chaque icône doit être reconnaissable en 1 seconde.

### 4.4 Mode Duel (fond sombre)

| Nom | Format | Description | Couleurs |
|---|---|---|---|
| `duel_hero` | Plein cadre | Deux mascottes qui s'affrontent avec des boucliers/éclairs, ambiance compétition amicale. Fond sombre ou transparent pour intégration sur `#141B2E`. | `#141B2E`, `#22D3C5`, `#FFC700` |
| `duel_podium` | Transparent | Podium avec 3 marches, médailles, trophée. | Or `#FFC700`, argent `#C0C0C0`, bronze `#CD7F32` |
| `duel_waiting` | Transparent | Mascotte `mascot_waiting` avec un sablier ou un compteur. | Mascotte + accent `#22D3C5` |
| `duel_invite` | Transparent | Mascotte avec une enveloppe ou un code QR amical. | Fond clair possible |

### 4.5 Empty states / états vides

| Nom | Format | Description | Usage |
|---|---|---|---|
| `empty_friends` | Transparent | Mascotte `mascot_shrug` avec un message invisible + petits avatars fantômes. | `FriendsView` sans amis |
| `empty_review` | Transparent | Mascotte `mascot_shrug` avec un cerveau "tout est à jour". | `ThemesView` quand rien à réviser |
| `empty_leaderboard` | Transparent | Mascotte `mascot_duel` avec une médaille, "sois le premier". | `LeaderboardView` vide |
| `empty_notifications` | Transparent | Mascotte `mascot_sleep` avec une enveloppe vide. | Settings / notifications |

### 4.6 Fond d'ambiance général (optionnel mais fortement recommandé)

| Nom | Format | Description | Usage |
|---|---|---|---|
| `bg_pattern_light` | Tileable / seamless | Petits éléments flottants très pâles (livres, crayons, bulles, étoiles) sur fond transparent. Style très léger. | Fond derrière Home / Thèmes / Profil |

Contraintes : transparent, mosaïquable, opacité très faible (~8-15%), pas de détails denses.

---

## 5. Spécifications techniques pour toutes les images

- **Format PNG** avec transparence pour les mascottes et icônes isolées.
- **Format PNG ou JPG** pour les illustrations plein cadre (JPG acceptable si fond opaque crème).
- **Résolution** : minimum 2× la taille d'affichage cible. Sur mobile (iPhone), viser 1024px de hauteur pour les plein cadre, 512px de hauteur pour les mascottes.
- **Style** : flat vectoriel, Duolingo-like, pas de photoréalisme, pas de dégradés complexes, pas de line art noir, pas de textures granuleuses.
- **Couleurs** : utiliser strictement la palette fournie ci-dessus.
- **Aucun texte** dans les images (sauf si demandé explicitement pour un logo). Le texte est géré par le code.
- **Safe area** : pour les illustrations plein cadre, garder la zone centrale et basse relativement calme pour le texte et les boutons.

---

## 6. Ordre de priorité (MVP d'illustrations)

1. **Mascottes** : `mascot_trophy`, `mascot_cheer`, `mascot_duel`, `mascot_shrug`, `mascot_waiting`.
2. **Icônes matières** : les 8 `theme_icon_*` pour les cartes Thèmes.
3. **Héros onboarding** : `onboarding_welcome`, `onboarding_goal`.
4. **Écrans de fin** : `lesson_success`, `session_streak`.
5. **Duel** : `duel_hero`, `duel_podium`.
6. **Empty states** : `empty_friends`, `empty_review`.
7. **Fond pattern** : `bg_pattern_light`.

---

## 7. Exemple de prompt-type pour l'IA générative

> Flat vector illustration, Duolingo-style, cute chibi mascot with a round head and tiny body, holding a golden trophy, big happy eyes, vibrant orange and yellow color palette, soft pastel accents, no black outlines, transparent background, cheerful pose, mobile app asset, clean shapes, 2D vector style.

Adapter selon l'image demandée.

---

## 8. Références à observer avant de générer

- **Mascotte existante** : observer les images `MascotWave`, `MascotJump`, `MascotRead`, `MascotWink` dans l'app pour copier le style exact.
- **Inspiration générale** : Duolingo (leçons, parcours, célébrations de série), Kahoot (couleurs flash), Headspace (rondeur et calme).
- **Style à éviter** : émojis réalistes, clip art cheap, icônes Material Design, illustrations avec contour noir épais, dégradés métalliques.

---

*Brief généré le 2026-08-05 pour Minduel — app iOS de culture générale.*
