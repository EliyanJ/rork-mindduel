# Minduel — Bibliothèque de données Quiz

Export complet du contenu quiz actuel de l'application, à utiliser comme base pour générer de nouvelles questions avec ton IA data. Ce document réunit : le contenu principal du jeu (catalogue), les questions du mini-quiz d'onboarding, le modèle des tranches de temps d'écran, et le schéma exact à respecter pour toute nouvelle question.

Généré le 2026-07-11. Source : `ios/Cortex/Resources/content.json` (contenu principal) + `ios/Cortex/Models/MiniQuizContent.swift` (mini-quiz onboarding) + `ios/Cortex/Models/OnboardingModels.swift` (temps d'écran).

---

## 1. Vue d'ensemble du catalogue principal

- **7 disciplines**
- **27 chapitres** (thèmes)
- **135 questions** au total (5 par chapitre)
- Répartition par type de question :
  - QCM (`multipleChoice`) : 54
  - Vrai ou Faux (`trueFalse`) : 27
  - Texte à trous (`fillBlank`) : 27
  - Anagramme (`anagram`) : 27

| Discipline | id | Icône (SF Symbol) | Couleur | Chapitres | Questions |
|---|---|---|---|---|---|
| Histoire | `histoire` | `building.columns.fill` | `#E8590C` | 5 | 25 |
| Sciences | `sciences` | `atom` | `#7048E8` | 5 | 25 |
| Géographie | `geographie` | `globe.europe.africa.fill` | `#1C7ED6` | 5 | 25 |
| Littérature | `litterature` | `book.fill` | `#0CA678` | 3 | 15 |
| Arts & Musique | `arts` | `paintpalette.fill` | `#E64980` | 3 | 15 |
| Nature & Animaux | `nature` | `leaf.fill` | `#2F9E44` | 3 | 15 |
| Tech & Espace | `technologie` | `lightbulb.fill` | `#F59F00` | 3 | 15 |

---

## 2. Schéma d'une question (à respecter pour toute génération)

Chaque question suit exactement cette forme JSON (voir `ContentModels.swift` côté app) :

```json
{
  "id": "identifiant_unique_snake_case",
  "type": "multipleChoice | trueFalse | fillBlank | anagram",
  "prompt": "Énoncé de la question",
  "options": [
    "Liste de choix (QCM et fillBlank uniquement, null sinon)"
  ],
  "answer": "Réponse exacte, doit correspondre à une valeur de options si présentes",
  "explanation": "1 à 3 phrases donnant un fait complémentaire intéressant, ton pédagogique et précis"
}
```

Règles à respecter :
- `id` : unique dans tout le catalogue, format `xx_yy_n` (ex. `hi_an_1` = histoire / antiquité / question 1).
- `type = multipleChoice` : 4 options dans `options`, `answer` = une des 4.
- `type = trueFalse` : pas de champ `options` (ou omis), `answer` = `"Vrai"` ou `"Faux"`.
- `type = fillBlank` : le `prompt` contient `___` à la place du mot manquant, `options` propose 4 mots plausibles, `answer` = le bon mot.
- `type = anagram` : pas d'`options`, `prompt` est un indice/définition, `answer` = le mot à trouver (en MAJUSCULES).
- `explanation` : toujours renseignée, factuelle, jamais une invention statistique — même esprit que le reste de l'app (honnêteté des données).
- Chaque **chapitre** contient exactement 5 questions aujourd'hui (peut être étendu).
- Un nouveau **chapitre** = `{ id, title, questions: [...] }` ajouté au tableau `chapters` d'une discipline existante.
- Une nouvelle **discipline** = `{ id, name, icon, colorHex, chapters: [...] }` ajoutée au tableau racine `disciplines`. L'icône doit être un nom SF Symbols valide (iOS), la couleur un hex `#RRGGBB`.

---

## 3. Catalogue complet — toutes les questions actuelles

Cette section liste l'intégralité des 135 questions en place aujourd'hui dans l'app, organisées par discipline puis par chapitre. Utile pour : éviter les doublons quand tu génères du nouveau contenu, et comme référence de ton/niveau de difficulté à reproduire.

### Histoire (`histoire`)

#### L'Antiquité (`histoire_antiquite`)

**[hi_an_1]** (QCM) — Quelle civilisation a construit les pyramides de Gizeh ?
- Choix : Les Égyptiens / Les Romains / Les Grecs / Les Perses
- Réponse : **Les Égyptiens**
- Explication : Les pyramides de Gizeh ont été construites vers 2560 av. J.-C. sous le pharaon Khéops. La grande pyramide est restée le plus haut monument du monde pendant plus de 3 800 ans.

**[hi_an_2]** (QCM) — En quelle année Jules César a-t-il été assassiné ?
- Choix : 44 av. J.-C. / 27 av. J.-C. / 100 av. J.-C. / 14 ap. J.-C.
- Réponse : **44 av. J.-C.**
- Explication : César fut poignardé aux ides de mars (15 mars) 44 av. J.-C. par un groupe de sénateurs, dont Brutus. Sa mort précipita la fin de la République romaine et l'avènement de l'Empire.

**[hi_an_3]** (Vrai ou Faux) — La démocratie est née à Athènes au Ve siècle av. J.-C.
- Réponse : **Vrai**
- Explication : Les réformes de Clisthène en 508 av. J.-C. ont posé les bases de la démocratie athénienne : les citoyens votaient directement les lois à l'Ecclésia. Attention : femmes, esclaves et étrangers en étaient exclus.

**[hi_an_4]** (Texte à trous) — Le ___ est le fleuve qui a permis le développement de la civilisation égyptienne.
- Choix : Nil / Tigre / Euphrate / Gange
- Réponse : **Nil**
- Explication : Les crues annuelles du Nil déposaient un limon fertile sur ses rives, permettant l'agriculture en plein désert. Hérodote disait que « l'Égypte est un don du Nil ».

**[hi_an_5]** (Anagramme) — Ville fondée en 753 av. J.-C. selon la légende de Romulus et Rémus
- Réponse : **ROME**
- Explication : Selon la légende, Romulus tua son frère Rémus et fonda Rome sur le mont Palatin en 753 av. J.-C. La ville devint le cœur d'un empire qui domina toute la Méditerranée.

#### Le Moyen Âge (`histoire_moyen_age`)

**[hi_ma_1]** (QCM) — Qui a été couronné empereur d'Occident en l'an 800 ?
- Choix : Charlemagne / Clovis / Hugues Capet / Saint Louis
- Réponse : **Charlemagne**
- Explication : Charlemagne fut couronné empereur par le pape Léon III à Rome le 25 décembre 800. Son empire couvrait une grande partie de l'Europe occidentale, restaurant l'idée impériale disparue depuis Rome.

**[hi_ma_2]** (QCM) — En quelle année a eu lieu la bataille d'Hastings ?
- Choix : 1066 / 1214 / 987 / 1337
- Réponse : **1066**
- Explication : En 1066, Guillaume le Conquérant, duc de Normandie, vainquit le roi anglo-saxon Harold à Hastings et devint roi d'Angleterre. Cet événement lia durablement les histoires française et anglaise.

**[hi_ma_3]** (Vrai ou Faux) — La peste noire a tué près d'un tiers de la population européenne au XIVe siècle.
- Réponse : **Vrai**
- Explication : Entre 1347 et 1352, la peste noire a tué entre 25 et 45 millions de personnes en Europe, soit environ un tiers de la population. Elle est arrivée par des navires marchands venus de mer Noire.

**[hi_ma_4]** (Texte à trous) — Jeanne d'Arc a délivré la ville d'___ en 1429.
- Choix : Orléans / Reims / Paris / Rouen
- Réponse : **Orléans**
- Explication : La levée du siège d'Orléans en mai 1429 fut le tournant de la guerre de Cent Ans. Jeanne d'Arc conduisit ensuite Charles VII à Reims pour son sacre, avant d'être capturée puis brûlée à Rouen en 1431.

**[hi_ma_5]** (Anagramme) — Tour principale d'un château fort, dernier refuge en cas d'attaque
- Réponse : **DONJON**
- Explication : Le donjon était la tour maîtresse du château fort : à la fois résidence du seigneur et ultime refuge en cas de siège. Ses murs pouvaient dépasser 4 mètres d'épaisseur.

#### La Révolution française (`histoire_revolution`)

**[hi_re_1]** (QCM) — Quel événement du 14 juillet 1789 marque le début de la Révolution française ?
- Choix : La prise de la Bastille / Le serment du Jeu de paume / La fuite à Varennes / Le sacre de Napoléon
- Réponse : **La prise de la Bastille**
- Explication : Le 14 juillet 1789, les Parisiens prirent d'assaut la Bastille, prison symbole de l'arbitraire royal. L'événement ne libéra que 7 prisonniers, mais son impact symbolique fut immense.

**[hi_re_2]** (QCM) — Quel roi de France a été guillotiné en janvier 1793 ?
- Choix : Louis XVI / Louis XIV / Louis XV / Charles X
- Réponse : **Louis XVI**
- Explication : Louis XVI fut guillotiné le 21 janvier 1793 sur la place de la Révolution (actuelle place de la Concorde), après avoir été jugé pour trahison par la Convention. Marie-Antoinette le suivit en octobre.

**[hi_re_3]** (Vrai ou Faux) — La Déclaration des droits de l'homme et du citoyen a été adoptée en août 1789.
- Réponse : **Vrai**
- Explication : Adoptée le 26 août 1789, la Déclaration proclame que « les hommes naissent et demeurent libres et égaux en droits ». Elle reste aujourd'hui au sommet du droit français.

**[hi_re_4]** (Texte à trous) — La devise de la République française est « Liberté, Égalité, ___ ».
- Choix : Fraternité / Solidarité / Justice / Unité
- Réponse : **Fraternité**
- Explication : La devise « Liberté, Égalité, Fraternité » apparaît pendant la Révolution, mais ne devient officielle que sous la IIe République en 1848. Elle figure dans la Constitution de 1958.

**[hi_re_5]** (Anagramme) — Instrument d'exécution devenu le symbole de la Terreur
- Réponse : **GUILLOTINE**
- Explication : Adoptée en 1792 sur proposition du docteur Guillotin pour rendre les exécutions égalitaires et rapides, la guillotine fit environ 17 000 victimes pendant la Terreur (1793-1794).

#### Les Grandes Découvertes (`histoire_decouvertes`)

**[hi_gd_1]** (QCM) — Quel navigateur a atteint l'Amérique en 1492 ?
- Choix : Christophe Colomb / Fernand de Magellan / Vasco de Gama / Marco Polo
- Réponse : **Christophe Colomb**
- Explication : Parti d'Espagne avec trois caravelles, Colomb toucha terre aux Bahamas le 12 octobre 1492. Il mourut en 1506 convaincu d'avoir atteint les Indes, sans savoir qu'il avait ouvert un nouveau continent aux Européens.

**[hi_gd_2]** (QCM) — Qui a ouvert la route maritime des Indes en contournant l'Afrique en 1498 ?
- Choix : Vasco de Gama / Jacques Cartier / Amerigo Vespucci / Bartolomeu Dias
- Réponse : **Vasco de Gama**
- Explication : Le Portugais Vasco de Gama doubla le cap de Bonne-Espérance et atteignit Calicut en Inde en 1498. Cette route brisa le monopole des marchands arabes et vénitiens sur les épices.

**[hi_gd_3]** (Vrai ou Faux) — L'expédition de Magellan a réalisé le premier tour du monde.
- Réponse : **Vrai**
- Explication : Partie en 1519 avec 237 hommes, l'expédition boucla le tour du monde en 1522… avec seulement 18 survivants. Magellan lui-même fut tué aux Philippines : c'est Elcano qui ramena le dernier navire.

**[hi_gd_4]** (Texte à trous) — L'imprimerie à caractères mobiles a été mise au point vers 1450 par Johannes ___.
- Choix : Gutenberg / Copernic / Kepler / Érasme
- Réponse : **Gutenberg**
- Explication : L'imprimerie de Gutenberg permit de produire des livres 100 fois plus vite que les copistes. Sa Bible de 1455 lança une révolution : en 50 ans, plus de livres furent imprimés qu'en mille ans de copie manuscrite.

**[hi_gd_5]** (Anagramme) — Navire léger et rapide utilisé par les explorateurs portugais et espagnols
- Réponse : **CARAVELLE**
- Explication : Inventée par les Portugais au XVe siècle, la caravelle pouvait remonter le vent grâce à ses voiles triangulaires. La Niña et la Pinta de Colomb étaient des caravelles.

#### Les Guerres mondiales (`histoire_guerres_mondiales`)

**[hi_gm_1]** (QCM) — Quel événement a déclenché la Première Guerre mondiale en 1914 ?
- Choix : L'assassinat de l'archiduc François-Ferdinand / L'invasion de la Pologne / Le naufrage du Titanic / La révolution russe
- Réponse : **L'assassinat de l'archiduc François-Ferdinand**
- Explication : Le 28 juin 1914 à Sarajevo, l'héritier du trône d'Autriche-Hongrie fut assassiné par un nationaliste serbe. Le jeu des alliances transforma cette crise locale en guerre mondiale en cinq semaines.

**[hi_gm_2]** (QCM) — En quelle année a eu lieu le débarquement de Normandie ?
- Choix : 1944 / 1942 / 1945 / 1940
- Réponse : **1944**
- Explication : Le 6 juin 1944, près de 156 000 soldats alliés débarquèrent sur cinq plages normandes lors de l'opération Overlord, la plus grande opération amphibie de l'histoire. Paris fut libéré le 25 août suivant.

**[hi_gm_3]** (Vrai ou Faux) — L'armistice de la Première Guerre mondiale a été signé le 11 novembre 1918.
- Réponse : **Vrai**
- Explication : L'armistice fut signé à 5 h 15 dans un wagon en forêt de Compiègne, et les combats cessèrent à 11 h. En 1940, Hitler exigea que la France signe sa capitulation dans ce même wagon.

**[hi_gm_4]** (Texte à trous) — La bataille de ___ (1916) a duré 300 jours et symbolise la guerre des tranchées.
- Choix : Verdun / la Somme / la Marne / Ypres
- Réponse : **Verdun**
- Explication : De février à décembre 1916, Verdun fit plus de 700 000 victimes pour un front qui bougea à peine. Environ 60 millions d'obus y furent tirés — le sol en garde encore les cicatrices aujourd'hui.

**[hi_gm_5]** (Anagramme) — Ligne de fortifications françaises construite dans les années 1930
- Réponse : **MAGINOT**
- Explication : La ligne Maginot était une prouesse technique jugée infranchissable… mais en 1940, l'armée allemande la contourna simplement par les Ardennes et la Belgique.


### Sciences (`sciences`)

#### Le Système solaire (`sciences_systeme_solaire`)

**[sc_ss_1]** (QCM) — Quelle est la planète la plus proche du Soleil ?
- Choix : Mercure / Vénus / Mars / La Terre
- Réponse : **Mercure**
- Explication : Mercure orbite à seulement 58 millions de km du Soleil. Sa température varie de +430 °C le jour à −180 °C la nuit, car elle n'a presque pas d'atmosphère pour retenir la chaleur.

**[sc_ss_2]** (QCM) — Combien de temps met la lumière du Soleil pour atteindre la Terre ?
- Choix : Environ 8 minutes / Environ 8 secondes / Environ 8 heures / Environ 1 seconde
- Réponse : **Environ 8 minutes**
- Explication : La lumière parcourt 300 000 km par seconde. Comme le Soleil est à 150 millions de km, sa lumière met 8 minutes et 20 secondes à nous parvenir : nous voyons donc le Soleil « du passé ».

**[sc_ss_3]** (Vrai ou Faux) — Jupiter est la plus grande planète du Système solaire.
- Réponse : **Vrai**
- Explication : Jupiter est si grande que toutes les autres planètes réunies tiendraient à l'intérieur. Sa Grande Tache rouge est une tempête plus large que la Terre, active depuis au moins 350 ans.

**[sc_ss_4]** (Texte à trous) — ___ est surnommée « la planète rouge » à cause de l'oxyde de fer qui couvre son sol.
- Choix : Mars / Vénus / Saturne / Neptune
- Réponse : **Mars**
- Explication : La couleur rouille de Mars vient de l'oxyde de fer (la rouille) présent dans son sol. Mars abrite aussi le plus grand volcan du Système solaire : Olympus Mons, presque 3 fois plus haut que l'Everest.

**[sc_ss_5]** (Anagramme) — Astre autour duquel gravitent les huit planètes
- Réponse : **SOLEIL**
- Explication : Le Soleil concentre 99,86 % de la masse du Système solaire. C'est une étoile de taille moyenne qui fusionne 600 millions de tonnes d'hydrogène chaque seconde depuis 4,6 milliards d'années.

#### Le Corps humain (`sciences_corps_humain`)

**[sc_ch_1]** (QCM) — Combien d'os compte le squelette humain adulte ?
- Choix : 206 / 156 / 306 / 412
- Réponse : **206**
- Explication : Un adulte possède 206 os, mais un bébé en a environ 300 ! Certains os fusionnent en grandissant. Plus de la moitié de nos os se trouvent dans les mains et les pieds.

**[sc_ch_2]** (QCM) — Quel organe pompe le sang dans tout le corps ?
- Choix : Le cœur / Le foie / Les poumons / Les reins
- Réponse : **Le cœur**
- Explication : Le cœur bat environ 100 000 fois par jour et pompe près de 8 000 litres de sang quotidiennement. Sur une vie entière, cela représente plus de 3 milliards de battements.

**[sc_ch_3]** (Vrai ou Faux) — Les globules rouges transportent l'oxygène grâce à l'hémoglobine.
- Réponse : **Vrai**
- Explication : L'hémoglobine est une protéine riche en fer qui capte l'oxygène dans les poumons et le libère dans les tissus. Chaque goutte de sang contient environ 5 millions de globules rouges.

**[sc_ch_4]** (Texte à trous) — Le ___ est l'organe principal du système nerveux : il contient environ 86 milliards de neurones.
- Choix : cerveau / cœur / foie / poumon
- Réponse : **cerveau**
- Explication : Le cerveau ne pèse que 2 % du poids du corps mais consomme 20 % de son énergie. Chaque neurone peut se connecter à 10 000 autres, formant un réseau de plusieurs centaines de billions de connexions.

**[sc_ch_5]** (Anagramme) — Organe de la respiration qui capte l'oxygène de l'air
- Réponse : **POUMON**
- Explication : Nos deux poumons contiennent environ 300 millions d'alvéoles. Dépliée, leur surface d'échange couvrirait un terrain de tennis, soit près de 70 m² pour capter l'oxygène.

#### L'Atome (`sciences_atome`)

**[sc_at_1]** (QCM) — Quelles particules composent le noyau d'un atome ?
- Choix : Protons et neutrons / Protons et électrons / Électrons et photons / Neutrons et photons
- Réponse : **Protons et neutrons**
- Explication : Le noyau concentre protons (charge positive) et neutrons (neutres). Il est 10 000 fois plus petit que l'atome : si l'atome était un stade, le noyau serait une bille au centre.

**[sc_at_2]** (QCM) — Quel est le symbole chimique de l'or ?
- Choix : Au / Or / Ag / Go
- Réponse : **Au**
- Explication : Au vient du latin « aurum » (aube dorée). De même, l'argent est Ag (argentum) et le fer Fe (ferrum) : beaucoup de symboles chimiques viennent des noms latins des éléments.

**[sc_at_3]** (Vrai ou Faux) — Un atome est électriquement neutre : il possède autant de protons que d'électrons.
- Réponse : **Vrai**
- Explication : Les charges positives des protons compensent exactement les charges négatives des électrons. Si un atome gagne ou perd des électrons, il devient un ion, chargé électriquement.

**[sc_at_4]** (Texte à trous) — Les ___ gravitent autour du noyau de l'atome et portent une charge négative.
- Choix : électrons / protons / neutrons / photons
- Réponse : **électrons**
- Explication : Les électrons sont 1 836 fois plus légers qu'un proton. Leur organisation en couches autour du noyau détermine toutes les propriétés chimiques d'un élément.

**[sc_at_5]** (Anagramme) — Particule élémentaire de charge négative découverte en 1897
- Réponse : **ELECTRON**
- Explication : L'électron fut découvert par J.J. Thomson en 1897. C'est la première particule subatomique identifiée, prouvant que l'atome — dont le nom signifie « insécable » — était en fait divisible.

#### L'Énergie et l'électricité (`sciences_energie`)

**[sc_en_1]** (QCM) — Quelle est l'unité de la tension électrique ?
- Choix : Le volt / L'ampère / Le watt / L'ohm
- Réponse : **Le volt**
- Explication : Le volt doit son nom à Alessandro Volta, inventeur de la première pile électrique en 1800. L'ampère mesure l'intensité du courant, le watt la puissance et l'ohm la résistance.

**[sc_en_2]** (QCM) — Laquelle de ces sources d'énergie est renouvelable ?
- Choix : L'énergie solaire / Le charbon / Le pétrole / Le gaz naturel
- Réponse : **L'énergie solaire**
- Explication : Le Soleil envoie sur Terre en une heure plus d'énergie que l'humanité n'en consomme en un an. Charbon, pétrole et gaz sont des énergies fossiles : elles ont mis des millions d'années à se former.

**[sc_en_3]** (Vrai ou Faux) — Un éclair peut être cinq fois plus chaud que la surface du Soleil.
- Réponse : **Vrai**
- Explication : L'air traversé par la foudre atteint près de 30 000 °C, contre 5 500 °C à la surface du Soleil. C'est cette dilatation brutale de l'air qui produit le tonnerre.

**[sc_en_4]** (Texte à trous) — L'unité de puissance est le ___, du nom d'un ingénieur écossais.
- Choix : watt / volt / joule / newton
- Réponse : **watt**
- Explication : James Watt perfectionna la machine à vapeur au XVIIIe siècle et lança la révolution industrielle. Une ampoule LED consomme environ 10 watts, un four électrique 2 000.

**[sc_en_5]** (Anagramme) — Machine tournante entraînée par l'eau ou la vapeur dans les centrales électriques
- Réponse : **TURBINE**
- Explication : Qu'elle soit hydraulique, nucléaire ou à charbon, presque toute centrale électrique fonctionne pareil : une turbine tourne et entraîne un alternateur qui produit le courant.

#### La Planète Terre (`sciences_terre`)

**[sc_te_1]** (QCM) — Quelle couche de l'atmosphère nous protège des rayons ultraviolets ?
- Choix : La couche d'ozone / La troposphère / La ionosphère / La magnétosphère
- Réponse : **La couche d'ozone**
- Explication : Située entre 20 et 40 km d'altitude, la couche d'ozone filtre la majorité des UV dangereux. Menacée par les gaz CFC, elle se reconstitue depuis leur interdiction en 1987 — un succès écologique mondial.

**[sc_te_2]** (QCM) — Quelle part de la surface terrestre est couverte par les océans ?
- Choix : Environ 71 % / Environ 50 % / Environ 85 % / Environ 35 %
- Réponse : **Environ 71 %**
- Explication : Les océans couvrent 71 % de la planète, d'où son surnom de « planète bleue ». Pourtant, plus de 80 % des fonds marins restent inexplorés : on connaît mieux la surface de Mars.

**[sc_te_3]** (Vrai ou Faux) — Le centre de la Terre est aussi chaud que la surface du Soleil.
- Réponse : **Vrai**
- Explication : Le noyau interne de la Terre atteint environ 5 500 °C, comparable à la surface du Soleil. C'est une boule de fer solide malgré la chaleur, car la pression y est 3,5 millions de fois celle de l'atmosphère.

**[sc_te_4]** (Texte à trous) — La magnitude des séismes se mesure sur l'échelle de ___.
- Choix : Richter / Beaufort / Mercalli / Celsius
- Réponse : **Richter**
- Explication : L'échelle de Richter est logarithmique : un séisme de magnitude 7 libère 32 fois plus d'énergie qu'un séisme de magnitude 6. Le plus puissant jamais mesuré : 9,5 au Chili en 1960.

**[sc_te_5]** (Anagramme) — Montagne qui peut cracher lave, cendres et gaz brûlants
- Réponse : **VOLCAN**
- Explication : On compte environ 1 500 volcans actifs sur Terre, dont 80 % le long de la « ceinture de feu » du Pacifique. L'éruption du Vésuve en 79 ap. J.-C. a figé la ville de Pompéi pour l'éternité.


### Géographie (`geographie`)

#### Capitales du monde (`geo_capitales`)

**[ge_ca_1]** (QCM) — Quelle est la capitale de l'Australie ?
- Choix : Canberra / Sydney / Melbourne / Perth
- Réponse : **Canberra**
- Explication : Contrairement à une idée reçue, ce n'est ni Sydney ni Melbourne. Canberra fut construite sur mesure en 1913, à mi-chemin entre les deux villes rivales, pour trancher leur dispute.

**[ge_ca_2]** (QCM) — Quelle est la capitale du Canada ?
- Choix : Ottawa / Toronto / Montréal / Vancouver
- Réponse : **Ottawa**
- Explication : La reine Victoria choisit Ottawa en 1857 : la ville était à la frontière entre le Canada anglophone et francophone, et assez éloignée des États-Unis pour être protégée d'une invasion.

**[ge_ca_3]** (Vrai ou Faux) — Istanbul est la capitale de la Turquie.
- Réponse : **Faux**
- Explication : C'est Ankara, choisie par Atatürk en 1923 pour sa position centrale en Anatolie. Istanbul reste néanmoins la plus grande ville du pays et la seule métropole au monde à cheval sur deux continents.

**[ge_ca_4]** (Texte à trous) — La capitale du Japon est ___, la plus grande agglomération du monde.
- Choix : Tokyo / Kyoto / Osaka / Séoul
- Réponse : **Tokyo**
- Explication : L'agglomération de Tokyo compte environ 37 millions d'habitants. Fait notable : Kyoto fut la capitale impériale pendant plus de 1 000 ans, avant que l'empereur ne s'installe à Tokyo en 1868.

**[ge_ca_5]** (Anagramme) — Capitale de l'Espagne, ville la plus haute d'Europe occidentale
- Réponse : **MADRID**
- Explication : Perchée à 667 mètres d'altitude sur le plateau castillan, Madrid est la capitale la plus élevée d'Europe occidentale. Elle devint capitale en 1561 sous Philippe II, pour sa position centrale.

#### Fleuves et montagnes (`geo_fleuves_montagnes`)

**[ge_fm_1]** (QCM) — Quel est le plus long fleuve du monde ?
- Choix : L'Amazone / Le Nil / Le Mississippi / Le Yangzi
- Réponse : **L'Amazone**
- Explication : Le débat Amazone-Nil a duré des décennies. Des expéditions récentes créditent l'Amazone d'environ 7 000 km. Il déverse à lui seul 20 % de toute l'eau douce qui arrive dans les océans.

**[ge_fm_2]** (QCM) — Sur quel continent se trouve la cordillère des Andes ?
- Choix : L'Amérique du Sud / L'Asie / L'Afrique / L'Océanie
- Réponse : **L'Amérique du Sud**
- Explication : Longue de 7 000 km, la cordillère des Andes est la plus longue chaîne de montagnes continentale du monde. Elle traverse 7 pays, de la Colombie à la Patagonie.

**[ge_fm_3]** (Vrai ou Faux) — L'Everest culmine à plus de 8 800 mètres d'altitude.
- Réponse : **Vrai**
- Explication : L'Everest culmine à 8 849 mètres et grandit encore de quelques millimètres par an, poussé par la collision entre les plaques indienne et eurasienne qui a créé l'Himalaya.

**[ge_fm_4]** (Texte à trous) — La ___ est le fleuve qui traverse Paris.
- Choix : Seine / Loire / Garonne / Rhône
- Réponse : **Seine**
- Explication : Longue de 777 km, la Seine prend sa source en Bourgogne et se jette dans la Manche au Havre. Paris est née sur ses îles, dont l'île de la Cité, cœur historique de la ville.

**[ge_fm_5]** (Anagramme) — Plus haut sommet des Alpes : le mont ___
- Réponse : **BLANC**
- Explication : Le mont Blanc culmine à environ 4 806 mètres, une altitude qui varie de quelques mètres selon l'épaisseur de sa calotte de glace, mesurée tous les deux ans.

#### La France (`geo_france`)

**[ge_fr_1]** (QCM) — Combien de régions compte la France métropolitaine depuis 2016 ?
- Choix : 13 / 22 / 18 / 9
- Réponse : **13**
- Explication : La réforme territoriale de 2016 a fait passer la France métropolitaine de 22 à 13 régions, en fusionnant par exemple la Bourgogne et la Franche-Comté. Avec l'outre-mer, on compte 18 régions.

**[ge_fr_2]** (QCM) — Quel est le plus long fleuve entièrement français ?
- Choix : La Loire / La Seine / Le Rhône / La Garonne
- Réponse : **La Loire**
- Explication : Avec 1 006 km, la Loire est le plus long fleuve de France. Le Rhône est plus puissant mais prend sa source en Suisse. La Loire est aussi réputée pour être le dernier fleuve « sauvage » d'Europe.

**[ge_fr_3]** (Vrai ou Faux) — La France métropolitaine partage une frontière terrestre avec huit pays.
- Réponse : **Vrai**
- Explication : Belgique, Luxembourg, Allemagne, Suisse, Italie, Monaco, Espagne et Andorre : huit voisins terrestres. Avec l'outre-mer, la France partage même une frontière avec le Brésil, sa plus longue !

**[ge_fr_4]** (Texte à trous) — Marseille, plus ancienne ville de France, est située au bord de la mer ___.
- Choix : Méditerranée / du Nord / Baltique / Noire
- Réponse : **Méditerranée**
- Explication : Marseille fut fondée vers 600 av. J.-C. par des marins grecs de Phocée, sous le nom de Massalia. C'est la plus ancienne ville de France et son plus grand port.

**[ge_fr_5]** (Anagramme) — Île française de Méditerranée surnommée « l'île de Beauté »
- Réponse : **CORSE**
- Explication : La Corse est la quatrième plus grande île de Méditerranée. Montagneuse et sauvage, elle a vu naître Napoléon Bonaparte à Ajaccio en 1769, un an après son rattachement à la France.

#### Océans et continents (`geo_oceans_continents`)

**[ge_oc_1]** (QCM) — Quel est le plus grand océan du monde ?
- Choix : Le Pacifique / L'Atlantique / L'océan Indien / L'océan Arctique
- Réponse : **Le Pacifique**
- Explication : Le Pacifique est plus vaste que toutes les terres émergées réunies. Il abrite aussi le point le plus profond du globe : la fosse des Mariannes, à près de 11 000 mètres sous la surface.

**[ge_oc_2]** (QCM) — Quel est le plus grand désert chaud du monde ?
- Choix : Le Sahara / Le Gobi / L'Atacama / Le Kalahari
- Réponse : **Le Sahara**
- Explication : Avec plus de 9 millions de km², le Sahara est presque aussi grand que les États-Unis. Il y a 10 000 ans, c'était une savane verte parcourue de rivières, comme le montrent les peintures rupestres du Tassili.

**[ge_oc_3]** (Vrai ou Faux) — L'Afrique est le continent le plus peuplé du monde.
- Réponse : **Faux**
- Explication : C'est l'Asie, avec près de 60 % de la population mondiale. L'Afrique arrive deuxième, mais c'est le continent dont la population croît le plus vite : elle pourrait doubler d'ici 2050.

**[ge_oc_4]** (Texte à trous) — Le canal de ___ relie la mer Méditerranée à la mer Rouge.
- Choix : Suez / Panama / Corinthe / Kiel
- Réponse : **Suez**
- Explication : Inauguré en 1869, le canal de Suez fait gagner environ 8 000 km aux navires entre l'Europe et l'Asie. Près de 12 % du commerce mondial y transite chaque année.

**[ge_oc_5]** (Anagramme) — Couche de glace de mer qui entoure le pôle Nord
- Réponse : **BANQUISE**
- Explication : Contrairement aux glaciers, la banquise est de l'eau de mer gelée : sa fonte ne fait donc pas monter le niveau des océans. Elle a perdu environ 40 % de sa surface d'été depuis 1980.

#### L'Europe (`geo_europe`)

**[ge_eu_1]** (QCM) — Quel est le plus petit pays du monde ?
- Choix : Le Vatican / Monaco / Saint-Marin / Le Liechtenstein
- Réponse : **Le Vatican**
- Explication : Avec 0,44 km², le Vatican tiendrait 8 fois dans Central Park. C'est un État souverain depuis 1929, avec sa propre monnaie, sa poste et même une équipe de football.

**[ge_eu_2]** (QCM) — Quel fleuve européen traverse le plus de pays ?
- Choix : Le Danube / Le Rhin / La Volga / L'Elbe
- Réponse : **Le Danube**
- Explication : Le Danube traverse ou borde 10 pays, un record mondial, de l'Allemagne à la mer Noire. Il arrose quatre capitales : Vienne, Bratislava, Budapest et Belgrade.

**[ge_eu_3]** (Vrai ou Faux) — La Norvège fait partie de l'Union européenne.
- Réponse : **Faux**
- Explication : Les Norvégiens ont refusé l'adhésion par référendum à deux reprises, en 1972 et 1994. Le pays participe néanmoins au marché unique via l'Espace économique européen.

**[ge_eu_4]** (Texte à trous) — L'___ est le pays le plus peuplé de l'Union européenne.
- Choix : Allemagne / Italie / Espagne / Pologne
- Réponse : **Allemagne**
- Explication : Avec environ 84 millions d'habitants, l'Allemagne devance la France (68 millions) et l'Italie (59 millions). Avant le Brexit, le Royaume-Uni occupait la troisième place.

**[ge_eu_5]** (Anagramme) — Chaîne de montagnes qui sépare la France de l'Espagne
- Réponse : **PYRENEES**
- Explication : Longues de 430 km de l'Atlantique à la Méditerranée, les Pyrénées culminent au pic d'Aneto (3 404 m). Elles abritent un micro-État : l'Andorre.


### Littérature (`litterature`)

#### Écrivains français (`litt_ecrivains`)

**[li_ec_1]** (QCM) — Qui a écrit « Les Misérables » ?
- Choix : Victor Hugo / Émile Zola / Honoré de Balzac / Gustave Flaubert
- Réponse : **Victor Hugo**
- Explication : Hugo publia « Les Misérables » en 1862 depuis son exil à Guernesey. Pour connaître le succès du livre, il envoya à son éditeur le télégramme le plus court de l'histoire : « ? ». Réponse : « ! ».

**[li_ec_2]** (QCM) — Quel écrivain a imaginé le sous-marin Nautilus dans « Vingt Mille Lieues sous les mers » ?
- Choix : Jules Verne / Alexandre Dumas / Guy de Maupassant / Théophile Gautier
- Réponse : **Jules Verne**
- Explication : Publié en 1870, le roman anticipait le sous-marin électrique des décennies avant son invention. Jules Verne est l'un des auteurs les plus traduits au monde, juste derrière Agatha Christie.

**[li_ec_3]** (Vrai ou Faux) — Molière est le nom de scène de Jean-Baptiste Poquelin.
- Réponse : **Vrai**
- Explication : Poquelin prit le pseudonyme de Molière vers 1644, peut-être pour épargner sa famille bourgeoise de la honte du théâtre. Il mourut en 1673 quelques heures après avoir joué… « Le Malade imaginaire ».

**[li_ec_4]** (Texte à trous) — « Le Petit Prince » a été écrit par Antoine de ___.
- Choix : Saint-Exupéry / Musset / Chateaubriand / Lamartine
- Réponse : **Saint-Exupéry**
- Explication : Écrit à New York en 1943, « Le Petit Prince » est traduit en plus de 500 langues, un record mondial. Pilote de guerre, Saint-Exupéry disparut en mer en 1944 lors d'une mission de reconnaissance.

**[li_ec_5]** (Anagramme) — Philosophe des Lumières, auteur de « Candide »
- Réponse : **VOLTAIRE**
- Explication : Voltaire, de son vrai nom François-Marie Arouet, fut embastillé deux fois pour ses écrits. « Candide » (1759), conte féroce contre l'optimisme naïf, se conclut par « il faut cultiver notre jardin ».

#### Romans et héros célèbres (`litt_heros`)

**[li_he_1]** (QCM) — Quel détective habite au 221B Baker Street à Londres ?
- Choix : Sherlock Holmes / Hercule Poirot / Arsène Lupin / Rouletabille
- Réponse : **Sherlock Holmes**
- Explication : Créé par Conan Doyle en 1887, Holmes fut si populaire que sa « mort » en 1893 provoqua un tollé : des lecteurs portèrent le deuil, et Doyle dut le ressusciter dix ans plus tard.

**[li_he_2]** (QCM) — Comment s'appelle le jeune héros gascon des « Trois Mousquetaires » ?
- Choix : D'Artagnan / Athos / Porthos / Aramis
- Réponse : **D'Artagnan**
- Explication : Le roman d'Alexandre Dumas (1844) s'inspire d'un vrai mousquetaire, Charles de Batz de Castelmore, mort au siège de Maastricht en 1673. La devise « Un pour tous, tous pour un » est restée légendaire.

**[li_he_3]** (Vrai ou Faux) — Le premier tome de « Harry Potter » a été refusé par de nombreux éditeurs.
- Réponse : **Vrai**
- Explication : Une douzaine d'éditeurs refusèrent le manuscrit de J.K. Rowling avant que Bloomsbury ne l'accepte en 1997 — sur les conseils de la fille de 8 ans du directeur. La saga s'est vendue à plus de 500 millions d'exemplaires.

**[li_he_4]** (Texte à trous) — Le capitaine ___ commande le sous-marin Nautilus chez Jules Verne.
- Choix : Nemo / Achab / Crochet / Haddock
- Réponse : **Nemo**
- Explication : « Nemo » signifie « personne » en latin — un nom choisi par ce prince déchu qui a renoncé au monde des hommes. Achab poursuit Moby Dick, Crochet affronte Peter Pan et Haddock accompagne Tintin.

**[li_he_5]** (Anagramme) — Gamin des rues de Paris dans « Les Misérables », symbole de l'enfant frondeur
- Réponse : **GAVROCHE**
- Explication : Gavroche meurt sur les barricades de l'insurrection de 1832 en chantant. Son nom est entré dans la langue française : un « gavroche » désigne un gamin de Paris malicieux et courageux.

#### Poésie et théâtre (`litt_poesie_theatre`)

**[li_pt_1]** (QCM) — Qui a écrit « Roméo et Juliette » ?
- Choix : William Shakespeare / Molière / Racine / Oscar Wilde
- Réponse : **William Shakespeare**
- Explication : Écrite vers 1595, la tragédie des amants de Vérone est la pièce la plus jouée au monde. Shakespeare a inventé ou popularisé plus de 1 700 mots de la langue anglaise.

**[li_pt_2]** (QCM) — Quel poète a publié « Les Fleurs du mal » en 1857 ?
- Choix : Charles Baudelaire / Arthur Rimbaud / Paul Verlaine / Victor Hugo
- Réponse : **Charles Baudelaire**
- Explication : Dès sa parution, le recueil valut à Baudelaire un procès pour « outrage à la morale publique » : six poèmes furent censurés. Il fallut attendre 1949 pour que la justice française le réhabilite.

**[li_pt_3]** (Vrai ou Faux) — Arthur Rimbaud a écrit toute son œuvre poétique avant l'âge de 21 ans.
- Réponse : **Vrai**
- Explication : Génie précoce, Rimbaud écrivit « Le Bateau ivre » à 17 ans puis abandonna définitivement la poésie vers 20 ans. Il devint ensuite négociant et explorateur en Afrique, où il mourut à 37 ans.

**[li_pt_4]** (Texte à trous) — Cyrano de ___ est célèbre pour son long nez et son panache.
- Choix : Bergerac / Gascogne / Montmartre / Provence
- Réponse : **Bergerac**
- Explication : La pièce d'Edmond Rostand (1897) fut un triomphe : 40 minutes d'applaudissements à la première. Le vrai Cyrano, écrivain du XVIIe siècle, avait bien un grand nez… et imagina un voyage vers la Lune.

**[li_pt_5]** (Anagramme) — Poème de 14 vers popularisé par Ronsard et Shakespeare
- Réponse : **SONNET**
- Explication : Né en Italie au XIIIe siècle et magnifié par Pétrarque, le sonnet compte deux quatrains et deux tercets dans sa forme française. Shakespeare en écrivit 154 dans sa version anglaise.


### Arts & Musique (`arts`)

#### La Peinture (`arts_peinture`)

**[ar_pe_1]** (QCM) — Qui a peint « La Joconde » ?
- Choix : Léonard de Vinci / Michel-Ange / Raphaël / Botticelli
- Réponse : **Léonard de Vinci**
- Explication : Peinte vers 1503, la Joconde doit une partie de sa célébrité à son vol en 1911 : un vitrier italien la garda deux ans sous son lit. Elle est aujourd'hui protégée par une vitre blindée au Louvre.

**[ar_pe_2]** (QCM) — Quel peintre s'est tranché une partie de l'oreille en 1888 ?
- Choix : Vincent van Gogh / Paul Gauguin / Claude Monet / Edgar Degas
- Réponse : **Vincent van Gogh**
- Explication : Van Gogh ne vendit qu'un seul tableau de son vivant. Un siècle plus tard, son « Portrait du docteur Gachet » s'est vendu 82,5 millions de dollars — alors record mondial.

**[ar_pe_3]** (Vrai ou Faux) — Pablo Picasso est l'un des fondateurs du cubisme.
- Réponse : **Vrai**
- Explication : Avec Georges Braque, Picasso lança le cubisme vers 1907 avec « Les Demoiselles d'Avignon ». Artiste prolifique, il a produit environ 50 000 œuvres en 78 ans de carrière.

**[ar_pe_4]** (Texte à trous) — Claude ___ est le chef de file de l'impressionnisme, célèbre pour ses Nymphéas.
- Choix : Monet / Manet / Renoir / Cézanne
- Réponse : **Monet**
- Explication : C'est son tableau « Impression, soleil levant » (1872) qui donna — par moquerie d'un critique — son nom au mouvement. Monet peignit ses Nymphéas dans son jardin de Giverny pendant 30 ans.

**[ar_pe_5]** (Anagramme) — Musée parisien qui abrite la Joconde
- Réponse : **LOUVRE**
- Explication : Ancien palais des rois de France, le Louvre est le musée le plus visité du monde avec près de 9 millions de visiteurs par an. Voir chaque œuvre 30 secondes prendrait plus de 100 jours.

#### La Musique (`arts_musique`)

**[ar_mu_1]** (QCM) — Combien de cordes possède un violon ?
- Choix : 4 / 6 / 5 / 8
- Réponse : **4**
- Explication : Les quatre cordes du violon sont accordées sol, ré, la, mi. Les violons les plus précieux, fabriqués par Stradivarius au XVIIIe siècle, se vendent plusieurs millions d'euros.

**[ar_mu_2]** (QCM) — Quel compositeur a continué à créer alors qu'il devenait sourd ?
- Choix : Ludwig van Beethoven / Wolfgang Amadeus Mozart / Jean-Sébastien Bach / Frédéric Chopin
- Réponse : **Ludwig van Beethoven**
- Explication : Presque totalement sourd, Beethoven composa sa 9e Symphonie et son « Ode à la joie » (1824). À la première, il fallut le retourner face au public pour qu'il voie les applaudissements qu'il n'entendait pas.

**[ar_mu_3]** (Vrai ou Faux) — Mozart a composé ses premières œuvres avant l'âge de 6 ans.
- Réponse : **Vrai**
- Explication : Mozart composa ses premiers menuets à 5 ans et fit ses premières tournées européennes à 6 ans. En 35 ans de vie, il laissa plus de 600 œuvres, dont 41 symphonies et 22 opéras.

**[ar_mu_4]** (Texte à trous) — Le ___ dirige les musiciens avec sa baguette.
- Choix : chef d'orchestre / premier violon / compositeur / soliste
- Réponse : **chef d'orchestre**
- Explication : La baguette n'est utilisée que depuis le XIXe siècle. Avant, on battait la mesure avec un lourd bâton : Lully s'en blessa le pied en dirigeant… et mourut de la gangrène en 1687.

**[ar_mu_5]** (Anagramme) — Instrument à 88 touches noires et blanches
- Réponse : **PIANO**
- Explication : Son nom complet est « piano-forte » (« doux-fort » en italien), car contrairement au clavecin, il permet de jouer doucement ou fort selon la force du toucher. Il fut inventé vers 1700 par Cristofori.

#### Monuments et architecture (`arts_monuments`)

**[ar_mo_1]** (QCM) — En quelle année la tour Eiffel a-t-elle été inaugurée ?
- Choix : 1889 / 1900 / 1870 / 1914
- Réponse : **1889**
- Explication : Construite pour l'Exposition universelle de 1889, la tour devait être démontée après 20 ans. Elle fut sauvée par son antenne de radio, devenue stratégique. Elle grandit de 15 cm l'été sous l'effet de la chaleur.

**[ar_mo_2]** (QCM) — Dans quel pays se trouve le Taj Mahal ?
- Choix : L'Inde / L'Iran / La Turquie / L'Égypte
- Réponse : **L'Inde**
- Explication : L'empereur Shah Jahan fit bâtir ce mausolée de marbre blanc (1631-1648) pour son épouse Mumtaz Mahal, morte en couches. Plus de 20 000 artisans y travaillèrent pendant 17 ans.

**[ar_mo_3]** (Vrai ou Faux) — La Grande Muraille de Chine est visible à l'œil nu depuis la Lune.
- Réponse : **Faux**
- Explication : C'est un mythe tenace : large de quelques mètres seulement, la muraille est invisible depuis la Lune et très difficile à repérer même en orbite basse, comme l'ont confirmé les astronautes.

**[ar_mo_4]** (Texte à trous) — La tour de ___ est mondialement célèbre pour son inclinaison.
- Choix : Pise / Londres / Séville / Bologne
- Réponse : **Pise**
- Explication : La tour penche depuis sa construction au XIIe siècle à cause d'un sol trop meuble. Des travaux menés en 2001 ont réduit son inclinaison de 44 cm pour la stabiliser… pour au moins 200 ans.

**[ar_mo_5]** (Anagramme) — Gigantesque amphithéâtre romain au cœur de Rome
- Réponse : **COLISEE**
- Explication : Inauguré en 80 ap. J.-C., le Colisée pouvait accueillir 50 000 spectateurs, évacués en 15 minutes grâce à ses 80 entrées — un système dont s'inspirent encore les stades modernes.


### Nature & Animaux (`nature`)

#### Animaux records (`nature_records`)

**[na_re_1]** (QCM) — Quel est le plus grand animal ayant jamais vécu sur Terre ?
- Choix : La baleine bleue / Le diplodocus / Le mammouth / Le mégalodon
- Réponse : **La baleine bleue**
- Explication : Avec ses 30 mètres et 170 tonnes, la baleine bleue dépasse tous les dinosaures connus. Son cœur pèse 600 kg — la taille d'une petite voiture — et son cri porte à des centaines de kilomètres.

**[na_re_2]** (QCM) — Quel est l'animal terrestre le plus rapide ?
- Choix : Le guépard / Le lion / L'antilope / Le lévrier
- Réponse : **Le guépard**
- Explication : Le guépard atteint 110 km/h en 3 secondes — mieux qu'une voiture de sport. Mais il ne tient ce sprint que 400 mètres : la moitié de ses chasses échouent par épuisement.

**[na_re_3]** (Vrai ou Faux) — La pieuvre possède trois cœurs.
- Réponse : **Vrai**
- Explication : Deux cœurs alimentent ses branchies, le troisième le reste du corps. Son sang est bleu, et chacun de ses huit bras contient ses propres neurones : ils peuvent « réfléchir » indépendamment.

**[na_re_4]** (Texte à trous) — L'___ d'Afrique est le plus grand animal terrestre actuel.
- Choix : éléphant / hippopotame / rhinocéros / girafe
- Réponse : **éléphant**
- Explication : Un éléphant d'Afrique peut peser 7 tonnes et manger 200 kg de végétaux par jour. La girafe est plus haute (jusqu'à 5,5 m), mais bien plus légère. Sa trompe compte 40 000 muscles.

