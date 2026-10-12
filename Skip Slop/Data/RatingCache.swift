import MapKit

/// A map item with its chain match and inferred rating, computed once.
struct RatedMapItem: Identifiable {
    let item: MKMapItem
    let chainMatch: ChainMatchResult?
    let inference: RatingInferenceEngine.InferenceResult

    var id: MKMapItem { item }
}

/// Memoizes `ChainMatcher.match` + `RatingInferenceEngine.infer` per map item so
/// camera pans and re-renders don't redo fuzzy matching for every annotation/row.
final class RatingCache {
    private var entries: [String: RatedMapItem] = [:]
    private let maxEntries = 2000

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
            return RatedMapItem(item: item, chainMatch: cached.chainMatch, inference: cached.inference)
        }
        let chainMatch = ChainMatcher.match(mapItem: item, using: database)
        let rated = RatedMapItem(
            item: item,
            chainMatch: chainMatch,
            inference: RatingInferenceEngine.infer(mapItem: item, chainMatch: chainMatch)
        )
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
