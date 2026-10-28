import AppKit

struct Release {
    let version: String
    let pageURL: URL
    let assetURL: URL?
}

/// Проверка и установка обновлений из GitHub Releases. В релизе ищется .zip с Foundry Lite.app
final class Updater {
    static let repo = "sevenwind/foundry-light-client"
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private struct APIRelease: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    enum UpdateError: LocalizedError {
        case http(Int), badArchive, notWritable
        var errorDescription: String? {
            switch self {
            case .http(let c): return "Сервер GitHub ответил кодом \(c)"
            case .badArchive: return "В архиве релиза не найдено приложение"
            case .notWritable: return "Нет прав на запись в папку с приложением"
            }
        }
    }

    /// Успех с nil — релизов в репозитории ещё нет
    static func fetchLatest(completion: @escaping (Result<Release?, Error>) -> Void) {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        URLSession.shared.dataTask(with: req) { data, response, error in
            let result: Result<Release?, Error>
            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                result = .success(nil)
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                result = .failure(UpdateError.http(http.statusCode))
            } else if let data, let api = try? JSONDecoder().decode(APIRelease.self, from: data) {
                let asset = api.assets.first { $0.name.lowercased().hasSuffix(".zip") }
                result = .success(Release(version: api.tag_name, pageURL: api.html_url, assetURL: asset?.browser_download_url))
            } else {
                result = .failure(UpdateError.badArchive)
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    /// "v1.10" новее "1.9": сравнение по числовым компонентам
    static func isNewer(_ remote: String, than local: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(remote), b = parts(local)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Скачивает архив, подменяет текущий .app после выхода и запускает новую версию
    static func install(_ release: Release, completion: @escaping (Error?) -> Void) {
        let target = Bundle.main.bundleURL
        guard let assetURL = release.assetURL, target.pathExtension == "app" else {
            NSWorkspace.shared.open(release.pageURL)
            return completion(nil)
        }
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            return completion(UpdateError.notWritable)
        }
        URLSession.shared.downloadTask(with: assetURL) { tmp, _, error in
            func finish(_ e: Error?) { DispatchQueue.main.async { completion(e) } }
            guard let tmp else { return finish(error) }
            do {
                let work = FileManager.default.temporaryDirectory.appendingPathComponent("FoundryLiteUpdate-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let zip = work.appendingPathComponent("update.zip")
                try FileManager.default.moveItem(at: tmp, to: zip)
                let unpacked = work.appendingPathComponent("app")
                let ditto = Process()
                ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                ditto.arguments = ["-x", "-k", zip.path, unpacked.path]
                try ditto.run()
                ditto.waitUntilExit()
                let found = try FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)
                guard ditto.terminationStatus == 0, let newApp = found.first(where: { $0.pathExtension == "app" }) else {
                    throw UpdateError.badArchive
                }
                let script = work.appendingPathComponent("swap.sh")
                try """
                #!/bin/bash
                while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
                rm -rf "$2" && mv "$3" "$2" && xattr -dr com.apple.quarantine "$2"
                open "$2"
                """.write(to: script, atomically: true, encoding: .utf8)
                let swap = Process()
                swap.executableURL = URL(fileURLWithPath: "/bin/bash")
                swap.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), target.path, newApp.path]
                try swap.run()
                DispatchQueue.main.async { NSApp.terminate(nil) }
            } catch {
                finish(error)
            }
        }.resume()
    }
}
