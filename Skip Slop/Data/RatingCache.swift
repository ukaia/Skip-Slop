import MapKit

/// A map item with its chain or independent match and cited grade, computed once.
/// Community reports are applied on top by `ExploreModel`.
struct RatedMapItem: Identifiable {
    let item: MKMapItem
    let chainMatch: ChainMatchResult?
    let independent: IndependentGrade?
    /// The researched grade, if any. Nil means no cited evidence.
    let cited: GradeAssessment?
    let placeKey: String

    var id: MKMapItem { item }

    func with(_ item: MKMapItem) -> RatedMapItem {
        RatedMapItem(item: item, chainMatch: chainMatch, independent: independent, cited: cited, placeKey: placeKey)
    }

    static func rate(_ item: MKMapItem, database: ChainDatabase, independents: IndependentGradeStore) -> RatedMapItem {
        let chainMatch = ChainMatcher.match(mapItem: item, using: database)
        var independent: IndependentGrade?
        var cited: GradeAssessment?
        if let chainMatch {
            cited = GradeResolver.assessment(for: chainMatch.chainInfo)
        } else if let name = item.name,
                  let match = independents.match(name: name, coordinate: item.location.coordinate) {
            independent = match
            cited = GradeResolver.assessment(for: match)
        }
        return RatedMapItem(
            item: item,
            chainMatch: chainMatch,
            independent: independent,
            cited: cited,
            placeKey: ChainMatcher.placeKey(for: item, chainSlug: chainMatch?.chainSlug)
        )
    }
}

/// Memoizes matching per map item so camera pans and re-renders don't redo
/// fuzzy matching for every annotation/row.
final class RatingCache {
    private var entries: [String: RatedMapItem] = [:]
    private let maxEntries = 2000
    private let independents: IndependentGradeStore

    init(independents: IndependentGradeStore = .shared) {
        self.independents = independents
    }

    static func key(for item: MKMapItem) -> String {
        if let identifier = item.identifier {
            return identifier.rawValue
        }
        let coord = item.location.coordinate
        return "\(item.name ?? "")|\(coord.latitude),\(coord.longitude)"
    }

    func rate(_ item: MKMapItem, using database: ChainDatabase) -> RatedMapItem {
        let key = Self.key(for: item)
        if let cached = entries[key] {
            // Same place, possibly a new MKMapItem instance from a fresh search.
            return cached.with(item)
        }
        let rated = RatedMapItem.rate(item, database: database, independents: independents)
        if entries.count >= maxEntries {
            entries.removeAll(keepingCapacity: true)
        }
        entries[key] = rated
        return rated
    }

    func rate(_ items: [MKMapItem], using database: ChainDatabase) -> [RatedMapItem] {
        items.map { rate($0, using: database) }
    }
}
