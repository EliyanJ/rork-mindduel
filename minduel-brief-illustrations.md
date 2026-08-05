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

**Le problème à éviter absolument** : ne PAS demander "une scène d'onboarding" en général à l'IA — c'est ce qui produit des compositions surchargées, avec 15 éléments mal proportionnés, un fond qui part dans tous les sens, et un rendu "AI slop" générique. Chaque image doit être pensée comme une **icône-clé (key art) à un seul sujet central**, pas un décor.

**Règle d'or, à répéter dans chaque prompt** : *"Single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Maximum 2 secondary props floating around the subject. Plain transparent or single flat color background. Think app icon / sticker, not a storybook illustration."*

Ce sont donc des **compositions de type "sticker"**, pas des scènes. Voici le brief exact pour chacune, à copier-coller telles quelles dans le prompt (en gardant la structure : 1 sujet + 2 accessoires max + fond neutre) :

| Nom | Sujet central (unique) | Accessoires flottants autorisés (2 max) | Fond | Couleurs dominantes |
|---|---|---|---|---|
| `onboarding_welcome` | La mascotte, pose `MascotWave` (debout, qui salue de la main), cadrée épaules-tête bien visible, occupant 60% de la hauteur de l'image | Une bulle de dialogue simple avec un "?" ou un "!" à côté de sa tête. Rien d'autre. | Fond uni transparent ou disque de couleur crème `#FDF8EF` derrière la mascotte, pas de décor | Orange `#FF6B00` (mascotte), crème `#FDF8EF` |
| `onboarding_topics` | La mascotte assise en tailleur, un livre ouvert posé sur les genoux | Seulement 2 petites icônes plates qui flottent autour (ex: un globe et une note de musique), rien de plus | Fond uni transparent | Bleu `#1CB0F6`, vert `#3DD62C`, mascotte orange |
| `onboarding_goal` | La mascotte pose `MascotJump` tenant une flamme de série (streak) dans une main, comme un trophée | Un petit badge/calendrier avec une coche, posé à côté (pas un vrai calendrier détaillé, juste une forme simple) | Fond uni transparent | Orange `#FF6B00`, jaune `#FFC700` |
| `onboarding_diagnostic_result` | La mascotte pose `MascotWink`, debout à côté d'une seule barre de progression verticale simple (comme un thermomètre stylisé), à moitié remplie | Rien d'autre — pas de tableau de bord, pas de multiples jauges | Fond uni transparent | Vert `#3DD62C`, violet `#9B4DFF` |

**Contraintes strictes pour ces 4 images** :
- **Un seul point focal** : l'œil doit aller directement à la mascotte, pas se balader dans un décor.
- **Pas de sol, pas d'arrière-plan de pièce, pas de paysage, pas d'horizon.** Fond transparent ou disque de couleur plat derrière le personnage seulement.
- **Zéro texte** dans l'image (le texte est ajouté par le code).
- **Silhouette lisible** : si on réduit l'image à la taille d'une icône de 80×80px, on doit encore comprendre le sujet.
- Réutiliser exactement les poses de mascotte déjà validées (`MascotWave`, `MascotJump`, `MascotWink`) comme référence de pose et de proportions — ne pas réinventer une nouvelle anatomie.
- Si le rendu ressemble à une illustration de livre pour enfants avec un décor complet → **le refuser et redemander en insistant sur "isolated sticker, no scenery"**.

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

## 9. Prompts prêts à copier-coller (un par élément)

Chaque bloc ci-dessous est autonome : copie-colle-le tel quel dans ton IA de génération d'image, un par un. Le style, les couleurs et les contraintes sont déjà injectés dedans.

### Mascottes

**`mascot_trophy`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, huge expressive round eyes, no visible pupils detail, soft rounded shapes, no black outlines, colored soft edges only. The mascot proudly holds a golden trophy above its head with one arm raised, joyful triumphant pose. Color palette: vivid orange #FF6B00 and yellow gold #FFC700 dominant, small green #3DD62C accents. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no photorealism, no gradients, no text.

