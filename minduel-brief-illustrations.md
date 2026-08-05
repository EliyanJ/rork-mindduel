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

**Important, corrigé après un premier essai raté** : la mascotte n'est PAS un personnage "chibi" générique. C'est un personnage très précis et il faut le décrire exactement comme ça, sinon l'IA invente un tout autre personnage (ça a été le cas : elle a produit une goutte/flamme dégradée au lieu du bon personnage).

### Description exacte du personnage (à copier telle quelle dans chaque prompt) :

La mascotte de Minduel est **un livre rose vivant, avec un cerveau qui pousse sur le dessus** (jeu visuel : "un livre qui pense"). Concrètement :
- Le **corps entier est un livre** fermé (ou ouvert dans la pose lecture), format portrait, couverture rose vive glossy, avec la tranche des pages visible sur le côté et un petit signet/ruban rose qui pend en bas.
- Un **cerveau stylisé rose pâle** (circonvolutions rondes et lisses, pas anatomique/gore) pousse directement sur le dessus du livre, à la place d'une tête.
- **Visage dessiné directement sur la couverture** : deux grands yeux ronds noirs avec un reflet blanc brillant, fins sourcils noirs arqués, bouche ouverte souriante (intérieur rouge/rose), deux joues rondes rosées (blush) de chaque côté.
- **Bras et jambes blancs**, façon peluche/gant, tout ronds, sans doigts détaillés (mains en mitaine arrondie), qui sortent directement des côtés et du bas du livre.
- **Rendu 3D glossy/toy-like** : éclairage doux de studio, reflets brillants sur la couverture et le cerveau, ombrage doux en dégradé, légère ombre portée au sol. PAS un flat design, PAS un aplat de couleur uniforme — c'est un rendu "figurine en plastique brillant", proche des mascottes 3D type Duolingo/Pixar.
- Couleur dominante : **rose vif** (couverture du livre) + **rose pâle** (cerveau) + **blanc** (membres). Pas d'orange, pas de bleu, pas de jaune sur la mascotte elle-même.

