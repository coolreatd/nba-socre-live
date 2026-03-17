import AppKit
import CryptoKit
import Foundation
import SwiftUI

actor RemoteImageCache {
    static let shared = RemoteImageCache()

    private let memoryCache = NSCache<NSURL, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    init() {
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        cacheDirectory = baseDirectory.appendingPathComponent("NBALiveImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func data(for urls: [URL]) async throws -> Data? {
        for url in urls {
            if let data = try await data(for: url) {
                return data
            }
        }
        return nil
    }

    func data(for url: URL) async throws -> Data? {
        let cacheKey = url as NSURL
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached as Data
        }

        let fileURL = cacheFileURL(for: url)
        if let diskData = try? Data(contentsOf: fileURL) {
            memoryCache.setObject(diskData as NSData, forKey: cacheKey)
            return diskData
        }

        let (data, response) = try await makeSession().data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            return nil
        }

        memoryCache.setObject(data as NSData, forKey: cacheKey)
        try? data.write(to: fileURL, options: .atomic)
        return data
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.connectionProxyDictionary = ProviderFactory.loadProxySettings().connectionProxyDictionary
        return URLSession(configuration: configuration)
    }

    private func cacheFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let key = digest.map { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        return cacheDirectory.appendingPathComponent("\(key).\(ext)")
    }
}

struct CachedRemoteImage<Placeholder: View>: View {
    let urls: [URL]
    let contentMode: ContentMode
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: Image?

    init(
        url: URL?,
        contentMode: ContentMode,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urls = url.map { [$0] } ?? []
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    init(
        urls: [URL],
        contentMode: ContentMode,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urls = urls
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: urls.map(\.absoluteString).joined(separator: "|")) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard !urls.isEmpty else {
            image = nil
            return
        }

        do {
            guard let data = try await RemoteImageCache.shared.data(for: urls),
                  let nsImage = NSImage(data: data) else {
                image = nil
                return
            }
            image = Image(nsImage: nsImage)
        } catch {
            image = nil
        }
    }
}
