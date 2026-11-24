// Tabelle compatte di aeroporti (codice IATA, nome, città, paese, fuso) e compagnie aeree: servono a leggere i biglietti
// di viaggio, dove l'ora di partenza è nel fuso dell'aeroporto di partenza e quella di arrivo in quello di arrivo.

import Foundation

struct Airport {
    let code: String, name: String, city: String, country: String, tz: String
    /// "Milano Linate LIN, Milano, Italia"
    var label: String { "\(name) \(code), \(city), \(country)" }
}

enum Travel {
    static let airports: [String: Airport] = {
        var out: [String: Airport] = [:]
        for line in airportTable.split(separator: "\n") {
            let p = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard p.count == 5 else { continue }
            out[p[0]] = Airport(code: p[0], name: p[1], city: p[2], country: p[3], tz: p[4])
        }
        return out
    }()

    static let airlines: [String: String] = {
        var out: [String: String] = [:]
        for pair in airlineTable.split(separator: ";") {
            let p = pair.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if p.count == 2 { out[p[0]] = p[1] }
        }
        return out
    }()

    /// Cerca un aeroporto per nome o città scritti per esteso (senza codice).
    static func airport(named text: String) -> Airport? {
        let t = text.lowercased()
        // Prima il nome completo ("milano linate"), poi la sola città.
        if let a = airports.values.first(where: { t.contains($0.name.lowercased()) }) { return a }
        return airports.values.sorted { $0.city.count > $1.city.count }.first { t.contains($0.city.lowercased()) }
    }

    private static let airlineTable = """
    AZ=ITA Airways; SN=Brussels Airlines; LH=Lufthansa; AF=Air France; KL=KLM; BA=British Airways; IB=Iberia; VY=Vueling; \
    FR=Ryanair; U2=easyJet; W6=Wizz Air; LX=Swiss; OS=Austrian Airlines; TP=TAP Air Portugal; SK=SAS; AY=Finnair; \
    EI=Aer Lingus; TK=Turkish Airlines; EK=Emirates; QR=Qatar Airways; EY=Etihad; DL=Delta; UA=United; AA=American Airlines; \
    AC=Air Canada; LO=LOT Polish Airlines; NH=ANA; JL=Japan Airlines; SQ=Singapore Airlines; CX=Cathay Pacific; KE=Korean Air; \
    ET=Ethiopian Airlines; MS=EgyptAir; AT=Royal Air Maroc; A3=Aegean; OK=Czech Airlines; HV=Transavia; TO=Transavia France; \
    DY=Norwegian; VS=Virgin Atlantic; LA=LATAM; BT=airBaltic; EW=Eurowings; 4U=Eurowings; LS=Jet2; V7=Volotea; \
    EN=Air Dolomiti; XQ=SunExpress; PC=Pegasus; IG=Air Italy; NO=Neos; B6=JetBlue; AS=Alaska Airlines; WN=Southwest
    """