**[na_re_5]** (Anagramme) — Plus grand oiseau du monde, incapable de voler mais champion de course
- Réponse : **AUTRUCHE**
- Explication : L'autruche court à 70 km/h et son œil est plus gros que son cerveau. Contrairement à la légende, elle ne se cache jamais la tête dans le sable : elle la baisse pour surveiller son nid.

#### La Vie marine (`nature_ocean`)

**[na_oc_1]** (QCM) — Quel est le plus grand poisson du monde ?
- Choix : Le requin-baleine / Le grand requin blanc / L'espadon / Le thon rouge
- Réponse : **Le requin-baleine**
- Explication : Long de 18 mètres, le requin-baleine est pourtant inoffensif : il se nourrit uniquement de plancton filtré par sa bouche d'un mètre cinquante de large. Chaque individu a un motif de taches unique, comme une empreinte digitale.

**[na_oc_2]** (QCM) — Grâce à quel organe les poissons respirent-ils sous l'eau ?
- Choix : Les branchies / Les poumons / Les nageoires / La vessie natatoire
- Réponse : **Les branchies**
- Explication : Les branchies extraient l'oxygène dissous dans l'eau. La vessie natatoire, elle, sert de « gilet de flottaison » interne : en la gonflant ou dégonflant, le poisson monte ou descend sans effort.

