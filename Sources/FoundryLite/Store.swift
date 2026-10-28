import Foundation

struct Server: Codable, Equatable {
    var name: String
    var url: String

    /// Ключ для настроек окна и зума: один и тот же сервер, сохранённый или нет
    var key: String {
        guard let u = normalizedURL(url) else { return url }
        return "\(u.host ?? "")-\(u.port ?? 0)"
    }
}

/// Принимает "host:30000", "http://host" и т.п., возвращает http(s) URL или nil
func normalizedURL(_ raw: String) -> URL? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }
    if !s.contains("://") { s = "http://" + s }
    guard let u = URL(string: s), let scheme = u.scheme?.lowercased(),
          ["http", "https"].contains(scheme), let host = u.host, !host.isEmpty else { return nil }
    return u
}

final class ServerStore {
    private(set) var servers: [Server] = []
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FoundryLite", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("servers.json")
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([Server].self, from: data) {
            servers = list
        }
    }

    func add(_ s: Server) { servers.append(s); save() }
    func update(at i: Int, _ s: Server) { servers[i] = s; save() }
    func remove(at i: Int) { servers.remove(at: i); save() }

    private func save() {
        if let data = try? JSONEncoder().encode(servers) { try? data.write(to: fileURL, options: .atomic) }
    }
}
