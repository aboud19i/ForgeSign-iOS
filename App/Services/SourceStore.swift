import SwiftUI
import Combine

@MainActor
class SourceStore: ObservableObject {
    @Published var apps: [FeedApp] = []
    @Published var isLoading: Bool = false
    @Published var sources: [String] = []

    // السورس الحصري والافتراضي
    private let defaultSource = "https://repository.apptesters.org"

    init() {
        setupSingleSource()
        fetchApps()
    }

    /// ضبط السورس الحصري وتصفية السورسات القديمة
    func setupSingleSource() {
        self.sources = [defaultSource]
        UserDefaults.standard.set(self.sources, forKey: "user_sources")
    }

    /// جلب التطبيقات من السورس المعتمد
    func fetchApps() {
        guard let url = URL(string: defaultSource) else { return }
        self.isLoading = true

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let data = data, error == nil else { return }

                do {
                    let decodedResponse = try JSONDecoder().decode(SourceFeed.self, from: data)
                    self?.apps = decodedResponse.apps
                } catch {
                    print("Failed to decode JSON: \(error)")
                }
            }
        }.resume()
    }

    /// إتاحة دالة addSource
    func addSource(_ urlString: String) {
        if !sources.contains(urlString) {
            sources.append(urlString)
            UserDefaults.standard.set(sources, forKey: "user_sources")
            fetchApps()
        }
    }

    /// إتاحة دالة removeSource
    func removeSource(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
        UserDefaults.standard.set(sources, forKey: "user_sources")
    }
}