**[na_oc_3]** (Vrai ou Faux) — Les dauphins sont des poissons.
- Réponse : **Faux**
- Explication : Les dauphins sont des mammifères marins : ils respirent avec des poumons, allaitent leurs petits et doivent remonter en surface. Ils ne dorment que d'un demi-cerveau à la fois pour ne pas se noyer.

**[na_oc_4]** (Texte à trous) — Le corail est en réalité un ___ vivant.
- Choix : animal / végétal / minéral / champignon
- Réponse : **animal**
- Explication : Le corail est une colonie de minuscules animaux, les polypes, qui bâtissent un squelette calcaire. La Grande Barrière de corail, longue de 2 300 km, est la seule structure vivante visible depuis l'espace.

**[na_oc_5]** (Anagramme) — Mammifère marin surnommé « la licorne des mers » pour sa longue défense torsadée
- Réponse : **NARVAL**
- Explication : La « corne » du narval est en fait une dent qui peut atteindre 3 mètres, truffée de millions de terminaisons nerveuses. Au Moyen Âge, on la vendait à prix d'or comme corne de licorne.

#### Plantes et forêts (`nature_plantes`)

**[na_pl_1]** (QCM) — Quel gaz les plantes absorbent-elles pour réaliser la photosynthèse ?
- Choix : Le dioxyde de carbone / L'oxygène / L'azote / L'hydrogène
- Réponse : **Le dioxyde de carbone**
- Explication : Grâce à la lumière, les plantes transforment le CO₂ et l'eau en sucres, et rejettent de l'oxygène. Plus de la moitié de l'oxygène que nous respirons vient en réalité du plancton des océans.