    // codice|nome|città|paese|fuso
    private static let airportTable = """
    MXP|Milano Malpensa|Milano|Italia|Europe/Rome
    LIN|Milano Linate|Milano|Italia|Europe/Rome
    BGY|Bergamo Orio al Serio|Bergamo|Italia|Europe/Rome
    FCO|Roma Fiumicino|Roma|Italia|Europe/Rome
    CIA|Roma Ciampino|Roma|Italia|Europe/Rome
    VCE|Venezia Marco Polo|Venezia|Italia|Europe/Rome
    TSF|Treviso Sant'Angelo|Treviso|Italia|Europe/Rome
    BLQ|Bologna Guglielmo Marconi|Bologna|Italia|Europe/Rome
    FLR|Firenze Peretola|Firenze|Italia|Europe/Rome
    PSA|Pisa Galilei|Pisa|Italia|Europe/Rome
    NAP|Napoli Capodichino|Napoli|Italia|Europe/Rome
    BRI|Bari Karol Wojtyla|Bari|Italia|Europe/Rome
    BDS|Brindisi Salento|Brindisi|Italia|Europe/Rome
    CTA|Catania Fontanarossa|Catania|Italia|Europe/Rome
    PMO|Palermo Falcone Borsellino|Palermo|Italia|Europe/Rome
    CAG|Cagliari Elmas|Cagliari|Italia|Europe/Rome
    OLB|Olbia Costa Smeralda|Olbia|Italia|Europe/Rome
    AHO|Alghero Fertilia|Alghero|Italia|Europe/Rome
    TRN|Torino Caselle|Torino|Italia|Europe/Rome
    GOA|Genova Cristoforo Colombo|Genova|Italia|Europe/Rome
    VRN|Verona Villafranca|Verona|Italia|Europe/Rome
    TRS|Trieste Friuli Venezia Giulia|Trieste|Italia|Europe/Rome
    PEG|Perugia Sant'Egidio|Perugia|Italia|Europe/Rome
    SUF|Lamezia Terme|Lamezia Terme|Italia|Europe/Rome
    PSR|Pescara Abruzzo|Pescara|Italia|Europe/Rome
    AOI|Ancona Falconara|Ancona|Italia|Europe/Rome
    BRU|Bruxelles Zaventem|Bruxelles|Belgio|Europe/Brussels
    CRL|Bruxelles Charleroi|Charleroi|Belgio|Europe/Brussels
    AMS|Amsterdam Schiphol|Amsterdam|Paesi Bassi|Europe/Amsterdam
    CDG|Parigi Charles de Gaulle|Parigi|Francia|Europe/Paris
    ORY|Parigi Orly|Parigi|Francia|Europe/Paris
    NCE|Nizza Costa Azzurra|Nizza|Francia|Europe/Paris
    LYS|Lione Saint-Exupery|Lione|Francia|Europe/Paris
    MRS|Marsiglia Provenza|Marsiglia|Francia|Europe/Paris
    TLS|Tolosa Blagnac|Tolosa|Francia|Europe/Paris
    LHR|Londra Heathrow|Londra|Regno Unito|Europe/London
    LGW|Londra Gatwick|Londra|Regno Unito|Europe/London
    STN|Londra Stansted|Londra|Regno Unito|Europe/London
    LTN|Londra Luton|Londra|Regno Unito|Europe/London
    LCY|Londra City|Londra|Regno Unito|Europe/London
    MAN|Manchester|Manchester|Regno Unito|Europe/London
    EDI|Edimburgo|Edimburgo|Regno Unito|Europe/London
    DUB|Dublino|Dublino|Irlanda|Europe/Dublin
    FRA|Francoforte|Francoforte|Germania|Europe/Berlin
    MUC|Monaco di Baviera|Monaco|Germania|Europe/Berlin
    BER|Berlino Brandeburgo|Berlino|Germania|Europe/Berlin
    HAM|Amburgo|Amburgo|Germania|Europe/Berlin
    DUS|Dusseldorf|Dusseldorf|Germania|Europe/Berlin
    CGN|Colonia Bonn|Colonia|Germania|Europe/Berlin
    STR|Stoccarda|Stoccarda|Germania|Europe/Berlin
    ZRH|Zurigo|Zurigo|Svizzera|Europe/Zurich
    GVA|Ginevra|Ginevra|Svizzera|Europe/Zurich
    BSL|Basilea Mulhouse|Basilea|Svizzera|Europe/Zurich
    VIE|Vienna Schwechat|Vienna|Austria|Europe/Vienna
    MAD|Madrid Barajas|Madrid|Spagna|Europe/Madrid
    BCN|Barcellona El Prat|Barcellona|Spagna|Europe/Madrid
    AGP|Malaga|Malaga|Spagna|Europe/Madrid
    VLC|Valencia|Valencia|Spagna|Europe/Madrid
    PMI|Palma di Maiorca|Palma|Spagna|Europe/Madrid
    LIS|Lisbona Humberto Delgado|Lisbona|Portogallo|Europe/Lisbon
    OPO|Porto Francisco Sa Carneiro|Porto|Portogallo|Europe/Lisbon
    ATH|Atene Venizelos|Atene|Grecia|Europe/Athens
    CPH|Copenaghen Kastrup|Copenaghen|Danimarca|Europe/Copenhagen
    ARN|Stoccolma Arlanda|Stoccolma|Svezia|Europe/Stockholm
    OSL|Oslo Gardermoen|Oslo|Norvegia|Europe/Oslo
    HEL|Helsinki Vantaa|Helsinki|Finlandia|Europe/Helsinki
    WAW|Varsavia Chopin|Varsavia|Polonia|Europe/Warsaw
    PRG|Praga Vaclav Havel|Praga|Repubblica Ceca|Europe/Prague
    BUD|Budapest Liszt Ferenc|Budapest|Ungheria|Europe/Budapest
    OTP|Bucarest Otopeni|Bucarest|Romania|Europe/Bucharest
    SOF|Sofia|Sofia|Bulgaria|Europe/Sofia
    LUX|Lussemburgo Findel|Lussemburgo|Lussemburgo|Europe/Luxembourg
    KEF|Reykjavik Keflavik|Reykjavik|Islanda|Atlantic/Reykjavik
    IST|Istanbul|Istanbul|Turchia|Europe/Istanbul
    SAW|Istanbul Sabiha Gokcen|Istanbul|Turchia|Europe/Istanbul
    JFK|New York JFK|New York|Stati Uniti|America/New_York
    EWR|New York Newark|Newark|Stati Uniti|America/New_York
    LGA|New York LaGuardia|New York|Stati Uniti|America/New_York
    BOS|Boston Logan|Boston|Stati Uniti|America/New_York
    IAD|Washington Dulles|Washington|Stati Uniti|America/New_York
    ATL|Atlanta Hartsfield-Jackson|Atlanta|Stati Uniti|America/New_York
    MIA|Miami|Miami|Stati Uniti|America/New_York
    ORD|Chicago O'Hare|Chicago|Stati Uniti|America/Chicago
    DFW|Dallas Fort Worth|Dallas|Stati Uniti|America/Chicago
    LAX|Los Angeles|Los Angeles|Stati Uniti|America/Los_Angeles
    SFO|San Francisco|San Francisco|Stati Uniti|America/Los_Angeles
    SEA|Seattle Tacoma|Seattle|Stati Uniti|America/Los_Angeles
    YYZ|Toronto Pearson|Toronto|Canada|America/Toronto
    YUL|Montreal Trudeau|Montreal|Canada|America/Toronto
    MEX|Citta del Messico|Citta del Messico|Messico|America/Mexico_City
    GRU|San Paolo Guarulhos|San Paolo|Brasile|America/Sao_Paulo
    EZE|Buenos Aires Ezeiza|Buenos Aires|Argentina|America/Argentina/Buenos_Aires
    DXB|Dubai|Dubai|Emirati Arabi Uniti|Asia/Dubai
    AUH|Abu Dhabi|Abu Dhabi|Emirati Arabi Uniti|Asia/Dubai
    DOH|Doha Hamad|Doha|Qatar|Asia/Qatar
    TLV|Tel Aviv Ben Gurion|Tel Aviv|Israele|Asia/Jerusalem
    CAI|Il Cairo|Il Cairo|Egitto|Africa/Cairo
    CMN|Casablanca Mohammed V|Casablanca|Marocco|Africa/Casablanca
    TUN|Tunisi Cartagine|Tunisi|Tunisia|Africa/Tunis
    JNB|Johannesburg O.R. Tambo|Johannesburg|Sudafrica|Africa/Johannesburg
    ADD|Addis Abeba Bole|Addis Abeba|Etiopia|Africa/Addis_Ababa
    NBO|Nairobi Jomo Kenyatta|Nairobi|Kenya|Africa/Nairobi
    SIN|Singapore Changi|Singapore|Singapore|Asia/Singapore
    HKG|Hong Kong|Hong Kong|Hong Kong|Asia/Hong_Kong
    NRT|Tokyo Narita|Tokyo|Giappone|Asia/Tokyo
    HND|Tokyo Haneda|Tokyo|Giappone|Asia/Tokyo
    ICN|Seul Incheon|Seul|Corea del Sud|Asia/Seoul
    PEK|Pechino Capital|Pechino|Cina|Asia/Shanghai
    PVG|Shanghai Pudong|Shanghai|Cina|Asia/Shanghai
    BKK|Bangkok Suvarnabhumi|Bangkok|Thailandia|Asia/Bangkok
    DEL|Nuova Delhi|Nuova Delhi|India|Asia/Kolkata
    BOM|Mumbai|Mumbai|India|Asia/Kolkata
    SYD|Sydney|Sydney|Australia|Australia/Sydney
    MEL|Melbourne|Melbourne|Australia|Australia/Melbourne
    """
}