**`mascot_cheer`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, huge expressive round eyes, no black outlines, soft rounded colored edges. The mascot is cheering with both arms up or giving a thumbs up, warm encouraging smile, supportive energetic pose. Color palette: vivid orange #FF6B00, green #3DD62C accents. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no gradients, no text.

**`mascot_duel`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, huge expressive round eyes, no black outlines, soft rounded colored edges. The mascot stands in a confident competitive stance, holding a small round shield or a lightning bolt in one hand, playful "ready to battle" energy but still cute and friendly, not aggressive. Color palette: teal #22D3C5 and dark navy #141B2E as background accent, orange #FF6B00 mascot body, gold #FFC700 highlight on the shield. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no gradients, no text.

**`mascot_waiting`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, huge expressive round eyes, no black outlines, soft rounded colored edges. The mascot sits cross-legged, calmly looking at a small simple hourglass or wristwatch floating next to it, patient and relaxed pose. Color palette: teal #22D3C5 accent, orange #FF6B00 mascot body. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no gradients, no text.

**`mascot_shrug`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, huge expressive round eyes, no black outlines, soft rounded colored edges. The mascot shrugs with both palms up and a gentle apologetic but still smiling expression, slightly tilted head, harmless "nothing here" pose. Color palette: orange #FF6B00 mascot body, muted cream #FDF8EF background tone only as a subtle glow, no real background. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no gradients, no text.

**`mascot_gift`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, huge expressive round eyes, no black outlines, soft rounded colored edges. The mascot happily holds out a small wrapped gift box or a little pouch of red gems, excited giving gesture. Color palette: orange #FF6B00 mascot body, ruby red #D81E3A gems, gold #FFC700 ribbon on the gift. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no gradients, no text.

**`mascot_brain`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, huge expressive round eyes, no black outlines, soft rounded colored edges. A single simple glowing light bulb or a small stylized brain icon floats just above the mascot's head, curious thoughtful expression, one hand near the chin. Color palette: orange #FF6B00 mascot body, violet #9B4DFF glow, gold #FFC700 bulb light. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no gradients, no text.

**`mascot_sleep`**
> Flat vector illustration sticker, cute chibi mascot character with a big round head and tiny compact body, closed curved eyes (sleeping), no black outlines, soft rounded colored edges. The mascot is dozing off, slightly slouched, with two or three small floating "Z" letters above its head, cozy sleepy mood. Color palette: muted orange #FF6B00 mascot body, soft navy #141B2E accents for the "Z" shapes. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no gradients, no text.

### Onboarding (sticker à sujet unique — pas de scène)

**`onboarding_welcome`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Cute chibi mascot character, big round head, tiny body, waving one hand in a friendly greeting, big expressive round eyes, warm welcoming smile, no black outlines, soft rounded colored edges. Exactly one small speech bubble with a simple "?" or "!" symbol floats near its head — nothing else. Plain transparent background, or a simple flat cream circle #FDF8EF directly behind the character only. Color palette: vivid orange #FF6B00 mascot, cream #FDF8EF accent, small touches of blue #1CB0F6 and green #3DD62C. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients, think app icon / sticker, not a storybook illustration.

**`onboarding_topics`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Cute chibi mascot character, big round head, tiny body, sitting cross-legged with an open book resting on its lap, calm curious expression, no black outlines, soft rounded colored edges. Maximum two small simple flat icons floating around it (for example a tiny globe and a tiny music note) — nothing more. Plain transparent background only. Color palette: blue #1CB0F6, green #3DD62C, orange #FF6B00 mascot body. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients, think app icon / sticker, not a storybook illustration.

**`onboarding_goal`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Cute chibi mascot character, big round head, tiny body, jumping joyfully while holding a single stylized flame (streak symbol) above its head like a trophy, no black outlines, soft rounded colored edges. Only one small simple badge or checkmark shape floats beside it — nothing else, no detailed calendar grid. Plain transparent background only. Color palette: vivid orange #FF6B00 mascot and flame, gold #FFC700 badge. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients, think app icon / sticker, not a storybook illustration.

