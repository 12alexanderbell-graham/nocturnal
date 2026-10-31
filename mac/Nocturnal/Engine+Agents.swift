import AppKit
import IOKit.pwr_mgt

/// Agents: sampling who is running and working (with their own hook reports laid over the power guess), the
/// "finished" alerts, and the apps the person added.
extension Engine {
    func sampleWatchers() {
        let extra = config.customAgents.map { AgentKind(id: "custom:" + $0.name, name: $0.name, executables: Set($0.executables),
                                                       scriptHints: [], transcriptDirs: [], idleWatts: $0.idleWatts ?? 0.05) }
        watcher.sample(custom: config.watchedApps, requests: config.countRequests, extraKinds: extra)
        let now = Date()
        sessions = applyAgentEvents(watcher.sessions, now: now)
        blockers = watcher.blockers
        for s in sessions where counts(s) {
            lastSeen = (now, s.kind.name)
            if isWorking(s) { lastWork = (max(s.lastActive, now.addingTimeInterval(-20)), s.kind.name) }
        }
        detectFinished()
    }

    func applyAgentEvents(_ list: [AgentSession], now: Date) -> [AgentSession] {
        agentEvents = previewOnly ? [] : AgentEvents.load(now: now)
        // Codex says when a turn ends but not when one starts: activity well after its last "finished" is a new turn.
        if let done = agentEvents.first(where: { $0.agent == "codex" && $0.state == .finished }),
           let s = list.first(where: { $0.kind.id == "codex" }),
           s.lastActive.timeIntervalSince1970 > done.at + Self.codexNewTurnAfter {
            AgentEvents.noteWorking(agent: "codex", session: done.session, at: s.lastActive, pid: s.pid)
            agentEvents = AgentEvents.load(now: now)
        }
        guard !agentEvents.isEmpty else { return list }
        var out = list
        for i in out.indices where !out[i].kind.isRequest {
            guard let (st, at) = AgentEvents.state(of: out[i].kind.id, in: agentEvents, lastActive: out[i].lastActive, now: now) else { continue }
            out[i].state = st
            switch st {
            case .working:
                out[i].lastActive = now
            case .waiting:
                if now.timeIntervalSince(at) < AgentEvents.waitLimit { out[i].lastActive = now }
                let key = out[i].kind.id + "@\(Int(at.timeIntervalSince1970))"
                if !announcedWaits.contains(key) {
                    announcedWaits.insert(key)
                    // Only worth a push while the person is away from the screen.
                    if lidClosed || holding { onNeedsYou?(out[i].kind.name) }
                }
            case .finished, .idle:
                // A command it left running in the background still counts; otherwise the turn's end is the last work.
                if !out[i].toolRunning { out[i].lastActive = at }
            }
        }
        if announcedWaits.count > 50 { announcedWaits.removeAll() }
        return out
    }

    /// Seconds of activity after Codex's last finished turn that count as a new turn (not the tail of the old one).
    static let codexNewTurnAfter: TimeInterval = 30

    /// How long an agent has to be quiet before it counts as done. An agent that reports its own state is believed
    /// at once; one Nocturnal can only judge by power gets longer, because a model thinking in silence uses none.
    func quietWindow(_ s: AgentSession) -> TimeInterval {
        let base = TimeInterval(config.quietMinutes * 60)
        return s.state == nil && s.kind.isAI ? max(base, Self.guessedQuiet) : base
    }
    static let guessedQuiet: TimeInterval = 10 * 60

    func counts(_ s: AgentSession) -> Bool {
        !s.kind.isRequest && !config.trackOnly.contains(s.kind.id) && !(s.kind == AgentKind.claudeApp && !config.countClaudeApp)
    }

    func detectFinished() {
        let now = Date()
        var working: [String: Date] = [:]
        for s in sessions where !s.kind.isRequest && isWorking(s) {
            if s.kind == AgentKind.claudeApp && !config.countClaudeApp { continue }
            // Keyed by kind: sessions of one kind are merged under whichever pid comes first, which can change.
            // Busy again within the 2-minute wait: same stretch of work.
            working[s.kind.id] = workingSince[s.kind.id] ?? idlePending.removeValue(forKey: s.kind.id)?.since ?? now
        }
        for (id, since) in workingSince where working[id] == nil { idlePending[id] = (since, now) }
        workingSince = working
        for (id, p) in idlePending {
            let present = sessions.first { $0.kind.id == id }
            // Its own "finished" or "waiting" is announced after 2 quiet minutes; a guess from power after 5.
            let wait: TimeInterval = present?.state == nil && present != nil ? 300 : 120
            guard now.timeIntervalSince(p.quietAt) >= wait else { continue }
            idlePending[id] = nil
            let minutes = p.quietAt.timeIntervalSince(p.since) / 60
            // The Claude app's work mostly runs in the cloud, so its power here says nothing about whether it's done.
            guard minutes >= 1, !previewOnly, id != AgentKind.claudeApp.id else { continue }
            onFinished?(present?.kind.name ?? finishedNames[id] ?? "Agent", minutes, present == nil, present?.state)
        }
        for s in sessions { finishedNames[s.kind.id] = s.kind.name }
    }

    func addWatched(_ app: WatchedApp) {
        guard !config.watchedApps.contains(app) else { return }
        update { $0.watchedApps.append(app) }
    }

    func removeWatched(_ app: WatchedApp) { update { $0.watchedApps.removeAll { $0 == app } } }

    /// Running apps that could be added to the watch list, most power-hungry first.
    var addableApps: [WatchedApp] {
        let taken = Set(config.watchedApps.map(\.id))
        let regular = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { a -> WatchedApp? in
                guard let path = a.bundleURL?.path else { return nil }
                return WatchedApp(id: path, name: a.localizedName ?? (path as NSString).lastPathComponent)
            }
        let order = Dictionary(apps.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        return regular.filter { !taken.contains($0.id) }.sorted { (order[$0.id] ?? 999) < (order[$1.id] ?? 999) }
    }

    /// For the phone panel: apps already kept awake for, then the busiest open apps to pick from.
    var watchCandidates: [(app: WatchedApp, on: Bool)] {
        config.watchedApps.map { ($0, true) } + addableApps.prefix(8).map { ($0, false) }
    }

    /// Whether an agent keeps the Mac awake (false: shown, but only tracked).
    func setKeepsAwake(_ kindID: String, _ keeps: Bool) {
        update { c in
            c.trackOnly.removeAll { $0 == kindID }
            if !keeps { c.trackOnly.append(kindID) }
        }
    }

    func toggleTrackOnly(_ kindID: String) {
        update { c in
            if let i = c.trackOnly.firstIndex(of: kindID) { c.trackOnly.remove(at: i) } else { c.trackOnly.append(kindID) }
        }
    }
}