**[na_pl_2]** (QCM) — Quelle forêt est surnommée « le poumon vert de la planète » ?
- Choix : L'Amazonie / La taïga sibérienne / La forêt du Congo / La forêt de Bornéo
- Réponse : **L'Amazonie**
- Explication : L'Amazonie couvre 5,5 millions de km² sur neuf pays et abrite environ 10 % des espèces connues au monde. On y découvre encore une nouvelle espèce tous les deux jours en moyenne.

**[na_pl_3]** (Vrai ou Faux) — Le bambou peut pousser de près d'un mètre en une seule journée.
- Réponse : **Vrai**
- Explication : Certains bambous poussent de 91 cm en 24 heures, un record absolu du monde végétal. Techniquement, le bambou n'est pas un arbre mais une herbe géante de la famille des graminées.

**[na_pl_4]** (Texte à trous) — Les ___ géants de Californie sont les plus grands arbres du monde.
- Choix : séquoias / chênes / baobabs / eucalyptus
- Réponse : **séquoias**
- Explication : Le plus haut, surnommé Hyperion, mesure près de 116 mètres — la hauteur d'un immeuble de 35 étages. Sa localisation exacte est tenue secrète pour le protéger des visiteurs.

**[na_pl_5]** (Anagramme) — Poudre fabriquée par les fleurs et transportée par les abeilles
- Réponse : **POLLEN**
- Explication : En butinant, une abeille visite jusqu'à 250 fleurs par heure. Environ 75 % des cultures alimentaires mondiales dépendent des pollinisateurs — sans eux, adieu pommes, café et chocolat.