- **Poses actuelles dans l'app** :
  - `MascotWave` : debout, une main levée qui salue, sourire ouvert.
  - `MascotJump` : saute en l'air, les deux poings levés, yeux fermés de joie (^ ^).
  - `MascotRead` : tient le livre ouvert devant lui (comme s'il se lisait lui-même), les deux mains sur les pages.
  - `MascotWink` : debout, une main qui salue, pose similaire à Wave.

### À faire absolument avant de générer les nouvelles poses

**Si l'outil de génération accepte une image de référence (upload/img2img), joins directement une des images `MascotWave` ou `MascotJump` en plus du prompt texte.** C'est beaucoup plus fiable que la description texte seule pour conserver exactement le même personnage (mêmes proportions de livre, même cerveau, même visage). Le texte sert alors juste à décrire la nouvelle pose/les nouveaux accessoires, pas à redécrire le personnage.

### Poses à générer (même personnage livre-cerveau, fond transparent PNG) :

| Nom | Description | Usage |
|---|---|---|
| `mascot_trophy` | Le livre-cerveau tient un trophée doré à deux mains ou levé au-dessus de lui, super fier, grand sourire. | Fin de parcours, palier de série, écran de victoire |
| `mascot_cheer` | Le livre-cerveau applaudit (mains qui se rejoignent) ou fait un pouce levé, très encourageant. | Écran d'échec léger de leçon, révision |
| `mascot_duel` | Le livre-cerveau en position de défi, un petit bouclier ou un éclair à la main, pose confiante mais toujours mignonne. | Accueil onglet Duel |
| `mascot_waiting` | Le livre-cerveau assis, qui regarde un sablier ou une montre, patient et détendu. | Lobby multijoueur, chargement |
| `mascot_shrug` | Le livre-cerveau hausse les "épaules" (bras écartés, paumes ouvertes vers le haut), légèrement désolé mais souriant. | Empty states (pas d'amis, rien à réviser) |
| `mascot_gift` | Le livre-cerveau tient un cadeau emballé ou un petit sac de pierres précieuses rouges (rubis), tout content. | Écran de déblocage, boutique, récompense |
| `mascot_brain` | Le livre-cerveau avec une ampoule allumée qui flotte juste au-dessus de son cerveau, l'air inspiré. | Révision, questions de culture |
| `mascot_sleep` | Le livre-cerveau qui dort debout ou assis, yeux fermés en traits courbés, quelques "Z" qui flottent au-dessus. | Pas d'activité, cooldown nuit |

**Contraintes techniques** :
- Fond transparent PNG.
- Ratio hauteur ~1:1 ou 4:5.
- Résolution suffisante pour affichage à ~150px de haut sur mobile (générer 512px ou 1024px de haut).
- Style strictement cohérent avec `MascotWave` / `MascotJump` / `MascotWink` / `MascotRead` existants : même personnage livre-cerveau, même rendu 3D glossy.
- Couleurs : rose vif (couverture), rose pâle (cerveau), blanc (membres) — ne pas changer la couleur de base du personnage, seuls les accessoires (trophée, bouclier, cadeau…) suivent la palette de l'app.

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

**Base du personnage à répéter dans chaque prompt ci-dessous (ne change jamais)** :
> Same exact character as reference: a living pink book mascot with a soft pastel-pink stylized brain (smooth rounded lobes, no gore) growing on top like a head, glossy 3D toy-like render with soft studio lighting and gentle drop shadow — NOT flat vector, NOT 2D illustration. The book body has a vivid glossy pink cover with visible page edges on the side and a small pink ribbon bookmark hanging at the bottom. Face printed on the cover: two big round black eyes with a bright white glossy highlight dot, thin arched black eyebrows, an open smiling mouth, two soft pink round blush cheeks. Chubby soft white plush-like arms and legs with rounded mitten hands, no visible fingers. Colors: vivid pink cover, pale pink brain, white limbs only — no orange, no blue, no yellow on the character itself.

**`mascot_trophy`**
> [Base du personnage ci-dessus.] Pose: standing, proudly holding a small glossy golden trophy up high with both white plush arms raised, huge joyful smile. Small gold #FFC700 sparkle accents around the trophy only. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

**`mascot_cheer`**
> [Base du personnage ci-dessus.] Pose: both white plush arms raised up cheering, or one arm out doing a thumbs up, warm encouraging open-mouth smile. No extra props. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

**`mascot_duel`**
> [Base du personnage ci-dessus.] Pose: confident competitive stance, holding a small glossy round shield or a cartoon lightning bolt in one plush hand, chest slightly forward, playful "ready to battle" energy but still cute and friendly, not aggressive. Small teal #22D3C5 accent glow on the shield/bolt only. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only, designed to sit on a dark navy #141B2E app background. Mobile app asset, glossy 3D toy render, no text.

**`mascot_waiting`**
> [Base du personnage ci-dessus.] Pose: sitting down with legs crossed, calmly looking at a small glossy hourglass floating next to it, relaxed patient expression. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

**`mascot_shrug`**
> [Base du personnage ci-dessus.] Pose: both plush arms out to the sides with palms/mittens turned up in a shrug, head tilted slightly, gentle apologetic but still smiling expression. No extra props. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

**`mascot_gift`**
> [Base du personnage ci-dessus.] Pose: holding out a small glossy wrapped gift box with a gold ribbon in both plush arms, excited giving expression, or holding a tiny pouch with a couple of ruby-red #D81E3A gem shapes peeking out. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

**`mascot_brain`**
> [Base du personnage ci-dessus.] Pose: standing, one small glowing golden light bulb icon floats just above its brain, one plush hand near its chin in a thinking gesture, curious inspired expression. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

**`mascot_sleep`**
> [Base du personnage ci-dessus, but with eyes closed as two soft curved lines instead of open round eyes.] Pose: dozing off, slightly slumped forward or leaning, two or three small "Z" shapes floating above, cozy sleepy mood. Isolated single subject, no background scenery, no ground, no environment — plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

### Onboarding (sticker à sujet unique — pas de scène)

**Base du personnage à répéter dans chaque prompt ci-dessous (identique à la section Mascottes)** :
> Same exact character as reference: a living pink book mascot with a soft pastel-pink stylized brain (smooth rounded lobes, no gore) growing on top like a head, glossy 3D toy-like render with soft studio lighting and gentle drop shadow — NOT flat vector, NOT 2D illustration. The book body has a vivid glossy pink cover with visible page edges on the side and a small pink ribbon bookmark hanging at the bottom. Face printed on the cover: two big round black eyes with a bright white glossy highlight dot, thin arched black eyebrows, an open smiling mouth, two soft pink round blush cheeks. Chubby soft white plush-like arms and legs with rounded mitten hands, no visible fingers. Colors: vivid pink cover, pale pink brain, white limbs only.

**`onboarding_welcome`**
> [Base du personnage ci-dessus.] Single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Pose: waving one arm in a friendly greeting, warm welcoming smile. Exactly one small speech bubble with a simple "?" or "!" symbol floats near it — nothing else. Plain transparent background, or a simple flat cream circle #FDF8EF directly behind the character only. Mobile app asset, glossy 3D toy render, no text, think app icon / sticker, not a storybook illustration.

**`onboarding_topics`**
> [Base du personnage ci-dessus.] Single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Pose: sitting cross-legged with a small open book resting on its lap, calm curious expression. Maximum two small simple flat colored icons floating around it (for example a tiny globe and a tiny music note) — nothing more. Plain transparent background only. Mobile app asset, glossy 3D toy render, no text, think app icon / sticker, not a storybook illustration.

**`onboarding_goal`**
> [Base du personnage ci-dessus.] Single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Pose: jumping joyfully with both fists up (like `MascotJump`), a single stylized orange #FF6B00 flame (streak symbol) floating right beside it. Only one small simple gold badge or checkmark shape floats nearby — nothing else, no detailed calendar grid. Plain transparent background only. Mobile app asset, glossy 3D toy render, no text, think app icon / sticker, not a storybook illustration.

**`onboarding_diagnostic_result`**
> [Base du personnage ci-dessus.] Single centered subject, isolated, no background scenery, no environment, no horizon, no room, no landscape. Pose: standing next to exactly one simple vertical progress bar shape (like a rounded thermometer) half filled with green #3DD62C, one arm pointing at it, winking playfully. Nothing else in the frame — no dashboard, no multiple gauges. Plain transparent background only. Mobile app asset, glossy 3D toy render, no text, think app icon / sticker, not a storybook illustration.

### Écrans de fin de leçon

**`lesson_success`** *(réutilise `mascot_trophy` directement si déjà généré)*
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: holding a golden trophy up high, huge joyful smile. A few simple confetti shapes (small circles, triangles, stars) and one small crown float around it — keep it light, not cluttered. Plain transparent background only. Confetti/crown colors: gold #FFC700, green #3DD62C. Mobile app asset, glossy 3D toy render, no text.

**`session_streak`**
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. One large glossy stylized flame shape (streak symbol) in orange #FF6B00 and gold #FFC700, with the mascot peeking out from behind it or standing right next to it, excited expression. Optionally a few small floating spark shapes around the flame — nothing else. Plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

**`unlock_celebration`** *(réutilise `mascot_gift` directement si déjà généré)*
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: holding a wrapped gift box that is opening, with a couple of ruby-red #D81E3A gem shapes floating out of it, excited surprised expression. Gold #FFC700 ribbon and sparkle accents only. Plain transparent background only. Mobile app asset, glossy 3D toy render, no text.

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
> Two identical "living pink book with a brain on top" mascots (same character as reference — glossy 3D toy render, pink glossy book body, pale pink brain on top, white plush arms and legs, big round eyes) facing each other in a friendly competitive stance, each holding a small glossy round shield or a cartoon lightning bolt, playful energetic "face-off" pose, not aggressive. Single composition, isolated, no environment, no ground, no room, no landscape. Plain transparent background, designed to sit on a dark navy #141B2E app background. Small teal #22D3C5 and gold #FFC700 accents on the shields/bolts only. Mobile app asset, glossy 3D toy render, no text.

**`duel_podium`**
> Simple glossy three-step podium shape (1st taller, 2nd and 3rd shorter), toy-like 3D render matching the mascot's glossy plastic material, with one small medal or star icon on each step. Single centered subject, isolated, no environment, no ground plane beyond the podium itself. Plain transparent background, designed to sit on a dark navy #141B2E app background. Colors: gold #FFC700 for 1st, silver #C0C0C0 for 2nd, bronze #CD7F32 for 3rd. Mobile app asset, no text.

**`duel_waiting`**
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: sitting patiently next to one simple glossy hourglass shape with sand flowing, calm relaxed expression. Plain transparent background, designed to sit on a dark navy #141B2E app background. Small teal #22D3C5 accent on the hourglass only. Mobile app asset, glossy 3D toy render, no text.

**`duel_invite`**
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: holding out a simple glossy envelope or a small card with a friendly wave, welcoming inviting gesture. Plain transparent background. Small teal #22D3C5 and gold #FFC700 accents on the envelope only. Mobile app asset, glossy 3D toy render, no text.

### Empty states

**`empty_friends`** *(réutilise `mascot_shrug` directement si déjà généré)*
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: shrugging with both plush arms up, gentle apologetic but smiling expression, one or two faint ghost-like empty circle silhouettes floating nearby suggesting "no friends yet". Plain transparent background. Mobile app asset, glossy 3D toy render, no text.

**`empty_review`**
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: shrugging cheerfully, one small simple green #3DD62C checkmark icon floating above indicating "all caught up". Plain transparent background. Mobile app asset, glossy 3D toy render, no text.

**`empty_leaderboard`** *(réutilise `mascot_duel` directement si déjà généré)*
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: confident ready stance holding a single gold #FFC700 medal, inviting "be the first" energy. Plain transparent background, designed to sit on a dark navy #141B2E app background. Mobile app asset, glossy 3D toy render, no text.

**`empty_notifications`** *(réutilise `mascot_sleep` directement si déjà généré)*
> [Base du personnage "livre-cerveau glossy 3D" — voir section Mascottes, eyes closed as soft curved lines.] Single centered subject, isolated, no background scenery, no ground, no environment. Pose: dozing off sleepily with small "Z" shapes floating above, one simple empty envelope shape resting nearby, calm quiet mood. Plain transparent background. Mobile app asset, glossy 3D toy render, no text.

### Fond d'ambiance

**`bg_pattern_light`**
> Seamless tileable flat vector pattern, very light and subtle, scattered tiny flat icons like small books, pencils, speech bubbles and stars, low opacity around 10 percent, thin simple shapes, no gradients, no black outlines, evenly spaced across the tile, soft pastel cream and orange tones on a fully transparent background. Designed as a barely-visible background texture for a mobile app screen, extremely subtle and non-distracting.

---

*Brief généré le 2026-08-05 pour Minduel — app iOS de culture générale.*
