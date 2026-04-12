import Foundation
import SwiftData

@Model
final class Restaurant {
    @Attribute(.unique) var id: String
    var name: String
    var chainSlug: String?
    var latitude: Double
    var longitude: Double
    var address: String
    var slopRatingRaw: String
    var ratingSourceRaw: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CommunityNote.restaurant)
    var communityNotes: [CommunityNote] = []

    var slopRating: SlopRating {
        get { SlopRating(rawValue: slopRatingRaw) ?? .grey }
        set { slopRatingRaw = newValue.rawValue }
    }

    var ratingSource: RatingSource {
        get { RatingSource(rawValue: ratingSourceRaw) ?? .seeded }
        set { ratingSourceRaw = newValue.rawValue }
    }

    var isChain: Bool { chainSlug != nil }

    init(
        id: String,
        name: String,
        chainSlug: String? = nil,
        latitude: Double,
        longitude: Double,
        address: String,
        slopRating: SlopRating,
        ratingSource: RatingSource = .seeded
    ) {
        self.id = id
        self.name = name
        self.chainSlug = chainSlug
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.slopRatingRaw = slopRating.rawValue
        self.ratingSourceRaw = ratingSource.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    static func makeID(chainSlug: String?, latitude: Double, longitude: Double, placeID: String? = nil) -> String {
        if let placeID {
            return placeID
        }
        let slug = chainSlug ?? "independent"
        let lat = String(format: "%.5f", latitude)
        let lng = String(format: "%.5f", longitude)
        return "\(slug)_\(lat)_\(lng)"
    }
}