### Tech & Espace (`technologie`)

#### Grandes inventions (`tech_inventions`)

**[te_in_1]** (QCM) — Qui a commercialisé la première ampoule électrique durable en 1879 ?
- Choix : Thomas Edison / Nikola Tesla / Alexander Graham Bell / Benjamin Franklin
- Réponse : **Thomas Edison**
- Explication : Edison testa plus de 6 000 matériaux avant de trouver le bon filament. Détenteur de 1 093 brevets, il fonda aussi la première centrale électrique du monde à New York en 1882.

**[te_in_2]** (QCM) — Quelle invention les frères Lumière ont-ils présentée au public en 1895 ?
- Choix : Le cinématographe / La radio / Le phonographe / La photographie couleur
- Réponse : **Le cinématographe**
- Explication : La première projection publique payante eut lieu à Paris le 28 décembre 1895 devant 33 spectateurs. La légende raconte que « L'Arrivée d'un train en gare » fit sursauter la salle entière.

**[te_in_3]** (Vrai ou Faux) — Le téléphone a été inventé avant l'automobile.
- Réponse : **Vrai**
- Explication : Graham Bell breveta le téléphone en 1876, dix ans avant la première automobile à essence de Carl Benz (1886). Les premiers mots au téléphone : « M. Watson, venez ici, j'ai besoin de vous. »

