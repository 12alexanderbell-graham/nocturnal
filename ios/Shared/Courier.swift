import Foundation

/// One command and its answer, without the app: for the widgets' buttons and their refresh. Same protocol as
/// Relay, but instead of holding a stream open it posts the sealed command, then asks the relay for anything sent
/// to the reply topic since, about once a second, until the answer turns up or time runs out.
nonisolated enum Courier {
    enum Failure: Error {
        case notPaired
        case relay
        case refused(String)
        case noAnswer
    }

    /// Sends `cmd` and returns the computer's status from its answer. `keep` leaves the command at the relay for a
    /// sleeping computer's next check-in (a wake must; a status request mustn't pile up). With `wait` zero it only
    /// posts.
    @discardableResult
    static func send(_ cmd: String, _ args: [String: Any] = [:], keep: Bool = true,
                     wait: TimeInterval = 10) async throws(Failure) -> Panel? {
        guard let pairing = PairingStore.load() else { throw .notPaired }
        let session = URLSession(configuration: .ephemeral)
        let id = (0..<8).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        let now = Int(Date().timeIntervalSince1970)
        let message: [String: Any] = ["t": now, "n": id, "cmd": cmd, "args": args, "dev": "iPhone"]
        guard let plain = try? JSONSerialization.data(withJSONObject: message),
              let body = pairing.seal(plain, topic: pairing.commandTopic),
              let url = URL(string: "\(pairing.server)/\(pairing.commandTopic)") else { throw .relay }
        var post = URLRequest(url: url, timeoutInterval: 8)
        post.httpMethod = "POST"
        post.httpBody = Data(body.utf8)
        post.setValue(keep ? "yes" : "no", forHTTPHeaderField: "Cache")
        guard let (_, response) = try? await session.data(for: post),
              (response as? HTTPURLResponse)?.statusCode == 200 else { throw .relay }
        guard wait > 0 else { return nil }

        // A few seconds of slack: the relay stamps messages with its own clock.
        guard let poll = URL(string: "\(pairing.server)/\(pairing.replyTopic)/json?poll=1&since=\(now - 5)") else { throw .relay }
        let deadline = Date().addingTimeInterval(wait)
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(1.2))
            guard let (data, response) = try? await session.data(from: poll),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                guard let ev = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      ev["event"] as? String == "message",
                      let text = await text(of: ev, pairing: pairing, session: session),
                      let opened = pairing.open(text, topic: pairing.replyTopic),
                      let reply = try? JSONSerialization.jsonObject(with: opened) as? [String: Any],
                      reply["re"] as? String == id else { continue }
                if reply["ok"] as? Bool == false { throw .refused(reply["error"] as? String ?? "Not done") }
                return (reply["panel"]).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                    .flatMap { try? JSONDecoder().decode(Panel.self, from: $0) }
            }
        }
        throw .noAnswer
    }

    /// ntfy turns messages over 4 KB into attachments; those are fetched (still sealed) from the same relay only.
    private static func text(of ev: [String: Any], pairing: Pairing, session: URLSession) async -> String? {
        if let a = ev["attachment"] as? [String: Any], let s = a["url"] as? String, let url = URL(string: s),
           (a["size"] as? Int ?? .max) < 65536, url.host == URL(string: pairing.server)?.host, url.scheme == "https" {
            return (try? await session.data(from: url)).map { String(decoding: $0.0, as: UTF8.self) }
        }
        return ev["message"] as? String
    }
}