**`onboarding_diagnostic_result`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Cute chibi mascot character, big round head, tiny body, standing next to exactly one simple vertical progress bar shape (like a rounded thermometer), half filled, winking playfully, no black outlines, soft rounded colored edges. Nothing else in the frame — no dashboard, no multiple gauges. Plain transparent background only. Color palette: green #3DD62C progress fill, violet #9B4DFF outline/track, orange #FF6B00 mascot body. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients, think app icon / sticker, not a storybook illustration.

### Écrans de fin de leçon

**`lesson_success`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character holding a golden trophy up high, huge round joyful eyes, no black outlines, soft rounded colored edges. A few simple confetti shapes (small circles, triangles, stars) and one small crown float around it — keep it light, not cluttered. Plain transparent background only. Color palette: orange #FF6B00 mascot, gold #FFC700 trophy and confetti, green #3DD62C accents. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`session_streak`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. One large stylized flame shape (streak symbol) with the cute chibi mascot peeking out from behind or standing next to it, excited expression, no black outlines, soft rounded colored edges. Optionally a few small floating spark shapes around the flame — nothing else. Plain transparent background only. Color palette: vivid orange #FF6B00 and gold #FFC700 flame, small red #FF3B5C accents. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`unlock_celebration`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character holding a wrapped gift box that is opening, with a couple of ruby gem shapes floating out of it, excited surprised expression, no black outlines, soft rounded colored edges. Plain transparent background only. Color palette: orange #FF6B00 mascot, ruby red #D81E3A gems, gold #FFC700 ribbon and sparkle accents. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

### Icônes de matières (fond transparent, silhouette blanche simple)

**`theme_icon_histoire`**
> Flat minimal line-and-shape icon, pure white silhouette, simple ancient columns / temple front with a small triangular pediment, symmetrical and clean, single unified shape, no gradients, no shading, no outline stroke besides the white fill itself. Transparent background. Must read clearly as "History" at small size (60x60px). Vector icon style, rounded corners, no text.

**`theme_icon_sciences`**
> Flat minimal line-and-shape icon, pure white silhouette, simple atom symbol made of one circle and two intersecting oval orbit rings, clean and symmetrical, single unified shape, no gradients, no shading. Transparent background. Must read clearly as "Science" at small size (60x60px). Vector icon style, rounded corners, no text.

**`theme_icon_geographie`**
> Flat minimal line-and-shape icon, pure white silhouette, simple globe shape with two or three simple curved continent shapes on it, clean rounded circle base, single unified shape, no gradients, no shading. Transparent background. Must read clearly as "Geography" at small size (60x60px). Vector icon style, rounded corners, no text.

**`theme_icon_litterature`**
> Flat minimal line-and-shape icon, pure white silhouette, simple open book shape seen from the front with a small bookmark ribbon, clean and symmetrical, single unified shape, no gradients, no shading. Transparent background. Must read clearly as "Literature" at small size (60x60px). Vector icon style, rounded corners, no text.

**`theme_icon_arts`**
> Flat minimal line-and-shape icon, pure white silhouette, simple painter's palette shape with a couple of small round paint dots cut out, clean rounded shape, single unified shape, no gradients, no shading. Transparent background. Must read clearly as "Arts" at small size (60x60px). Vector icon style, rounded corners, no text.

**`theme_icon_nature`**
> Flat minimal line-and-shape icon, pure white silhouette, simple single leaf shape with a clean center vein line, rounded and organic but minimal, single unified shape, no gradients, no shading. Transparent background. Must read clearly as "Nature" at small size (60x60px). Vector icon style, rounded corners, no text.