**[te_in_4]** (Texte à trous) — Les frères ___ ont fait voler le premier ballon à air chaud habité en 1783.
- Choix : Montgolfier / Wright / Lumière / Michelin
- Réponse : **Montgolfier**
- Explication : Avant d'embarquer des humains, la montgolfière transporta un mouton, un canard et un coq pour vérifier qu'on pouvait survivre en altitude. Les frères Wright, eux, inventèrent l'avion en 1903.

**[te_in_5]** (Anagramme) — Invention chinoise qui indique le nord et a révolutionné la navigation
- Réponse : **BOUSSOLE**
- Explication : Inventée en Chine il y a plus de 2 000 ans, la boussole servait d'abord à la divination avant de guider les navigateurs. Son aiguille aimantée s'aligne sur le champ magnétique terrestre.

#### Informatique et numérique (`tech_informatique`)

**[te_if_1]** (QCM) — Que signifie « www » dans une adresse internet ?
- Choix : World Wide Web / World Web Wire / Wide World Watch / Web World Work
- Réponse : **World Wide Web**
- Explication : Le Web fut inventé en 1989 par Tim Berners-Lee au CERN, à Genève, pour partager des documents entre chercheurs. Il offrit sa technologie au monde gratuitement, sans déposer de brevet.

**[te_if_2]** (QCM) — Quelle est l'unité de base de l'information en informatique ?
- Choix : Le bit / L'octet / Le pixel / Le hertz
- Réponse : **Le bit**
- Explication : Un bit vaut 0 ou 1 : c'est le langage binaire des machines. Huit bits forment un octet, capable de coder une lettre. Une photo de smartphone en contient plusieurs millions.

