# Minduel — Nouveau contenu Phase 2 (nouveaux chapitres)

Généré le 2026-07-11. Complète `# Minduel — Bibliothèque de données.txt` + `minduel-contenu-phase1-nouveaux-chapitres.md`.

**Objectif** : amener chaque discipline à 9 chapitres / 45 questions, pour obtenir exactement 3 étapes de 15 questions dans le chemin thématique.

**⚠️ Changement de code requis, pas seulement du contenu.** D'après le rapport de ton dev sur `AppModel.swift` :
```swift
private static func buildStages(items: [LessonItem], idPrefix: String) -> [PathStage] {
    let stageSize = 9   // ← à passer à 15
```
Sans ce changement, ce nouveau contenu créera juste plus d'étapes de 9 questions (5 étapes au lieu de 3), pas des étapes de 15. Les deux changements (code + contenu) doivent être livrés ensemble.

**Vérification du découpage avec 45 questions et `stageSize = 15`** : la fonction traite les questions par tranches de 15 en partant de 0 → `[0:15], [15:30], [30:45]` = exactement 3 étapes de 15 questions, sans reste (la règle de fusion des restes < 4 questions ne s'applique même pas ici). Idem pour le chemin mixte, qui interlace les 7 disciplines : 315 questions au total (175 existantes + 140 ici) → 21 étapes de 15.

**Format respecté** : même schéma que les phases précédentes, même pattern par lot de 5 (QCM + QCM + Vrai/Faux + Texte à trous + Anagramme). Aucun doublon avec les 175 questions déjà en place (vérifié par sujet et par fait cité).

---

## Récapitulatif des compteurs (après Phase 1 → après Phase 2)

| Discipline | Chapitres | Questions |
|---|---|---|
| Histoire | 5 → **9** | 25 → **45** |
| Sciences | 5 → **9** | 25 → **45** |
| Géographie | 5 → **9** | 25 → **45** |
| Littérature | 5 → **9** | 25 → **45** |
| Arts & Musique | 5 → **9** | 25 → **45** |
| Nature & Animaux | 5 → **9** | 25 → **45** |
| Tech & Espace | 5 → **9** | 25 → **45** |
| **Total catalogue** | 35 → **63** | 175 → **315** |

---

## Histoire (`histoire`)

### La Renaissance (`histoire_renaissance`)

**[hi_rn_1]** (QCM) — Dans quelle ville italienne la Renaissance a-t-elle pris son essor au XVe siècle ?
- Choix : Florence / Venise / Milan / Naples
- Réponse : **Florence**
- Explication : Sous l'impulsion de riches mécènes comme les Médicis, Florence devient au XVe siècle un foyer majeur des arts et des sciences, où travaillent des artistes comme Botticelli et Léonard de Vinci.

**[hi_rn_2]** (QCM) — Quel astronome polonais a proposé un modèle héliocentrique de l'univers au XVIe siècle ?
- Choix : Nicolas Copernic / Galilée / Johannes Kepler / Tycho Brahe
- Réponse : **Nicolas Copernic**
- Explication : Publié en 1543, l'ouvrage de Copernic plaçait le Soleil, et non la Terre, au centre du système solaire, bouleversant la vision du monde héritée de l'Antiquité.

**[hi_rn_3]** (Vrai ou Faux) — Léonard de Vinci était à la fois peintre, ingénieur et scientifique.
- Réponse : **Vrai**
- Explication : Véritable « homme de la Renaissance », Léonard de Vinci a dessiné des machines volantes, étudié l'anatomie humaine et peint la Joconde. Ses carnets contiennent des milliers de croquis techniques.

**[hi_rn_4]** (Texte à trous) — La Renaissance marque un renouveau d'intérêt pour les arts et textes de l'Antiquité ___ et romaine.
- Choix : grecque / égyptienne / perse / celte
- Réponse : **grecque**
- Explication : Les artistes et penseurs de la Renaissance redécouvrent les philosophes, sculpteurs et architectes de la Grèce antique, considérés comme un idéal esthétique à retrouver après le Moyen Âge.

**[hi_rn_5]** (Anagramme) — Mouvement intellectuel de la Renaissance qui place l'être humain au centre de la réflexion
- Réponse : **HUMANISME**
- Explication : L'humanisme valorise la raison, l'éducation et la dignité humaine, en s'appuyant sur les textes antiques redécouverts. Érasme et Thomas More comptent parmi ses figures majeures.

### La Guerre froide (`histoire_guerre_froide`)

**[hi_gf_1]** (QCM) — Quels deux blocs se sont opposés pendant la Guerre froide ?
- Choix : Les États-Unis et l'URSS / La France et l'Allemagne / Le Royaume-Uni et la Chine / Le Japon et les États-Unis
- Réponse : **Les États-Unis et l'URSS**
- Explication : De 1947 à 1991 environ, ces deux superpuissances se sont opposées sans jamais s'affronter militairement de façon directe, dans une course aux armements nucléaires.

**[hi_gf_2]** (QCM) — En quelle année le mur de Berlin est-il tombé ?
- Choix : 1989 / 1991 / 1985 / 1961
- Réponse : **1989**
- Explication : Le mur, construit en 1961 pour séparer Berlin-Est et Berlin-Ouest, tombe le 9 novembre 1989 sous la pression populaire, symbolisant la fin proche de la Guerre froide.

**[hi_gf_3]** (Vrai ou Faux) — La crise des missiles de Cuba, en 1962, a fait craindre une guerre nucléaire entre les États-Unis et l'URSS.
- Réponse : **Vrai**
- Explication : Après la découverte de missiles soviétiques à Cuba, le monde s'est retrouvé au bord d'un conflit nucléaire pendant treize jours, avant un accord entre Kennedy et Khrouchtchev.

**[hi_gf_4]** (Texte à trous) — L'URSS a été dissoute en ___.
- Choix : 1991 / 1989 / 1985 / 1979
- Réponse : **1991**
- Explication : L'Union soviétique se dissout officiellement le 26 décembre 1991, donnant naissance à la Russie et à plusieurs autres États indépendants.

**[hi_gf_5]** (Anagramme) — Activité de collecte secrète d'informations, très développée entre USA et URSS pendant la Guerre froide
- Réponse : **ESPIONNAGE**
- Explication : La Guerre froide fut aussi une guerre de renseignement : la CIA et le KGB rivalisaient d'espionnage et d'opérations secrètes à travers le monde entier.

### Civilisations précolombiennes (`histoire_civilisations_precolombiennes`)

**[hi_cp_1]** (QCM) — Quelle civilisation précolombienne a construit le Machu Picchu ?
- Choix : Les Incas / Les Aztèques / Les Mayas / Les Olmèques
- Réponse : **Les Incas**
- Explication : Construite au XVe siècle dans les Andes péruviennes, cette cité perchée à plus de 2400 mètres d'altitude est restée inconnue des Européens jusqu'à sa redécouverte en 1911.

**[hi_cp_2]** (QCM) — Quelle civilisation a développé un calendrier très précis et de grandes pyramides au Mexique et en Amérique centrale ?
- Choix : Les Mayas / Les Incas / Les Iroquois / Les Sioux
- Réponse : **Les Mayas**
- Explication : Entre 250 et 900 ap. J.-C. environ, la civilisation maya a prospéré en Amérique centrale, développant l'écriture hiéroglyphique et un système de numération avec le zéro.

**[hi_cp_3]** (Vrai ou Faux) — Les Aztèques avaient leur capitale, Tenochtitlan, construite sur un lac.
- Réponse : **Vrai**
- Explication : Fondée vers 1325, Tenochtitlan était bâtie sur des îles du lac Texcoco, reliée à la terre ferme par des chaussées. Les conquistadors la découvrirent aussi grande que les plus grandes villes d'Europe.

**[hi_cp_4]** (Texte à trous) — L'empereur inca portait le titre de ___.
- Choix : Sapa Inca / Pharaon / Tlatoani / Cacique
- Réponse : **Sapa Inca**
- Explication : Considéré comme descendant du dieu Soleil, le Sapa Inca dirigeait un empire qui s'étendait sur plus de 4000 km le long des Andes, relié par un vaste réseau de routes.

**[hi_cp_5]** (Anagramme) — Objet de communication inca fait de cordelettes à nœuds, utilisé pour compter et transmettre des informations
- Réponse : **QUIPU**
- Explication : Sans écriture au sens strict, les Incas utilisaient des quipus, des cordelettes nouées de couleurs différentes, pour enregistrer des données administratives ou des recensements.

### La Chine impériale (`histoire_chine_imperiale`)

**[hi_ci_1]** (QCM) — Quel empereur chinois est à l'origine de la construction de l'armée de terre cuite ?
- Choix : Qin Shi Huang / Kublai Khan / Confucius / Sun Tzu
- Réponse : **Qin Shi Huang**
- Explication : Premier empereur à avoir unifié la Chine en 221 av. J.-C., il fit enterrer près de 8000 soldats en terre cuite grandeur nature pour protéger sa tombe. Ils furent découverts par hasard en 1974.

**[hi_ci_2]** (QCM) — Quelle dynastie chinoise, fondée par Kublai Khan au XIIIe siècle, a régné sur l'un des plus vastes empires de l'histoire ?
- Choix : La dynastie Yuan / La dynastie Ming / La dynastie Tang / La dynastie Han
- Réponse : **La dynastie Yuan**
- Explication : Petit-fils de Gengis Khan, Kublai Khan fonde la dynastie Yuan en 1271 et devient le premier empereur mongol à régner sur toute la Chine, recevant notamment le voyageur vénitien Marco Polo à sa cour.

**[hi_ci_3]** (Vrai ou Faux) — La Grande Muraille de Chine a été construite en une seule fois par un seul empereur.
- Réponse : **Faux**
- Explication : La muraille résulte de plusieurs siècles de constructions et de renforcements successifs, entrepris par différentes dynasties, notamment sous les Qin puis massivement sous les Ming.

**[hi_ci_4]** (Texte à trous) — La ___ était l'ancien réseau de routes commerciales reliant la Chine à l'Europe et au Moyen-Orient.
- Choix : route de la soie / route des épices / voie royale / route de l'ambre
- Réponse : **route de la soie**
- Explication : Empruntée dès l'Antiquité, la route de la soie permettait d'échanger soie, épices, papier et idées entre l'Orient et l'Occident sur des milliers de kilomètres.

**[hi_ci_5]** (Anagramme) — Philosophe chinois du VIe siècle av. J.-C. dont les enseignements moraux ont façonné la société chinoise
- Réponse : **CONFUCIUS**
- Explication : Les préceptes de Confucius, centrés sur le respect, la hiérarchie sociale et l'harmonie, ont influencé la pensée chinoise pendant plus de deux mille ans.

---

## Sciences (`sciences`)

### La Génétique (`sciences_genetique`)

**[sc_ge_1]** (QCM) — Quelle molécule contient l'information génétique des êtres vivants ?
- Choix : L'ADN / L'ARN / Les protéines / Les lipides
- Réponse : **L'ADN**
- Explication : L'ADN est une longue molécule en double hélice qui code l'ensemble des instructions génétiques d'un organisme, transmises de génération en génération.

**[sc_ge_2]** (QCM) — Qui a co-découvert la structure en double hélice de l'ADN en 1953 ?
- Choix : James Watson et Francis Crick / Charles Darwin et Gregor Mendel / Louis Pasteur et Robert Koch / Alexander Fleming et Marie Curie
- Réponse : **James Watson et Francis Crick**
- Explication : Watson et Crick publièrent leur modèle en s'appuyant notamment sur les clichés de diffraction aux rayons X réalisés par Rosalind Franklin, dont le rôle fut longtemps sous-reconnu.

**[sc_ge_3]** (Vrai ou Faux) — Un être humain partage plus de 90 % de son ADN avec un chimpanzé.
- Réponse : **Vrai**
- Explication : Les études génétiques estiment la similarité entre l'ADN humain et celui du chimpanzé à environ 98-99 %, reflet de notre proche parenté évolutive au sein des grands singes.

**[sc_ge_4]** (Texte à trous) — Un ___ est un segment d'ADN qui porte l'information nécessaire à la fabrication d'une protéine.
- Choix : gène / chromosome / neurone / ribosome
- Réponse : **gène**
- Explication : L'être humain possède environ 20 000 à 25 000 gènes, répartis sur 23 paires de chromosomes présentes dans presque toutes les cellules du corps.

**[sc_ge_5]** (Anagramme) — Moine autrichien du XIXe siècle considéré comme le père de la génétique grâce à ses travaux sur les petits pois
- Réponse : **MENDEL**
- Explication : Gregor Mendel établit dans les années 1860 les lois de l'hérédité en croisant des petits pois, jetant les bases de la génétique moderne bien avant la découverte de l'ADN.

### La Chimie (`sciences_chimie`)

**[sc_ci_1]** (QCM) — Quel scientifique russe a créé le tableau périodique des éléments en 1869 ?
- Choix : Dmitri Mendeleïev / Antoine Lavoisier / Marie Curie / Ernest Rutherford
- Réponse : **Dmitri Mendeleïev**
- Explication : Mendeleïev organisa les éléments par masse atomique croissante et propriétés similaires, laissant des cases vides pour des éléments pas encore découverts, dont il prédit correctement les propriétés.

**[sc_ci_2]** (QCM) — Quel est le pH de l'eau pure, considéré comme neutre ?
- Choix : 7 / 0 / 14 / 5
- Réponse : **7**
- Explication : L'échelle de pH va de 0 (très acide) à 14 (très basique), 7 étant le point neutre. Le vinaigre est acide (autour de 2-3) tandis que la javel est basique (autour de 12-13).

**[sc_ci_3]** (Vrai ou Faux) — L'eau est composée de deux atomes d'hydrogène et d'un atome d'oxygène.
- Réponse : **Vrai**
- Explication : La formule chimique de l'eau, H₂O, reflète exactement cette composition. Cette molécule simple est pourtant essentielle à toute forme de vie connue.

**[sc_ci_4]** (Texte à trous) — Le ___ est le gaz le plus abondant dans l'atmosphère terrestre, représentant environ 78 % de l'air.
- Choix : diazote / dioxygène / dioxyde de carbone / hydrogène
- Réponse : **diazote**
- Explication : Contrairement à une idée reçue, ce n'est pas l'oxygène (environ 21 %) mais le diazote qui domine largement la composition de l'air que nous respirons.

**[sc_ci_5]** (Anagramme) — Réaction chimique au cours de laquelle une substance se combine avec le dioxygène, souvent en dégageant de la chaleur
- Réponse : **COMBUSTION**
- Explication : La combustion du bois, du gaz ou de l'essence libère de l'énergie sous forme de chaleur et de lumière : une réaction chimique dite exothermique.

### La Gravité (`sciences_gravite`)

**[sc_gr_1]** (QCM) — Quel scientifique anglais a formulé la loi de la gravitation universelle au XVIIe siècle ?
- Choix : Isaac Newton / Albert Einstein / Galilée / Johannes Kepler
- Réponse : **Isaac Newton**
- Explication : Newton publie sa théorie en 1687, expliquant aussi bien la chute d'une pomme que le mouvement des planètes par une seule et même force : l'attraction gravitationnelle.

**[sc_gr_2]** (QCM) — Quel scientifique a proposé une nouvelle théorie de la gravitation, la relativité générale, au début du XXe siècle ?
- Choix : Albert Einstein / Isaac Newton / Niels Bohr / Max Planck
- Réponse : **Albert Einstein**
- Explication : Publiée en 1915, la relativité générale décrit la gravité comme une déformation de l'espace-temps causée par la masse des objets, confirmée par une observation d'éclipse en 1919.

**[sc_gr_3]** (Vrai ou Faux) — La gravité sur la Lune est plus faible que sur Terre.
- Réponse : **Vrai**
- Explication : La gravité lunaire ne représente qu'environ un sixième de celle de la Terre, en raison de la masse bien plus faible de la Lune.

**[sc_gr_4]** (Texte à trous) — Un objet en orbite autour de la Terre est en état d'___, car il est en chute libre permanente autour de la planète.
- Choix : apesanteur / accélération / immobilité / lévitation
- Réponse : **apesanteur**
- Explication : Il y a bien de la gravité dans la Station spatiale internationale. Les astronautes flottent car la station et son contenu sont en chute libre continue autour de la Terre, à grande vitesse.

**[sc_gr_5]** (Anagramme) — Force qui retient les objets à la surface d'une planète et les empêche de s'envoler dans l'espace
- Réponse : **GRAVITE**
- Explication : Sans la gravité, rien ne resterait à la surface de la Terre. C'est cette même force qui maintient les planètes en orbite autour du Soleil.

### L'Évolution (`sciences_evolution`)

**[sc_ev_1]** (QCM) — Quel naturaliste britannique a formulé la théorie de l'évolution par sélection naturelle ?
- Choix : Charles Darwin / Gregor Mendel / Alfred Wallace / Jean-Baptiste Lamarck
- Réponse : **Charles Darwin**
- Explication : Darwin publie « L'Origine des espèces » en 1859, après un voyage à bord du Beagle qui l'amena notamment aux îles Galápagos, où il observa la diversité des pinsons.

**[sc_ev_2]** (QCM) — Quel est le nom du processus par lequel les individus les mieux adaptés à leur environnement survivent et se reproduisent davantage ?
- Choix : La sélection naturelle / La mutation spontanée / La dérive génétique / L'adaptation forcée
- Réponse : **La sélection naturelle**
- Explication : Ce mécanisme central de la théorie de Darwin explique comment les caractéristiques favorables à la survie se transmettent plus souvent à la génération suivante.

**[sc_ev_3]** (Vrai ou Faux) — L'être humain descend directement du chimpanzé.
- Réponse : **Faux**
- Explication : L'humain et le chimpanzé partagent un ancêtre commun, disparu il y a environ 6 à 7 millions d'années, mais aucune des deux espèces ne descend de l'autre.

**[sc_ev_4]** (Texte à trous) — Les îles ___ ont fortement inspiré Charles Darwin dans l'élaboration de sa théorie de l'évolution.
- Choix : Galápagos / Canaries / Baléares / Féroé
- Réponse : **Galápagos**
- Explication : Lors de son voyage sur le Beagle en 1835, Darwin observa que les pinsons de chaque île de l'archipel avaient un bec différent, adapté à leur nourriture locale.

**[sc_ev_5]** (Anagramme) — Processus par lequel une espèce disparaît définitivement de la planète
- Réponse : **EXTINCTION**
- Explication : On estime que plus de 99 % des espèces ayant existé sur Terre sont aujourd'hui éteintes. Cinq grandes extinctions de masse ont marqué l'histoire de la vie.

---

## Géographie (`geographie`)

### L'Amérique (`geo_amerique`)

**[ge_am_1]** (QCM) — Quel est le plus grand pays d'Amérique du Sud ?
- Choix : Le Brésil / L'Argentine / La Colombie / Le Pérou
- Réponse : **Le Brésil**
- Explication : Avec plus de 8,5 millions de km², le Brésil couvre près de la moitié du continent sud-américain et abrite la majeure partie de la forêt amazonienne.

**[ge_am_2]** (QCM) — Quelle chaîne de montagnes traverse les États-Unis d'est en ouest, aux abords de la côte pacifique ?
- Choix : Les Rocheuses / Les Appalaches / La Sierra Madre / Les Andes
- Réponse : **Les Rocheuses**
- Explication : S'étendant sur environ 4800 km depuis le Canada jusqu'au Nouveau-Mexique, les montagnes Rocheuses constituent l'une des plus longues chaînes d'Amérique du Nord.

**[ge_am_3]** (Vrai ou Faux) — Le Canada possède le plus long littoral de tous les pays du monde.
- Réponse : **Vrai**
- Explication : Grâce à ses innombrables îles et fjords dans l'Arctique, le Canada possède un littoral total dépassant les 200 000 km, largement le plus long au monde.

**[ge_am_4]** (Texte à trous) — Le ___ est le désert le plus sec du monde, situé au Chili.
- Choix : Atacama / Sonora / Mojave / Patagonie
- Réponse : **Atacama**
- Explication : Certaines zones du désert d'Atacama n'ont reçu aucune pluie mesurable depuis des décennies. Son sol extrêmement aride est parfois comparé à celui de la planète Mars.

**[ge_am_5]** (Anagramme) — Isthme d'Amérique centrale traversé par un canal reliant l'Atlantique au Pacifique
- Réponse : **PANAMA**
- Explication : Inauguré en 1914, le canal de Panama fait gagner des milliers de kilomètres aux navires en évitant le contournement de l'Amérique du Sud par le cap Horn.

### L'Asie (`geo_asie`)

**[ge_as_1]** (QCM) — Quel est le pays le plus peuplé du monde aujourd'hui ?
- Choix : L'Inde / La Chine / L'Indonésie / Les États-Unis
- Réponse : **L'Inde**
- Explication : L'Inde a dépassé la Chine en 2023 et compte aujourd'hui environ 1,46 milliard d'habitants, devenant le pays le plus peuplé de la planète.

**[ge_as_2]** (QCM) — Quelle chaîne de montagnes abrite les plus hauts sommets du monde, dont l'Everest ?
- Choix : L'Himalaya / Le Caucase / L'Oural / Le Tian Shan
- Réponse : **L'Himalaya**
- Explication : L'Himalaya s'étend sur plus de 2400 km entre l'Inde, le Népal, le Bhoutan et la Chine, et compte la totalité des quatorze sommets de plus de 8000 mètres sur Terre.

**[ge_as_3]** (Vrai ou Faux) — Le lac Baïkal, en Russie, est le lac d'eau douce le plus profond du monde.
- Réponse : **Vrai**
- Explication : Le lac Baïkal atteint environ 1642 mètres de profondeur et contient à lui seul près de 20 % de l'eau douce liquide non gelée de la planète.

**[ge_as_4]** (Texte à trous) — Le ___ est un désert d'Asie centrale, partagé entre la Mongolie et la Chine.
- Choix : Gobi / Taklamakan / Kara-Koum / Thar
- Réponse : **Gobi**
- Explication : Contrairement aux déserts chauds classiques, le désert de Gobi connaît des hivers glaciaux, avec des températures pouvant descendre sous -40°C.

**[ge_as_5]** (Anagramme) — Archipel d'Asie de l'Est composé de plus de 6800 îles, dont Honshu et Hokkaido
- Réponse : **JAPON**
- Explication : Le Japon est situé sur la « ceinture de feu » du Pacifique, une zone de forte activité volcanique et sismique qui explique la fréquence des tremblements de terre dans le pays.

### L'Afrique (`geo_afrique`)

**[ge_af_1]** (QCM) — Combien de pays compte le continent africain ?
- Choix : 54 / 42 / 61 / 38
- Réponse : **54**
- Explication : L'Afrique compte 54 pays reconnus par l'ONU, ce qui en fait le continent comptant le plus grand nombre d'États souverains au monde.

**[ge_af_2]** (QCM) — Quel est le point culminant du continent africain ?
- Choix : Le Kilimandjaro / Le mont Kenya / Les monts Rwenzori / L'Atlas
- Réponse : **Le Kilimandjaro**
- Explication : Situé en Tanzanie, le Kilimandjaro culmine à environ 5895 mètres. C'est un volcan qui, malgré sa proximité avec l'équateur, conserve un sommet enneigé une bonne partie de l'année.

**[ge_af_3]** (Vrai ou Faux) — Le fleuve Congo est le fleuve le plus profond du monde.
- Réponse : **Vrai**
- Explication : Le fleuve Congo atteint par endroits plus de 220 mètres de profondeur, ce qui en fait le fleuve le plus profond mesuré sur Terre.

**[ge_af_4]** (Texte à trous) — Le lac ___ est le plus grand lac d'Afrique et le deuxième plus grand lac d'eau douce du monde.
- Choix : Victoria / Tanganyika / Malawi / Tchad
- Réponse : **Victoria**
- Explication : Partagé entre le Kenya, l'Ouganda et la Tanzanie, le lac Victoria couvre environ 68 000 km² et constitue la source du Nil Blanc.

**[ge_af_5]** (Anagramme) — Vaste plaine herbeuse africaine, habitat de lions, éléphants et gazelles
- Réponse : **SAVANE**
- Explication : La savane africaine couvre de grandes parties de l'est et du sud du continent. Sa végétation clairsemée permet l'observation de la faune sur de longues distances.

### Climats et biomes (`geo_climats`)

**[ge_cl_1]** (QCM) — Quel type de climat est caractérisé par des étés chauds et secs et des hivers doux et humides, typique du sud de la France ?
- Choix : Le climat méditerranéen / Le climat tropical / Le climat continental / Le climat océanique
- Réponse : **Le climat méditerranéen**
- Explication : Ce climat se retrouve autour de la Méditerranée mais aussi en Californie, au Chili central ou dans le sud-ouest de l'Australie, des régions à des latitudes similaires.

**[ge_cl_2]** (QCM) — Quelle ligne imaginaire divise la Terre en hémisphère nord et hémisphère sud ?
- Choix : L'équateur / Le tropique du Cancer / Le méridien de Greenwich / Le cercle polaire
- Réponse : **L'équateur**
- Explication : L'équateur mesure environ 40 075 km de long. Les régions proches de l'équateur connaissent généralement un climat chaud et humide toute l'année.

**[ge_cl_3]** (Vrai ou Faux) — La forêt tropicale humide reçoit généralement plus de précipitations annuelles que le désert.
- Réponse : **Vrai**
- Explication : Une forêt tropicale peut recevoir plus de 2000 mm de pluie par an, contre souvent moins de 250 mm pour un désert, expliquant la densité de végétation opposée entre les deux biomes.

**[ge_cl_4]** (Texte à trous) — La ___ est une vaste plaine froide et sans arbres, typique des régions arctiques où le sol reste gelé en profondeur.
- Choix : toundra / taïga / steppe / savane
- Réponse : **toundra**
- Explication : Sous la toundra se trouve le pergélisol, un sol resté gelé en permanence. Seules des plantes basses comme les mousses et lichens parviennent à y pousser durant le court été.

**[ge_cl_5]** (Anagramme) — Grande forêt de conifères qui couvre une large bande du Canada, de la Russie et de la Scandinavie
- Réponse : **TAIGA**
- Explication : La taïga, ou forêt boréale, est le plus grand biome terrestre du monde par sa superficie. Elle abrite des espèces adaptées au froid comme l'ours brun ou le lynx.

---

## Littérature (`litterature`)

### Bandes dessinées (`litt_bd_comics`)

**[li_bd_1]** (QCM) — Qui a créé le personnage de Tintin ?
- Choix : Hergé / Albert Uderzo / René Goscinny / Franquin
- Réponse : **Hergé**
- Explication : De son vrai nom Georges Remi, Hergé crée Tintin en 1929 pour un journal belge. La série, traduite dans des dizaines de langues, s'est vendue à plus de 230 millions d'exemplaires.

**[li_bd_2]** (QCM) — Quels sont les deux créateurs originaux de la bande dessinée « Astérix » ?
- Choix : René Goscinny et Albert Uderzo / Hergé et Edgar P. Jacobs / Franquin et Peyo / Morris et Goscinny
- Réponse : **René Goscinny et Albert Uderzo**
- Explication : Le premier album d'Astérix paraît en 1961. Goscinny écrivait les scénarios pleins de jeux de mots, tandis qu'Uderzo dessinait les aventures du petit village gaulois résistant aux Romains.

**[li_bd_3]** (Vrai ou Faux) — Le mot « manga » désigne spécifiquement les bandes dessinées japonaises.
- Réponse : **Vrai**
- Explication : Utilisé au Japon pour désigner la bande dessinée en général, ce terme s'est répandu à l'international pour désigner spécifiquement les BD d'origine japonaise, souvent lues de droite à gauche.

**[li_bd_4]** (Texte à trous) — Le personnage de ___ est un cow-boy solitaire qui « tire plus vite que son ombre », créé par Morris.
- Choix : Lucky Luke / Blueberry / Rantanplan / Averell
- Réponse : **Lucky Luke**
- Explication : Créé en 1946, Lucky Luke parcourt le Far West accompagné de son cheval Jolly Jumper. Goscinny rejoindra plus tard Morris comme scénariste de la série.

**[li_bd_5]** (Anagramme) — Élément graphique en forme de nuage qui contient les paroles d'un personnage de BD
- Réponse : **BULLE**
- Explication : La bulle (ou phylactère, son nom plus savant) est apparue dès la fin du XIXe siècle dans la presse américaine, avant de devenir un code visuel universel de la bande dessinée.

### Prix littéraires (`litt_prix_litteraires`)

**[li_pr_1]** (QCM) — Comment s'appelle le plus prestigieux prix littéraire français, décerné chaque année depuis 1903 ?
- Choix : Le prix Goncourt / Le prix Renaudot / Le prix Femina / Le prix Médicis
- Réponse : **Le prix Goncourt**
- Explication : Créé grâce au legs de l'écrivain Edmond de Goncourt, ce prix est décerné chaque automne par une académie de dix membres. Le lauréat ne reçoit officiellement que 10 euros, mais voit ses ventes exploser.

**[li_pr_2]** (QCM) — Quel prix international récompense chaque année une œuvre littéraire marquante, remis à Stockholm ?
- Choix : Le prix Nobel de littérature / Le prix Pulitzer / Le Man Booker Prize / Le prix Cervantès
- Réponse : **Le prix Nobel de littérature**
- Explication : Décerné depuis 1901 selon les volontés d'Alfred Nobel, ce prix a récompensé des auteurs comme Albert Camus, Gabriel García Márquez ou Toni Morrison.

**[li_pr_3]** (Vrai ou Faux) — Marcel Proust a reçu le prix Goncourt pour son roman « À l'ombre des jeunes filles en fleurs ».
- Réponse : **Vrai**
- Explication : Proust reçoit le prix Goncourt en 1919 pour ce deuxième tome de « À la recherche du temps perdu », une consécration tardive pour un auteur alors âgé de 48 ans.

**[li_pr_4]** (Texte à trous) — Le prix ___ récompense chaque année une œuvre de fiction ou de non-fiction aux États-Unis, dans de nombreuses catégories dont le journalisme.
- Choix : Pulitzer / Booker / Hugo / Nebula
- Réponse : **Pulitzer**
- Explication : Créé grâce au legs du magnat de la presse Joseph Pulitzer, ce prix est décerné depuis 1917 et couvre aussi bien la littérature que le journalisme ou la photographie.

**[li_pr_5]** (Anagramme) — Écrivaine française devenue en 1980 la première femme élue à l'Académie française
- Réponse : **YOURCENAR**
- Explication : Marguerite Yourcenar, autrice notamment des « Mémoires d'Hadrien », devient en 1980 la première femme admise sous la Coupole en plus de 340 ans d'histoire de l'institution.

### Théâtre antique (`litt_theatre_antique`)

**[li_ta_1]** (QCM) — Dans quel pays antique le théâtre occidental est-il né ?
- Choix : La Grèce / L'Égypte / Rome / La Perse
- Réponse : **La Grèce**
- Explication : Le théâtre grec naît au VIe siècle av. J.-C. à Athènes, lors de fêtes religieuses en l'honneur du dieu Dionysos, jouées en plein air devant des milliers de spectateurs.

**[li_ta_2]** (QCM) — Quel dramaturge grec est l'auteur de la tragédie « Œdipe roi » ?
- Choix : Sophocle / Euripide / Eschyle / Aristophane
- Réponse : **Sophocle**
- Explication : Écrite au Ve siècle av. J.-C., cette tragédie raconte comment Œdipe découvre malgré lui qu'il a tué son père et épousé sa mère, un mythe qui inspirera le terme de « complexe d'Œdipe ».

**[li_ta_3]** (Vrai ou Faux) — Dans le théâtre grec antique, les acteurs portaient des masques.
- Réponse : **Vrai**
- Explication : Les masques permettaient de jouer plusieurs rôles avec la même troupe et d'amplifier la voix grâce à leur forme, dans de vastes amphithéâtres en plein air.

**[li_ta_4]** (Texte à trous) — La ___ est un genre théâtral antique qui met en scène des personnages ridicules dans des situations absurdes pour faire rire, contrairement à la tragédie.
- Choix : comédie / épopée / élégie / ode
- Réponse : **comédie**
- Explication : Aristophane est le plus célèbre auteur de comédies grecques antiques, souvent satiriques envers la politique et la société athéniennes de son époque.

**[li_ta_5]** (Anagramme) — Espace en demi-cercle où se tenait le chœur dans un théâtre grec antique, entre le public et la scène
- Réponse : **ORCHESTRA**
- Explication : Ce mot grec, qui signifie littéralement « lieu où l'on danse », a donné plus tard le mot français « orchestre ».

### Grandes autrices (`litt_femmes_ecrivaines`)

**[li_fe_1]** (QCM) — Quelle autrice française du XXe siècle a écrit l'essai « Le Deuxième Sexe » ?
- Choix : Simone de Beauvoir / Simone Veil / George Sand / Colette
- Réponse : **Simone de Beauvoir**
- Explication : Publié en 1949, cet essai philosophique et féministe majeur analyse la condition des femmes dans la société, avec la formule devenue célèbre : « On ne naît pas femme, on le devient. »

**[li_fe_2]** (QCM) — Quel est le vrai nom de l'écrivaine française du XIXe siècle connue sous le pseudonyme George Sand ?
- Choix : Amantine Lucile Aurore Dupin / Amélie Nothomb / Colette / Marguerite Duras
- Réponse : **Amantine Lucile Aurore Dupin**
- Explication : George Sand adopta un pseudonyme masculin pour être prise au sérieux dans le monde littéraire du XIXe siècle, dominé par les hommes.

**[li_fe_3]** (Vrai ou Faux) — Colette a été la première femme à recevoir des funérailles nationales en France.
- Réponse : **Vrai**
- Explication : À sa mort en 1954, l'écrivaine Colette reçoit des funérailles nationales, une première pour une femme en France.

**[li_fe_4]** (Texte à trous) — L'écrivaine ___, autrice de « L'Amant », a reçu le prix Goncourt en 1984.
- Choix : Marguerite Duras / Annie Ernaux / Nathalie Sarraute / Françoise Sagan
- Réponse : **Marguerite Duras**
- Explication : « L'Amant », roman largement autobiographique sur son adolescence en Indochine française, connaît un immense succès et est traduit dans des dizaines de langues.

**[li_fe_5]** (Anagramme) — Autrice française contemporaine, prix Nobel de littérature en 2022 pour une œuvre inspirée de sa propre vie
- Réponse : **ERNAUX**
- Explication : Annie Ernaux devient en 2022 la première femme française à recevoir le prix Nobel de littérature, récompensée pour une œuvre qui explore sa mémoire personnelle et les classes sociales.

---

## Arts & Musique (`arts`)

### Le Cinéma (`arts_cinema`)

**[ar_ci_1]** (QCM) — Quelle cérémonie américaine récompense chaque année les meilleurs films de l'industrie du cinéma ?
- Choix : Les Oscars / Les Golden Globes / Les César / Le Festival de Cannes
- Réponse : **Les Oscars**
- Explication : Décernés depuis 1929 par l'Académie des arts et des sciences du cinéma, les Oscars sont considérés comme la récompense la plus prestigieuse de l'industrie cinématographique américaine.

**[ar_ci_2]** (QCM) — Comment s'appelle la récompense suprême décernée au Festival de Cannes ?
- Choix : La Palme d'or / L'Ours d'or / Le Lion d'or / La Coquille d'or
- Réponse : **La Palme d'or**
- Explication : Créée en 1955, la Palme d'or est la récompense la plus prestigieuse du Festival de Cannes, l'un des plus importants festivals de cinéma au monde, fondé en 1946.

**[ar_ci_3]** (Vrai ou Faux) — Le premier film sonore de l'histoire du cinéma est sorti dans les années 1920.
- Réponse : **Vrai**
- Explication : « Le Chanteur de jazz », sorti en 1927, est considéré comme le premier long métrage avec des dialogues synchronisés, marquant le début du cinéma parlant.

**[ar_ci_4]** (Texte à trous) — Le prix français équivalent aux Oscars s'appelle le ___.
- Choix : César / Molière / Goncourt / Femina
- Réponse : **César**
- Explication : Créés en 1976, les César récompensent chaque année les meilleurs films et artistes du cinéma français, lors d'une cérémonie à Paris.

**[ar_ci_5]** (Anagramme) — Technique consistant à filmer image par image des objets immobiles pour donner l'illusion du mouvement
- Réponse : **ANIMATION**
- Explication : Le cinéma d'animation regroupe des techniques variées : dessin traditionnel, pâte à modeler ou images de synthèse, et ne se limite pas aux films pour enfants.

### La Photographie (`arts_photographie`)

**[ar_ph_1]** (QCM) — Qui est crédité de l'invention du premier procédé photographique durable au XIXe siècle ?
- Choix : Nicéphore Niépce / Louis Daguerre / George Eastman / Eadweard Muybridge
- Réponse : **Nicéphore Niépce**
- Explication : Vers 1826-1827, ce Français réalise ce qui est considéré comme la première photographie permanente de l'histoire, avec un temps de pose de plusieurs heures.

**[ar_ph_2]** (QCM) — Quel procédé photographique du XIXe siècle, portant le nom de son inventeur, a rendu la photographie plus accessible au grand public ?
- Choix : Le daguerréotype / Le calotype / L'ambrotype / Le collodion
- Réponse : **Le daguerréotype**
- Explication : Mis au point par Louis Daguerre et présenté au public en 1839, ce procédé réduisait le temps de pose à quelques minutes, rendant la photographie de portrait beaucoup plus praticable.

**[ar_ph_3]** (Vrai ou Faux) — Les premiers appareils photo numériques grand public sont apparus dans les années 1990.
- Réponse : **Vrai**
- Explication : Bien que le premier prototype numérique ait été développé chez Kodak dès 1975, ce n'est que dans les années 1990 que les appareils numériques deviennent accessibles au grand public.

**[ar_ph_4]** (Texte à trous) — L'___ d'un appareil photo contrôle la quantité de lumière qui entre par l'objectif.
- Choix : ouverture / obturateur / capteur / zoom
- Réponse : **ouverture**
- Explication : L'ouverture, mesurée en valeurs f (comme f/2.8 ou f/16), influence aussi la profondeur de champ : une grande ouverture donne un arrière-plan flou, une petite ouverture garde tout net.

**[ar_ph_5]** (Anagramme) — Appareil optique sans objectif, ancêtre de la photographie, qui projette une image inversée à travers un petit trou
- Réponse : **STENOPE**
- Explication : Le principe de la « chambre noire » ou sténopé est connu depuis l'Antiquité et a servi de base théorique à l'invention de l'appareil photo plusieurs siècles plus tard.

### Mode et design (`arts_mode_design`)

**[ar_md_1]** (QCM) — Quelle créatrice française a révolutionné la mode féminine au XXe siècle avec des vêtements plus simples, et son célèbre parfum n°5 ?
- Choix : Coco Chanel / Christian Dior / Yves Saint Laurent / Sonia Rykiel
- Réponse : **Coco Chanel**
- Explication : Dans les années 1920, Chanel libère les femmes des corsets en popularisant des coupes plus souples, comme la petite robe noire, devenue un incontournable intemporel.

**[ar_md_2]** (QCM) — Quel créateur français est à l'origine du fameux « New Look » qui a marqué la mode d'après-guerre en 1947 ?
- Choix : Christian Dior / Coco Chanel / Pierre Cardin / Hubert de Givenchy
- Réponse : **Christian Dior**
- Explication : Le « New Look » de Dior, avec ses jupes amples et sa taille marquée, tranchait avec les restrictions de tissu de la Seconde Guerre mondiale et relança le prestige de la mode parisienne.

**[ar_md_3]** (Vrai ou Faux) — Paris est historiquement considérée comme l'une des capitales mondiales de la haute couture.
- Réponse : **Vrai**
- Explication : La haute couture, appellation protégée réservée à un nombre restreint de maisons, est étroitement associée à Paris depuis le XIXe siècle et le couturier Charles Frederick Worth.

**[ar_md_4]** (Texte à trous) — Le ___ est un défilé où les mannequins présentent les collections d'un créateur devant un public de professionnels et de journalistes.
- Choix : podium / atelier / salon / gala
- Réponse : **podium**
- Explication : Les défilés de mode rythment le calendrier de la mode internationale, avec des semaines dédiées à Paris, Milan, New York et Londres.

**[ar_md_5]** (Anagramme) — Tissu résistant en coton, souvent bleu, utilisé pour fabriquer les jeans
- Réponse : **DENIM**
- Explication : Le denim tire son nom de la ville française de Nîmes (« de Nîmes »), où ce tissu robuste était fabriqué à l'origine avant de devenir mondialement associé au blue-jean américain.

### L'Opéra (`arts_opera`)

**[ar_op_1]** (QCM) — Quel compositeur italien est l'auteur des opéras « La Traviata » et « Aïda » ?
- Choix : Giuseppe Verdi / Giacomo Puccini / Gioachino Rossini / Gaetano Donizetti
- Réponse : **Giuseppe Verdi**
- Explication : Verdi domine l'opéra italien du XIXe siècle avec des œuvres jouées encore aujourd'hui dans le monde entier. « Aïda » fut composé pour l'inauguration de l'opéra du Caire.

**[ar_op_2]** (QCM) — Quel compositeur allemand a créé un cycle de quatre opéras appelé « L'Anneau du Nibelung » ?
- Choix : Richard Wagner / Johann Strauss / Ludwig van Beethoven / Johannes Brahms
- Réponse : **Richard Wagner**
- Explication : Cette œuvre monumentale, inspirée de mythes germaniques et nordiques, dure au total près de 15 heures et a nécessité la construction d'un théâtre spécialement conçu pour elle, à Bayreuth.

**[ar_op_3]** (Vrai ou Faux) — Dans un opéra, les dialogues chantés accompagnés uniquement d'un instrument, sans mélodie développée, s'appellent des récitatifs.
- Réponse : **Vrai**
- Explication : Le récitatif fait avancer l'intrigue de façon proche du langage parlé, tandis que l'air permet au personnage d'exprimer ses émotions sur une mélodie plus développée.

**[ar_op_4]** (Texte à trous) — Le célèbre opéra Garnier, à ___, est aussi appelé « Palais Garnier » du nom de son architecte.
- Choix : Paris / Vienne / Milan / Londres
- Réponse : **Paris**
- Explication : Inauguré en 1875, l'Opéra Garnier est réputé pour son architecture somptueuse ainsi que pour le plafond peint par Marc Chagall en 1964, un siècle après sa construction.

**[ar_op_5]** (Anagramme) — Voix de femme la plus aiguë dans le classement des voix lyriques
- Réponse : **SOPRANO**
- Explication : Du grave à l'aigu, les voix féminines se classent en contralto, mezzo-soprano puis soprano. Les rôles principaux féminins des grands opéras sont très souvent écrits pour une voix de soprano.

---

## Nature & Animaux (`nature`)

### Les Oiseaux (`nature_oiseaux`)

**[na_oi_1]** (QCM) — Quel est le plus grand oiseau volant du monde en envergure ?
- Choix : L'albatros hurleur / L'aigle royal / Le condor des Andes / Le pélican
- Réponse : **L'albatros hurleur**
- Explication : L'albatros hurleur peut déployer une envergure d'environ 3,5 mètres, la plus grande de tous les oiseaux volants actuels, lui permettant de planer des heures au-dessus de l'océan.

**[na_oi_2]** (QCM) — Quel oiseau est capable de voler à reculons ?
- Choix : Le colibri / L'aigle / Le moineau / Le pigeon
- Réponse : **Le colibri**
- Explication : Grâce à des ailes capables de battre jusqu'à 80 fois par seconde selon l'espèce, le colibri est le seul oiseau capable de voler sur place, mais aussi en arrière.

**[na_oi_3]** (Vrai ou Faux) — Les pingouins et les manchots sont exactement le même animal.
- Réponse : **Faux**
- Explication : En français, on confond souvent les deux, mais les manchots (hémisphère sud, incapables de voler) et les pingouins (hémisphère nord) sont des familles d'oiseaux différentes.

**[na_oi_4]** (Texte à trous) — La ___ migratrice parcourt chaque année l'un des plus longs trajets migratoires connus, entre l'Arctique et l'Antarctique.
- Choix : sterne / cygne / héron / faucon
- Réponse : **sterne**
- Explication : La sterne arctique peut parcourir jusqu'à 70 000 km par an lors de sa migration annuelle, voyant ainsi passer deux étés par an, un record chez les animaux migrateurs.

**[na_oi_5]** (Anagramme) — Rapace nocturne aux grands yeux, connu pour son cri caractéristique et sa capacité à tourner la tête à presque 270 degrés
- Réponse : **HIBOU**
- Explication : Contrairement à la chouette, le hibou se distingue par ses aigrettes, deux touffes de plumes ressemblant à des oreilles sur le sommet de sa tête.

### Les Mammifères (`nature_mammiferes`)

**[na_ma_1]** (QCM) — Quel est le seul mammifère capable de voler activement, et non simplement de planer ?
- Choix : La chauve-souris / L'écureuil volant / Le phalanger volant / Le colugo
- Réponse : **La chauve-souris**
- Explication : Grâce à une membrane tendue entre ses doigts très allongés, la chauve-souris peut voler activement, contrairement à l'écureuil volant qui ne fait que planer d'arbre en arbre.

**[na_ma_2]** (QCM) — Quel petit mammifère peut se rouler en boule hérissée de piquants pour se protéger ?
- Choix : Le hérisson / La musaraigne / Le porc-épic / Le tatou
- Réponse : **Le hérisson**
- Explication : Le hérisson possède environ 5000 à 7000 piquants sur le dos. En cas de danger, des muscles spécifiques lui permettent de se rouler en boule complète.

**[na_ma_3]** (Vrai ou Faux) — L'ornithorynque, mammifère australien, pond des œufs.
- Réponse : **Vrai**
- Explication : L'ornithorynque fait partie des rares mammifères ovipares au monde, aux côtés des échidnés. Il possède aussi un venin et un bec de canard.

**[na_ma_4]** (Texte à trous) — La ___ est le plus grand mammifère marin et le plus grand animal ayant jamais existé sur Terre.
- Choix : baleine bleue / orque / cachalot / baleine à bosse
- Réponse : **baleine bleue**
- Explication : Un cœur de baleine bleue peut peser autant qu'une petite voiture. Son cri, l'un des sons les plus puissants émis par un animal, peut porter à des centaines de kilomètres sous l'eau.

**[na_ma_5]** (Anagramme) — Petit mammifère marsupial australien qui se nourrit presque exclusivement de feuilles d'eucalyptus
- Réponse : **KOALA**
- Explication : Le koala dort en moyenne entre 18 et 20 heures par jour, en grande partie parce que les feuilles d'eucalyptus qu'il mange sont pauvres en nutriments et toxiques pour la plupart des autres animaux.

### Reptiles et Amphibiens (`nature_reptiles_amphibiens`)

**[na_ra_1]** (QCM) — Quel est le plus grand reptile vivant actuellement ?
- Choix : Le crocodile marin / L'anaconda / Le varan de Komodo / La tortue luth
- Réponse : **Le crocodile marin**
- Explication : Le crocodile marin peut dépasser 6 mètres de long. C'est aussi l'un des prédateurs les plus puissants au monde, capable de nager en pleine mer sur de longues distances.

**[na_ra_2]** (QCM) — Quelle caractéristique permet de distinguer un amphibien d'un reptile ?
- Choix : Sa peau nue et humide, sans écailles / Ses écailles / Ses griffes / Sa capacité à pondre des œufs
- Réponse : **Sa peau nue et humide, sans écailles**
- Explication : Contrairement aux reptiles à peau écailleuse et imperméable, les amphibiens comme les grenouilles ont une peau fine qui doit rester humide, car elle participe à leur respiration.

**[na_ra_3]** (Vrai ou Faux) — Les caméléons changent de couleur uniquement pour se camoufler.
- Réponse : **Faux**
- Explication : Si le camouflage joue un rôle, les caméléons changent surtout de couleur pour communiquer : exprimer leur humeur, réguler leur température ou séduire un partenaire.

**[na_ra_4]** (Texte à trous) — Le ___ est un amphibien capable de régénérer des membres entiers, dont sa queue, ses pattes, voire une partie de son cœur.
- Choix : axolotl / crapaud / triton / têtard
- Réponse : **axolotl**
- Explication : Originaire du Mexique et aujourd'hui en danger critique dans la nature, l'axolotl fascine les scientifiques pour ses capacités de régénération exceptionnelles.

**[na_ra_5]** (Anagramme) — Reptile sans pattes, dont certaines espèces sont venimeuses
- Réponse : **SERPENT**
- Explication : On recense plus de 3000 espèces de serpents dans le monde, dont environ 600 sont venimeuses. Ils détectent leurs proies grâce à leur langue fourchue.

### Animaux domestiques (`nature_animaux_domestiques`)

**[na_ad_1]** (QCM) — Quel animal a été domestiqué en premier par l'être humain, il y a plusieurs dizaines de milliers d'années ?
- Choix : Le chien / Le chat / Le cheval / La vache
- Réponse : **Le chien**
- Explication : Le chien descend du loup et aurait été domestiqué il y a au moins 15 000 ans, voire davantage selon certaines études, ce qui en fait le plus ancien animal domestique connu.

**[na_ad_2]** (QCM) — Dans quelle ancienne civilisation le chat était-il considéré comme un animal sacré ?
- Choix : L'Égypte antique / La Grèce antique / L'Empire romain / La Mésopotamie
- Réponse : **L'Égypte antique**
- Explication : Les chats étaient si respectés en Égypte antique que leur mort était pleurée par toute la famille, et certains étaient momifiés. La déesse Bastet y était représentée avec une tête de chat.

**[na_ad_3]** (Vrai ou Faux) — Les chevaux peuvent dormir debout.
- Réponse : **Vrai**
- Explication : Grâce à un système d'articulations qui se verrouillent dans leurs pattes, les chevaux peuvent dormir debout, même s'ils ont aussi besoin de courtes phases de sommeil allongé.

**[na_ad_4]** (Texte à trous) — Le ___ est un petit rongeur domestique originaire des Andes, souvent gardé comme animal de compagnie.
- Choix : cochon d'Inde / hamster / gerbille / chinchilla
- Réponse : **cochon d'Inde**
- Explication : Malgré son nom, le cochon d'Inde n'est ni un cochon ni originaire d'Inde : il vient des Andes, en Amérique du Sud.

**[na_ad_5]** (Anagramme) — Race de chien réputée pour son caractère docile, souvent utilisée comme chien-guide pour les personnes aveugles
- Réponse : **LABRADOR**
- Explication : Originaire de Terre-Neuve malgré son nom, le labrador est aujourd'hui l'une des races de chiens les plus populaires au monde, appréciée pour son tempérament calme.

---

## Tech & Espace (`technologie`)

### Internet et réseaux (`tech_internet_reseaux`)

**[te_ir_1]** (QCM) — Quel réseau, ancêtre d'Internet, a été créé par l'armée américaine à la fin des années 1960 ?
- Choix : ARPANET / ETHERNET / TCP-NET / USENET
- Réponse : **ARPANET**
- Explication : Mis en service en 1969, ARPANET reliait à l'origine quatre universités américaines et a jeté les bases techniques du réseau devenu Internet.

**[te_ir_2]** (QCM) — Quel protocole permet d'envoyer des e-mails sur Internet ?
- Choix : SMTP / HTTP / FTP / DNS
- Réponse : **SMTP**
- Explication : SMTP gère l'envoi des e-mails depuis les années 1980. HTTP, lui, sert à afficher les pages web, et le DNS traduit les noms de domaine en adresses numériques.

**[te_ir_3]** (Vrai ou Faux) — Le premier smartphone doté d'un écran tactile capacitif grand public est sorti en 2007.
- Réponse : **Vrai**
- Explication : Présenté par Apple en janvier 2007, l'iPhone original popularise l'écran tactile capacitif multi-touch, transformant durablement l'usage des téléphones mobiles.

**[te_ir_4]** (Texte à trous) — Le ___ est un réseau privé qui chiffre la connexion internet pour protéger la vie privée de l'utilisateur.
- Choix : VPN / DNS / Wi-Fi / Bluetooth
- Réponse : **VPN**
- Explication : Un VPN fait transiter le trafic internet par un serveur intermédiaire chiffré, masquant notamment l'adresse IP réelle de l'utilisateur aux sites visités.

**[te_ir_5]** (Anagramme) — Logiciel malveillant qui se propage d'un ordinateur à l'autre en s'attachant à d'autres programmes
- Réponse : **VIRUS**
- Explication : Le terme informatique s'inspire directement du virus biologique, car ce type de programme a besoin d'un « hôte » pour se propager d'une machine à l'autre.

### Télescopes et astronomie (`tech_telescopes_astronomie`)

**[te_ta_1]** (QCM) — Quel astronome italien a été l'un des premiers à utiliser une lunette pour observer le ciel, au début du XVIIe siècle ?
- Choix : Galilée / Copernic / Kepler / Newton
- Réponse : **Galilée**
- Explication : À partir de 1609, Galilée pointe sa lunette vers le ciel et découvre les cratères de la Lune, les quatre plus grandes lunes de Jupiter et les phases de Vénus.

**[te_ta_2]** (QCM) — Quel télescope spatial, lancé en 1990, a révolutionné l'astronomie en observant l'univers sans la distorsion de l'atmosphère terrestre ?
- Choix : Le télescope Hubble / Le télescope James Webb / Le télescope Kepler / Le télescope Spitzer
- Réponse : **Le télescope Hubble**
- Explication : Placé en orbite autour de la Terre, Hubble a fourni des images d'une netteté inédite, permettant notamment de mieux estimer l'âge de l'univers.

**[te_ta_3]** (Vrai ou Faux) — Le télescope James Webb observe principalement dans le domaine de la lumière infrarouge.
- Réponse : **Vrai**
- Explication : L'observation en infrarouge permet à James Webb, lancé en 2021, de voir à travers les nuages de poussière cosmique et d'observer des galaxies extrêmement lointaines.

**[te_ta_4]** (Texte à trous) — Une ___ est une unité de distance utilisée en astronomie, correspondant à la distance parcourue par la lumière en une année.
- Choix : année-lumière / unité astronomique / parsec / seconde-lumière
- Réponse : **année-lumière**
- Explication : Une année-lumière équivaut à environ 9500 milliards de kilomètres, une unité nécessaire car les distances entre étoiles sont bien trop grandes pour être exprimées en kilomètres.

**[te_ta_5]** (Anagramme) — Instrument optique qui grossit les objets lointains grâce à des lentilles ou des miroirs
- Réponse : **TELESCOPE**
- Explication : Le mot vient du grec « tele » (loin) et « skopein » (observer). Les plus grands télescopes terrestres utilisent des miroirs de plusieurs dizaines de mètres de diamètre.

### Jeux vidéo (`tech_jeux_video`)

**[te_jv_1]** (QCM) — Quel est le nom du premier jeu vidéo d'arcade à succès commercial, sorti en 1972 ?
- Choix : Pong / Pac-Man / Space Invaders / Tetris
- Réponse : **Pong**
- Explication : Créé par Atari, Pong simulait une partie de tennis de table en noir et blanc. Son succès dans les bars a lancé l'industrie du jeu vidéo d'arcade au début des années 1970.

**[te_jv_2]** (QCM) — Quel plombier moustachu, créé par Nintendo, est devenu l'un des personnages de jeu vidéo les plus connus au monde ?
- Choix : Mario / Luigi / Sonic / Link
- Réponse : **Mario**
- Explication : Apparu en 1981 dans le jeu d'arcade « Donkey Kong », Mario est depuis devenu la mascotte de Nintendo, avec des centaines de jeux à son nom vendus dans le monde.

**[te_jv_3]** (Vrai ou Faux) — Le jeu Tetris a été créé par un programmeur soviétique dans les années 1980.
- Réponse : **Vrai**
- Explication : Alexey Pajitnov crée Tetris en 1984 en Union soviétique. Basé sur l'assemblage de pièces géométriques, il deviendra l'un des jeux vidéo les plus vendus de tous les temps.

**[te_jv_4]** (Texte à trous) — Le terme ___ désigne un jeu vidéo pratiqué de manière compétitive, souvent lors de tournois suivis par un large public.
- Choix : e-sport / speedrun / gameplay / streaming
- Réponse : **e-sport**
- Explication : L'e-sport rassemble aujourd'hui des millions de spectateurs pour des compétitions dont les cagnottes peuvent dépasser plusieurs millions de dollars.

**[te_jv_5]** (Anagramme) — Genre de jeu vidéo où le joueur explore un monde ouvert et incarne un personnage évoluant au fil de l'aventure
- Réponse : **AVENTURE**
- Explication : Les jeux d'aventure mettent l'accent sur l'exploration, la narration et la résolution d'énigmes, parfois combinés à d'autres genres pour former des « jeux d'action-aventure ».

### Innovations médicales (`tech_medecine`)

**[te_md_1]** (QCM) — Qui a découvert la pénicilline en 1928, ouvrant la voie aux antibiotiques modernes ?
- Choix : Alexander Fleming / Louis Pasteur / Robert Koch / Marie Curie
- Réponse : **Alexander Fleming**
- Explication : Fleming remarque par hasard qu'une moisissure tuait des bactéries dans une de ses boîtes de culture oubliées, une découverte accidentelle ayant sauvé des millions de vies.

**[te_md_2]** (QCM) — Quelle technique d'imagerie médicale utilise des champs magnétiques puissants plutôt que des rayons X pour observer l'intérieur du corps ?
- Choix : L'IRM / Le scanner / La radiographie / L'échographie
- Réponse : **L'IRM**
- Explication : L'IRM permet d'obtenir des images très détaillées des tissus mous, comme le cerveau ou les muscles, sans exposer le patient aux rayonnements ionisants utilisés en radiographie.

**[te_md_3]** (Vrai ou Faux) — Louis Pasteur a mis au point le premier vaccin contre la rage.
- Réponse : **Vrai**
- Explication : En 1885, Pasteur teste avec succès son vaccin contre la rage sur un jeune garçon mordu par un chien enragé, une avancée majeure de la microbiologie moderne.

**[te_md_4]** (Texte à trous) — Les rayons ___ ont été découverts en 1895 par le physicien allemand Wilhelm Röntgen et permettent aujourd'hui de radiographier les os.
- Choix : X / gamma / ultraviolets / infrarouges
- Réponse : **X**
- Explication : Röntgen appela ce rayonnement inconnu « rayons X » en référence à l'inconnue mathématique. Sa découverte lui vaut le tout premier prix Nobel de physique, décerné en 1901.

**[te_md_5]** (Anagramme) — Préparation contenant une forme affaiblie ou inactive d'un agent infectieux, utilisée pour immuniser contre une maladie
- Réponse : **VACCIN**
- Explication : Le mot vient du latin « vacca » (vache), en référence aux travaux d'Edward Jenner qui utilisa la vaccine, une maladie bovine proche de la variole, pour immuniser les humains dès 1796.
