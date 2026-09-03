import Foundation

/// A single "did you know" fact shown on the pre-quiz teaser screen, tied to
/// one discipline. Written independently from question `explanation` fields
/// so this screen never repeats what a question later reveals.
nonisolated struct FunFact: Identifiable, Hashable {
    let id: String
    let disciplineId: String
    /// Short, punchy hook sentence shown big under the theme badge.
    let hook: String
    /// Longer paragraph developing the fact, shown under the illustration.
    let body: String
}

/// Static library of fun facts, several per discipline so consecutive rings
/// never show the same one. Independent of `content.json` question content.
nonisolated enum FunFactLibrary {
    static let facts: [FunFact] = [
        // MARK: Histoire
        FunFact(
            id: "hist_1",
            disciplineId: "histoire",
            hook: "La tour Eiffel devait être démontée après 20 ans.",
            body: "Construite pour l'Exposition universelle de 1889, elle n'avait qu'une autorisation temporaire. Elle a été sauvée grâce à son antenne radio, jugée trop utile militairement pour être détruite."
        ),
        FunFact(
            id: "hist_2",
            disciplineId: "histoire",
            hook: "Cléopâtre est née plus proche de nous que des pyramides.",
            body: "Les grandes pyramides de Gizeh datent d'environ 2560 av. J.-C., alors que Cléopâtre a régné vers 30 av. J.-C. Il s'est donc écoulé plus de temps entre les pyramides et Cléopâtre qu'entre Cléopâtre et aujourd'hui."
        ),
        FunFact(
            id: "hist_3",
            disciplineId: "histoire",
            hook: "La guerre la plus courte de l'Histoire a duré 38 minutes.",
            body: "En 1896, le conflit entre le Royaume-Uni et Zanzibar s'est arrêté quasi aussitôt commencé, après le bombardement du palais du sultan. Un record qui tient toujours aujourd'hui."
        ),
        FunFact(
            id: "hist_4",
            disciplineId: "histoire",
            hook: "Napoléon n'était pas particulièrement petit pour son époque.",
            body: "Sa taille, souvent citée comme minuscule, vient d'une confusion entre les pouces français et anglais. Avec environ 1,68 m, il était dans la moyenne des hommes de son temps."
        ),
        FunFact(
            id: "hist_5",
            disciplineId: "histoire",
            hook: "Le plus vieux traité de paix encore respecté a presque 3200 ans.",
            body: "Signé vers 1259 av. J.-C. entre l'Égypte et les Hittites après la bataille de Qadesh, ce traité est considéré comme le plus ancien accord diplomatique connu gravé sur pierre."
        ),

        // MARK: Sciences
        FunFact(
            id: "sci_1",
            disciplineId: "sciences",
            hook: "Un jour sur Vénus dure plus longtemps qu'une année sur Vénus.",
            body: "Vénus met environ 243 jours terrestres à faire un tour sur elle-même, mais seulement 225 jours pour faire le tour du Soleil. Sa rotation est aussi si lente qu'elle en devient plus longue que son orbite."
        ),
        FunFact(
            id: "sci_2",
            disciplineId: "sciences",
            hook: "Le corps humain brille légèrement dans le noir.",
            body: "Nos cellules émettent une infime lumière bioluminescente liée aux réactions chimiques du métabolisme. Elle est mille fois trop faible pour être vue à l'œil nu, mais des caméras ultra-sensibles l'ont captée."
        ),
        FunFact(
            id: "sci_3",
            disciplineId: "sciences",
            hook: "Le miel ne se périme jamais vraiment.",
            body: "Grâce à sa faible teneur en eau et à son acidité naturelle, le miel peut rester comestible pendant des millénaires. Des archéologues en ont retrouvé dans des tombes égyptiennes, encore consommable."
        ),
        FunFact(
            id: "sci_4",
            disciplineId: "sciences",
            hook: "Un éclair est environ 5 fois plus chaud que la surface du Soleil.",
            body: "La foudre peut atteindre près de 30 000°C en une fraction de seconde, contre environ 5500°C à la surface du Soleil. C'est cette chaleur extrême qui fait exploser l'air et produit le tonnerre."
        ),
        FunFact(
            id: "sci_5",
            disciplineId: "sciences",
            hook: "Les bananes sont légèrement radioactives.",
            body: "Elles contiennent du potassium 40, un isotope naturellement radioactif. La dose est infime et sans danger, mais elle sert d'unité de mesure amusante appelée « dose banane » en radioprotection."
        ),

        // MARK: Géographie
        FunFact(
            id: "geo_1",
            disciplineId: "geographie",
            hook: "Le Canada compte plus de lacs que tout le reste du monde réuni.",
            body: "On estime à plus de deux millions le nombre de lacs sur son territoire, soit environ 60% de tous les lacs de la planète, grâce à l'héritage des glaciers de la dernière ère glaciaire."
        ),
        FunFact(
            id: "geo_2",
            disciplineId: "geographie",
            hook: "L'Afrique pourrait contenir la Chine, les États-Unis et l'Europe en même temps.",
            body: "Sa superficie réelle (plus de 30 millions de km²) est largement sous-estimée sur les cartes classiques, déformées par la projection de Mercator qui agrandit les zones proches des pôles."
        ),
        FunFact(
            id: "geo_3",
            disciplineId: "geographie",
            hook: "Il existe une ville qui appartient à deux pays en même temps.",
            body: "Baarle, à la frontière entre la Belgique et les Pays-Bas, est un enchevêtrement de dizaines d'enclaves : certaines maisons ont littéralement la frontière tracée au sol, en travers du salon."
        ),
        FunFact(
            id: "geo_4",
            disciplineId: "geographie",
            hook: "La Russie s'étend sur 11 fuseaux horaires.",
            body: "Du plus à l'ouest au plus à l'est, un même pays peut donc vivre le matin et la nuit en même temps, un record mondial largement devant les autres grands pays du globe."
        ),
        FunFact(
            id: "geo_5",
            disciplineId: "geographie",
            hook: "Le point le plus proche des étoiles n'est pas l'Everest.",
            body: "En raison du renflement équatorial de la Terre, le sommet du volcan Chimborazo, en Équateur, est le point du globe le plus éloigné du centre de la Terre — donc le plus proche de l'espace."
        ),

        // MARK: Littérature
        FunFact(
            id: "lit_1",
            disciplineId: "litterature",
            hook: "Le mot « robot » vient d'une pièce de théâtre tchèque.",
            body: "Il a été inventé en 1920 par l'écrivain Karel Čapek dans sa pièce R.U.R., à partir du mot « robota » qui signifie travail forcé en tchèque."
        ),
        FunFact(
            id: "lit_2",
            disciplineId: "litterature",
            hook: "Victor Hugo a écrit une partie des Misérables nu.",
            body: "Pour se forcer à rester à son bureau et éviter les distractions, il aurait demandé à son valet de cacher ses vêtements jusqu'à ce qu'il ait fini d'écrire pour la journée."
        ),
        FunFact(
            id: "lit_3",
            disciplineId: "litterature",
            hook: "Le plus long roman jamais publié dépasse 1,3 million de mots.",
            body: "« À la recherche du perdu » de Marcel Proust détient officiellement ce record selon le Guinness des records, avec sept tomes et des milliers de pages."
        ),
        FunFact(
            id: "lit_4",
            disciplineId: "litterature",
            hook: "Sherlock Holmes n'a jamais prononcé « Élémentaire, mon cher Watson ».",
            body: "Cette phrase culte n'apparaît dans aucun des romans originaux d'Arthur Conan Doyle : elle a été inventée plus tard par les adaptations au cinéma."
        ),
        FunFact(
            id: "lit_5",
            disciplineId: "litterature",
            hook: "Le premier roman de science-fiction a été écrit par une femme de 18 ans.",
            body: "Mary Shelley avait à peine 18 ans lorsqu'elle a commencé à écrire « Frankenstein », publié en 1818, souvent considéré comme la première grande œuvre du genre."
        ),

        // MARK: Arts
        FunFact(
            id: "arts_1",
            disciplineId: "arts",
            hook: "La Joconde n'a pas de sourcils.",
            body: "Léonard de Vinci l'aurait peinte avec des sourcils fins qui ont disparu au fil des restaurations et du vernissage, ou selon d'autres experts qui n'en aurait tout simplement jamais peint."
        ),
        FunFact(
            id: "arts_2",
            disciplineId: "arts",
            hook: "Beethoven a continué de composer alors qu'il était devenu sourd.",
            body: "À partir de sa trentaine, son audition s'est peu à peu détériorée jusqu'à la surdité complète. Il composait en ressentant les vibrations du piano à travers le bois, posant sa tête dessus."
        ),
        FunFact(
            id: "arts_3",
            disciplineId: "arts",
            hook: "Van Gogh n'a vendu qu'un seul tableau de son vivant.",
            body: "Malgré plus de 800 peintures réalisées, seule « La Vigne rouge » a trouvé preneur avant sa mort, pour l'équivalent de quelques centaines d'euros actuels."
        ),
        FunFact(
            id: "arts_4",
            disciplineId: "arts",
            hook: "Le mot « musique » vient des muses de la mythologie grecque.",
            body: "Chez les Grecs anciens, les Muses étaient neuf déesses inspirant les arts. Le terme « mousikē » désignait à l'origine tout ce qui relevait de leur domaine, pas seulement le son."
        ),
        FunFact(
            id: "arts_5",
            disciplineId: "arts",
            hook: "Le plafond de la chapelle Sixtine n'a pas été peint allongé sur le dos.",
            body: "Contrairement à la légende, Michel-Ange a peint debout sur un échafaudage courbé, la tête renversée en arrière — une position tout aussi éprouvante qui lui a valu des douleurs chroniques."
        ),

        // MARK: Nature
        FunFact(
            id: "nat_1",
            disciplineId: "nature",
            hook: "Certains chats sont allergiques aux humains.",
            body: "La biologie a un sens de l'ironie assez féroce : si nos protéines cutanées ou nos produits ménagers irritent parfois leur système immunitaire sensible, certains chats développent bel et bien une hypersensibilité aux humains."
        ),
        FunFact(
            id: "nat_2",
            disciplineId: "nature",
            hook: "Les pieuvres ont trois cœurs et du sang bleu.",
            body: "Deux cœurs pompent le sang vers les branchies, le troisième vers le reste du corps. Leur sang est bleu car il transporte l'oxygène grâce à l'hémocyanine, à base de cuivre, plutôt que de fer."
        ),
        FunFact(
            id: "nat_3",
            disciplineId: "nature",
            hook: "Un escargot peut dormir jusqu'à trois ans d'affilée.",
            body: "En période de sécheresse ou de froid extrême, certaines espèces s'enferment dans leur coquille et ralentissent leur métabolisme au point de rester en sommeil plusieurs années."
        ),
        FunFact(
            id: "nat_4",
            disciplineId: "nature",
            hook: "Les girafes n'ont que sept vertèbres cervicales, comme nous.",
            body: "Malgré la longueur spectaculaire de leur cou, les girafes possèdent exactement le même nombre de vertèbres cervicales que les humains — chacune est simplement beaucoup plus longue."
        ),
        FunFact(
            id: "nat_5",
            disciplineId: "nature",
            hook: "Les arbres communiquent entre eux sous terre.",
            body: "Grâce à un réseau de champignons microscopiques reliant leurs racines, surnommé le « wood wide web », les arbres peuvent échanger nutriments et signaux d'alerte face aux parasites."
        ),

        // MARK: Technologie
        FunFact(
            id: "tech_1",
            disciplineId: "technologie",
            hook: "Le premier ordinateur pesait plus de 27 tonnes.",
            body: "L'ENIAC, mis en service en 1945, occupait une pièce entière et consommait autant d'électricité qu'un petit quartier, pour une puissance de calcul largement inférieure à celle d'une calculatrice actuelle."
        ),
        FunFact(
            id: "tech_2",
            disciplineId: "technologie",
            hook: "La première webcam surveillait... une cafetière.",
            body: "Des chercheurs de Cambridge l'ont installée en 1991 pour vérifier à distance si le café était prêt sans avoir à se déplacer, avant que le concept ne se généralise à Internet."
        ),
        FunFact(
            id: "tech_3",
            disciplineId: "technologie",
            hook: "Il y a plus de mille satellites actifs en orbite autour de la Terre.",
            body: "Ils servent aux communications, à la météo, à la navigation GPS et à l'observation de la Terre, et leur nombre a explosé ces dernières années avec les constellations privées."
        ),
        FunFact(
            id: "tech_4",
            disciplineId: "technologie",
            hook: "Le symbole « @ » existait bien avant l'e-mail.",
            body: "Utilisé depuis des siècles par les marchands pour indiquer un prix unitaire, il n'a été choisi pour les adresses électroniques qu'en 1971, car il était rarement utilisé dans les noms propres."
        ),
        FunFact(
            id: "tech_5",
            disciplineId: "technologie",
            hook: "Plus de gens ont un téléphone qu'un accès à l'eau potable.",
            body: "Selon plusieurs études des organisations internationales, le taux mondial de possession d'un téléphone mobile dépasse celui de l'accès à une eau potable sûre, un contraste frappant du monde actuel."
        ),

        // MARK: Football
        FunFact(
            id: "foot_1",
            disciplineId: "football",
            hook: "Le premier ballon de football était fait de vessies de porc gonflées.",
            body: "Avant l'invention du caoutchouc vulcanisé au 19e siècle, les premiers ballons utilisaient des vessies animales gonflées, recouvertes de cuir pour tenir leur forme ronde."
        ),
        FunFact(
            id: "foot_2",
            disciplineId: "football",
            hook: "Un match de Coupe du monde s'est terminé 149 à 0.",
            body: "En 2002, Madagascar a infligé ce score à l'AS Adema lors d'un championnat local, en guise de protestation contre un arbitrage jugé injuste, en marquant volontairement contre son propre camp."
        ),
        FunFact(
            id: "foot_3",
            disciplineId: "football",
            hook: "Le carton jaune et rouge a été inventé après un malentendu linguistique.",
            body: "L'arbitre anglais Ken Aston a eu l'idée en 1966, après avoir vu un joueur ne pas comprendre un avertissement verbal donné dans une autre langue lors d'un match international."
        ),
        FunFact(
            id: "foot_4",
            disciplineId: "football",
            hook: "Un même joueur a remporté la Coupe du monde avec deux pays différents... presque.",
            body: "Personne n'a encore réussi cet exploit précis avec l'équipe nationale, mais plusieurs sélectionneurs ont mené deux pays différents à des titres majeurs, une rareté qui alimente encore les débats."
        ),
        FunFact(
            id: "foot_5",
            disciplineId: "football",
            hook: "Le terrain de football le plus haut du monde est à plus de 3600 mètres d'altitude.",
            body: "Le stade Hernando Siles, à La Paz en Bolivie, joue avec l'air raréfié en altitude, un avantage tel pour l'équipe locale que la FIFA a un temps envisagé de l'interdire aux compétitions internationales."
        )
    ]

    /// All facts for a given discipline, in a stable order.
    static func facts(for disciplineId: String) -> [FunFact] {
        facts.filter { $0.disciplineId == disciplineId }
    }

    /// Picks a random fact for the discipline, avoiding the given previous
    /// fact id when the pool has more than one entry so two consecutive
    /// rings never show the exact same fact.
    static func randomFact(for disciplineId: String, avoiding previousId: String?) -> FunFact? {
        let pool = facts(for: disciplineId)
        guard !pool.isEmpty else { return nil }
        if pool.count == 1 { return pool.first }
        let candidates = pool.filter { $0.id != previousId }
        return (candidates.isEmpty ? pool : candidates).randomElement()
    }
}
