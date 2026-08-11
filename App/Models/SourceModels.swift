import Foundation

// MARK: - Source Feed Structure

struct SourceFeed: Codable {
    let name: String?
    let identifier: String?
    let apps: [FeedApp]

    enum CodingKeys: String, CodingKey {
        case name
        case identifier
        case apps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try? container.decode(String.self, forKey: .name)
        self.identifier = try? container.decode(String.self, forKey: .identifier)
        
        if let appsList = try? container.decode([FeedApp].self, forKey: .apps) {
            self.apps = appsList
        } else {
            self.apps = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encode(apps, forKey: .apps)
    }
}

// MARK: - Feed App Model

struct FeedApp: Codable, Identifiable {
    var id: String { bundleIdentifier }

    let bundleIdentifier: String
    let title: String?
    let developer: String?
    let description: String?
    let iconURL: URL?
    let bannerURL: URL?
    let imageURL: URL?
    let versions: [FeedVersion]

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case bundleID
        case name
        case title
        case developer = "developerName"
        case description = "localizedDescription"
        case iconURL
        case bannerURL
        case banner
        case imageURL
        case image
        case versions
        // common top-level single-version keys
        case ipa
        case download
        case downloadURL
        case down
        case url
        case version
        case filesize
        case size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let bId = try? container.decode(String.self, forKey: .bundleIdentifier) {
            self.bundleIdentifier = bId
        } else if let bId = try? container.decode(String.self, forKey: .bundleID) {
            self.bundleIdentifier = bId
        } else {
            self.bundleIdentifier = UUID().uuidString
        }

        self.title = (try? container.decode(String.self, forKey: .name)) ?? (try? container.decode(String.self, forKey: .title))
        self.developer = try? container.decode(String.self, forKey: .developer)
        self.description = try? container.decode(String.self, forKey: .description)

        // icon URL
        if let iconString = try? container.decode(String.self, forKey: .iconURL) {
            self.iconURL = URL(string: iconString)
        } else {
            self.iconURL = nil
        }

        // banner / image priority: try multiple common keys
        var bannerString: String? = nil
        if let s = try? container.decode(String.self, forKey: .bannerURL) { bannerString = s }
        if bannerString == nil, let s = try? container.decode(String.self, forKey: .banner) { bannerString = s }
        if bannerString == nil, let s = try? container.decode(String.self, forKey: .imageURL) { bannerString = s }
        if bannerString == nil, let s = try? container.decode(String.self, forKey: .image) { bannerString = s }

        if let b = bannerString, !b.isEmpty {
            self.bannerURL = URL(string: b)
        } else {
            self.bannerURL = nil
        }

        // imageURL (distinct) fallback — try imageURL then image
        if let imgString = try? container.decode(String.self, forKey: .imageURL) {
            self.imageURL = URL(string: imgString)
        } else if let imgString = try? container.decode(String.self, forKey: .image) {
            self.imageURL = URL(string: imgString)
        } else {
            self.imageURL = nil
        }

        // Try to decode explicit versions array first
        if let versionsList = try? container.decode([FeedVersion].self, forKey: .versions), !versionsList.isEmpty {
            self.versions = versionsList
        } else {
            // Some feeds put ipa/download fields at the app root (single-version). Try to detect common keys.
            var topLevelURLString: String? = nil
            if let s = try? container.decode(String.self, forKey: .downloadURL) { topLevelURLString = s }
            if topLevelURLString == nil, let s = try? container.decode(String.self, forKey: .down) { topLevelURLString = s }
            if topLevelURLString == nil, let s = try? container.decode(String.self, forKey: .download) { topLevelURLString = s }
            if topLevelURLString == nil, let s = try? container.decode(String.self, forKey: .ipa) { topLevelURLString = s }
            if topLevelURLString == nil, let s = try? container.decode(String.self, forKey: .url) { topLevelURLString = s }

            let topVersion = (try? container.decode(String.self, forKey: .version)) ?? "1.0"
            // size can be under several keys and sometimes as string
            var topSize: Int64? = nil
            if let sVal = try? container.decode(Int64.self, forKey: .size) { topSize = sVal }
            else if let sVal = try? container.decode(Int64.self, forKey: .filesize) { topSize = sVal }
            else if let sStr = try? container.decode(String.self, forKey: .size), let n = Int64(sStr) { topSize = n }
            else if let sStr = try? container.decode(String.self, forKey: .filesize), let n = Int64(sStr) { topSize = n }

            if let urlStr = topLevelURLString, let url = URL(string: urlStr) {
                self.versions = [FeedVersion(version: topVersion, downloadURL: url, size: topSize)]
            } else {
                self.versions = []
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(developer, forKey: .developer)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(iconURL?.absoluteString, forKey: .iconURL)
        try container.encodeIfPresent(bannerURL?.absoluteString, forKey: .bannerURL)
        try container.encodeIfPresent(imageURL?.absoluteString, forKey: .imageURL)
        try container.encode(versions, forKey: .versions)
    }
}

// MARK: - Feed Version Model

struct FeedVersion: Codable {
    let version: String
    let downloadURL: URL?
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case version
        case downloadURL
        case size
        case ipa
        case download
        case down
        case url
        case filesize
    }

    // Add convenience initializer so callers can construct programmatically
    init(version: String, downloadURL: URL?, size: Int64?) {
        self.version = version
        self.downloadURL = downloadURL
        self.size = size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = (try? container.decode(String.self, forKey: .version)) ?? "1.0"

        // try common URL keys
        if let urlString = try? container.decode(String.self, forKey: .downloadURL) {
            self.downloadURL = URL(string: urlString)
        } else if let urlString = try? container.decode(String.self, forKey: .down) {
            self.downloadURL = URL(string: urlString)
        } else if let urlString = try? container.decode(String.self, forKey: .ipa) {
            self.downloadURL = URL(string: urlString)
        } else if let urlString = try? container.decode(String.self, forKey: .download) {
            self.downloadURL = URL(string: urlString)
        } else if let urlString = try? container.decode(String.self, forKey: .url) {
            self.downloadURL = URL(string: urlString)
        } else {
            self.downloadURL = nil
        }

        // size under different possible keys
        if let s = try? container.decode(Int64.self, forKey: .size) {
            self.size = s
        } else if let s = try? container.decode(Int64.self, forKey: .filesize) {
            self.size = s
        } else if let sStr = try? container.decode(String.self, forKey: .size), let n = Int64(sStr) {
            self.size = n
        } else if let sStr = try? container.decode(String.self, forKey: .filesize), let n = Int64(sStr) {
            self.size = n
        } else {
            self.size = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(downloadURL?.absoluteString, forKey: .downloadURL)
        try container.encodeIfPresent(size, forKey: .size)
    }
}