**`theme_icon_technologie`**
> Flat minimal line-and-shape icon, pure white silhouette, simple light bulb shape with a small rocket silhouette accent or simple filament lines inside, clean and rounded, single unified shape, no gradients, no shading. Transparent background. Must read clearly as "Technology" at small size (60x60px). Vector icon style, rounded corners, no text.

**`theme_icon_football`**
> Flat minimal line-and-shape icon, pure white silhouette, simple soccer ball shape with classic pentagon pattern lines, clean round shape, single unified shape, no gradients, no shading. Transparent background. Must read clearly as "Football" at small size (60x60px). Vector icon style, rounded corners, no text.

### Mode Duel

**`duel_hero`**
> Flat vector illustration sticker, single composition, isolated, no environment, no ground, no room, no landscape. Two cute chibi mascot characters (same species, different simple color variation like orange and teal) facing each other in a friendly competitive stance, each holding a small round shield or a lightning bolt, playful energetic "face-off" pose, no black outlines, soft rounded colored edges. Plain transparent background, designed to sit on a dark navy #141B2E app background. Color palette: teal #22D3C5, orange #FF6B00, gold #FFC700 accents. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`duel_podium`**
> Flat vector illustration sticker, single centered subject, isolated, no environment, no ground plane beyond the podium itself. Simple three-step podium shape (1st taller, 2nd and 3rd shorter) with one small medal or star icon on each step, clean geometric shapes, no black outlines. Plain transparent background, designed to sit on a dark navy #141B2E app background. Color palette: gold #FFC700 for 1st, silver #C0C0C0 for 2nd, bronze #CD7F32 for 3rd. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`duel_waiting`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character sitting patiently next to one simple hourglass shape with sand flowing, calm relaxed expression, no black outlines, soft rounded colored edges. Plain transparent background, designed to sit on a dark navy #141B2E app background. Color palette: teal #22D3C5 accent, orange #FF6B00 mascot body. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`duel_invite`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character holding out a simple envelope or a small card with a friendly wave, welcoming inviting gesture, no black outlines, soft rounded colored edges. Plain transparent background. Color palette: teal #22D3C5, orange #FF6B00 mascot body, gold #FFC700 small accent. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

### Empty states

**`empty_friends`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character shrugging with both palms up, gentle apologetic but smiling expression, one or two faint ghost-like empty circle silhouettes floating nearby suggesting "no friends yet", no black outlines, soft rounded colored edges. Plain transparent background. Color palette: orange #FF6B00 mascot, muted cream #FDF8EF faint accents. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`empty_review`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character shrugging cheerfully, one small simple brain or checkmark icon floating above indicating "all caught up", no black outlines, soft rounded colored edges. Plain transparent background. Color palette: orange #FF6B00 mascot, green #3DD62C checkmark accent. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`empty_leaderboard`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character in a confident ready stance holding a single medal, inviting "be the first" energy, no black outlines, soft rounded colored edges. Plain transparent background, designed to sit on a dark navy #141B2E app background. Color palette: teal #22D3C5, gold #FFC700 medal, orange #FF6B00 mascot body. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

**`empty_notifications`**
> Flat vector illustration sticker, single centered subject, isolated, no background scenery, no ground, no environment. Cute chibi mascot character dozing off sleepily with small "Z" shapes floating above, one simple empty envelope shape resting nearby, calm quiet mood, no black outlines, soft rounded colored edges. Plain transparent background. Color palette: muted orange #FF6B00 mascot, soft navy #141B2E accents. Mobile app asset, clean 2D vector style, Duolingo-like aesthetic, no text, no gradients.

### Fond d'ambiance

**`bg_pattern_light`**
> Seamless tileable flat vector pattern, very light and subtle, scattered tiny flat icons like small books, pencils, speech bubbles and stars, low opacity around 10 percent, thin simple shapes, no gradients, no black outlines, evenly spaced across the tile, soft pastel cream and orange tones on a fully transparent background. Designed as a barely-visible background texture for a mobile app screen, extremely subtle and non-distracting.

---

*Brief généré le 2026-08-05 pour Minduel — app iOS de culture générale.*