**[te_if_3]** (Vrai ou Faux) — Le premier ordinateur électronique pesait plusieurs tonnes.
- Réponse : **Vrai**
- Explication : L'ENIAC (1945) pesait 30 tonnes, occupait 167 m² et consommait autant qu'un quartier entier. Votre smartphone est des millions de fois plus puissant que lui.

**[te_if_4]** (Texte à trous) — Ada ___ est considérée comme la première programmeuse de l'histoire.
- Choix : Lovelace / Hopper / Turing / Babbage
- Réponse : **Lovelace**
- Explication : Dès 1843, Ada Lovelace écrivit le premier algorithme destiné à une machine, celle de Charles Babbage. Fille du poète Lord Byron, elle avait prédit que les machines pourraient un jour créer de la musique.

**[te_if_5]** (Anagramme) — Cerveau de l'ordinateur qui exécute des milliards de calculs par seconde
- Réponse : **PROCESSEUR**
- Explication : Un processeur moderne contient des dizaines de milliards de transistors gravés à quelques nanomètres — 10 000 fois plus fins qu'un cheveu. Le premier, l'Intel 4004 (1971), en comptait 2 300.

#### Conquête spatiale (`tech_espace`)

**[te_es_1]** (QCM) — Qui a été le premier homme à marcher sur la Lune ?
- Choix : Neil Armstrong / Buzz Aldrin / Youri Gagarine / John Glenn
- Réponse : **Neil Armstrong**
- Explication : Le 21 juillet 1969, Armstrong posa le pied sur la Lune : « Un petit pas pour l'homme, un bond de géant pour l'humanité. » L'ordinateur d'Apollo 11 était moins puissant qu'une calculatrice actuelle.

**[te_es_2]** (QCM) — Quel a été le premier satellite artificiel mis en orbite ?
- Choix : Spoutnik 1 / Explorer 1 / Hubble / Voyager 1
- Réponse : **Spoutnik 1**
- Explication : Lancé par l'URSS le 4 octobre 1957, Spoutnik 1 était une sphère de 58 cm émettant un simple « bip-bip ». Ce signal déclencha la course à l'espace entre les deux superpuissances.

**[te_es_3]** (Vrai ou Faux) — Youri Gagarine est le premier être humain à être allé dans l'espace.
- Réponse : **Vrai**
- Explication : Le 12 avril 1961, Gagarine fit le tour de la Terre en 108 minutes à bord de Vostok 1. Il avait 27 ans et son vol était entièrement automatisé : on ignorait si un humain pouvait agir en apesanteur.

**[te_es_4]** (Texte à trous) — La Station spatiale internationale fait le tour de la Terre en environ 90 ___.
- Choix : minutes / heures / jours / secondes
- Réponse : **minutes**
- Explication : Filant à 28 000 km/h, l'ISS boucle 16 orbites par jour : ses astronautes voient donc 16 levers et couchers de soleil quotidiens. Elle est habitée en permanence depuis novembre 2000.

**[te_es_5]** (Anagramme) — Véhicule qui arrache les astronautes à la gravité terrestre
- Réponse : **FUSEE**
- Explication : Pour échapper à la gravité terrestre, une fusée doit atteindre 28 000 km/h. Au décollage, la Saturn V du programme Apollo développait la puissance de 85 barrages hydroélectriques.


---

## 4. Mini-quiz d'onboarding (indépendant du catalogue principal)

5 questions fixes, volontairement très faciles, utilisées uniquement pendant l'onboarding pour garantir une première expérience réussie. Définies dans `MiniQuizContent.swift`, format identique (QCM) mais catalogue séparé du contenu du jeu.

**[onboarding-quiz-1]** — Quelle est la capitale de la France ?
- Choix : Paris / Lyon / Marseille / Bruxelles
- Réponse : **Paris**
- Explication : Paris est la capitale de la France depuis des siècles.

**[onboarding-quiz-2]** — Combien y a-t-il de continents sur Terre ?
- Choix : 5 / 6 / 7 / 9
- Réponse : **7**
- Explication : On compte généralement 7 continents : Afrique, Amérique du Nord, Amérique du Sud, Antarctique, Asie, Europe, Océanie.

**[onboarding-quiz-3]** — Quelle planète est surnommée la "planète rouge" ?
- Choix : Vénus / Mars / Jupiter / Saturne
- Réponse : **Mars**
- Explication : Mars doit sa couleur rouge à l'oxyde de fer présent à sa surface.

**[onboarding-quiz-4]** — Qui a peint la Joconde ?
- Choix : Léonard de Vinci / Picasso / Van Gogh / Monet
- Réponse : **Léonard de Vinci**
- Explication : Léonard de Vinci l'a peinte au début du XVIe siècle.

**[onboarding-quiz-5]** — Quel est le plus grand océan du monde ?
- Choix : Atlantique / Indien / Arctique / Pacifique
- Réponse : **Pacifique**
- Explication : L'océan Pacifique couvre à lui seul près d'un tiers de la surface du globe.

---

## 5. Modèle « Temps d'écran » (onboarding, pas des questions)

Utilisé dans l'étape onboarding « Temps d'écran » pour projeter honnêtement le temps cumulé de l'utilisateur (aucune statistique inventée). Défini dans `OnboardingModels.swift`.

| Tranche (id) | Libellé | Heures moyennes/jour retenues |
|---|---|---|
| `under2` | Moins de 2h | 1.5 |
| `between2and4` | 2h - 4h | 3 |
| `between4and6` | 4h - 6h | 5 |
| `between6and8` | 6h - 8h | 7 |
| `over8` | Plus de 8h | 9 |

Formule de projection utilisée : `années de vie = (heures_moyennes × 365 × 70) / (24 × 365)` sur une espérance de vie de référence de 70 ans.

---

## 6. Idées d'axes pour enrichir le contenu

Pistes pour ton IA data, en cohérence avec ce qui existe déjà :
- Compléter les disciplines à 3 chapitres (Littérature, Arts & Musique, Nature & Animaux, Tech & Espace) pour atteindre 5 chapitres comme Histoire/Sciences/Géographie.
- Ajouter de nouvelles disciplines (ex. Cinéma & Séries, Sport, Gastronomie, Mythologie, Actualités/Culture pop) en respectant le schéma de la section 2.
- Ajouter des chapitres plus difficiles/avancés dans les disciplines existantes pour varier la difficulté (aujourd'hui pas de notion de niveau de difficulté par question — à considérer si on veut exploiter `perceivedLevel` de l'onboarding).
- Toujours garder l'équilibre 4 types de question par lot de 5 (1 QCM + 1 Vrai/Faux + 1 Texte à trous + 1 Anagramme + 1 QCM), comme observé dans le contenu existant.
- Toujours viser une explication factuelle vérifiable, jamais de chiffre inventé — c'est un principe déjà appliqué à l'écran temps d'écran et doit rester valable pour tout le contenu.
