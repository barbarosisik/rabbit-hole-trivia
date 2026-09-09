import AppKit
import SwiftUI
import WebKit
import Darwin

let lime = Color(red: 0.84, green: 0.98, blue: 0.51)
let ink = Color(red: 0.067, green: 0.075, blue: 0.059)
let muted = Color(red: 0.66, green: 0.69, blue: 0.61)
let topics = [("", "✳ Everything"), ("15", "⌘ Gaming"), ("20", "ϟ Mythology"), ("18", "⌨ Computers & code"), ("24", "⚑ Politics"), ("23", "⌛ History"), ("21", "◉ Sports"), ("17", "⚛ Science")]

struct APIEnvelope: Decodable { let response_code: Int; let results: [APIQuestion]? }
struct APIQuestion: Decodable {
    let question: String, category: String, difficulty: String, correct_answer: String
    let incorrect_answers: [String]
}
struct Choice { let text: String; let correct: Bool }
struct Question {
    let text: String, category: String, difficulty: String
    let choices: [Choice]
    init(_ raw: APIQuestion) throws {
        func decode(_ s: String) throws -> String {
            guard let value = s.removingPercentEncoding, !value.isEmpty else { throw TriviaError.invalid }
            return value
        }
        guard raw.incorrect_answers.count == 3 else { throw TriviaError.invalid }
        text = try decode(raw.question); category = try decode(raw.category); difficulty = try decode(raw.difficulty)
        choices = try ([Choice(text: decode(raw.correct_answer), correct: true)] + raw.incorrect_answers.map { Choice(text: try decode($0), correct: false) }).shuffled()
    }
}
enum TriviaError: LocalizedError {
    case busy, empty, invalid, unavailable
    var errorDescription: String? {
        switch self {
        case .busy: return "Open Trivia DB is busy. Wait a few seconds, then try again."
        case .empty: return "There aren’t enough questions for this selection. Try another topic or difficulty."
        case .invalid: return "The question service returned an incomplete response. Please try again."
        case .unavailable: return "Couldn’t reach Open Trivia DB. Check your connection and try again."
        }
    }
}

// One shared gate for both modes. No URL cache, cookies, token, history or disk responses.
@MainActor final class TriviaService {
    let session: URLSession
    var nextRequest = Date.distantPast
    init(configuration: URLSessionConfiguration? = nil) {
        let config = configuration ?? URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 18; config.timeoutIntervalForResource = 22
        session = URLSession(configuration: config)
    }
    func fetch(amount: Int, category: String, difficulty: String = "") async throws -> Data {
        guard [3, 10].contains(amount), topics.contains(where: { $0.0 == category }), ["", "easy", "medium", "hard"].contains(difficulty) else { throw TriviaError.invalid }
        for attempt in 0..<3 {
            // Reserve a slot before suspending, so concurrent callers remain spaced apart.
            let start = max(Date(), nextRequest)
            nextRequest = start.addingTimeInterval(5.5)
            let wait = start.timeIntervalSinceNow
            if wait > 0 { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            try Task.checkCancellation()
            var components = URLComponents(string: "https://opentdb.com/api.php")!
            components.queryItems = [URLQueryItem(name: "amount", value: String(amount)), URLQueryItem(name: "type", value: "multiple"), URLQueryItem(name: "encode", value: "url3986")]
            if !category.isEmpty { components.queryItems!.append(URLQueryItem(name: "category", value: category)) }
            if !difficulty.isEmpty { components.queryItems!.append(URLQueryItem(name: "difficulty", value: difficulty)) }
            let (data, response) = try await session.data(from: components.url!)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw TriviaError.unavailable }
            if http.statusCode == 429 { if attempt < 2 { continue }; throw TriviaError.busy }
            guard http.statusCode == 200 else { throw TriviaError.unavailable }
            let envelope = try JSONDecoder().decode(APIEnvelope.self, from: data)
            if envelope.response_code == 5 { if attempt < 2 { continue }; throw TriviaError.busy }
            if envelope.response_code == 1 { throw TriviaError.empty }
            guard envelope.response_code == 0, let rows = envelope.results, rows.count == amount else { throw TriviaError.invalid }
            _ = try rows.map(Question.init)
            return data
        }
        throw TriviaError.busy
    }
}

@MainActor final class Turn: ObservableObject {
    enum Phase { case closed, teaser, category, loading, question, result }
    @Published var phase: Phase = .closed
    @Published var questions: [Question] = []
    @Published var index = 0
    @Published var selected: Int? = nil
    @Published var score = 0
    @Published var correct = 0
    @Published var streak = 0
    @Published var message = ""
    @Published var finalFeedback = ""
    var question: Question? { questions.indices.contains(index) ? questions[index] : nil }
    func reset() { questions = []; index = 0; selected = nil; score = 0; correct = 0; streak = 0; message = ""; finalFeedback = ""; phase = .closed }
    func load(_ rows: [Question]) { reset(); questions = rows; phase = .question }
    func answer(_ choice: Int) {
        guard phase == .question, selected == nil, let q = question, q.choices.indices.contains(choice) else { return }
        selected = choice
        if q.choices[choice].correct {
            correct += 1; streak += 1
            score += (["easy": 100, "medium": 150, "hard": 200][q.difficulty] ?? 100) + min(streak - 1, 5) * 25
        } else { streak = 0 }
        if index == 2 {
            finalFeedback = (q.choices[choice].correct ? "Exactly right!" : "A fact for next time.") + " Correct answer: " + q.choices.first(where: { $0.correct })!.text
            questions = []; phase = .result
        }
    }
    func next() {
        guard phase == .question, selected != nil else { return }
        if index == 2 { questions = []; phase = .result } else { index += 1; selected = nil }
    }
}

struct RabbitButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .medium)).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(primary ? ink : Color.white)
            .background(primary ? lime.opacity(configuration.isPressed ? 0.7 : 1) : Color.white.opacity(configuration.isPressed ? 0.13 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(lime.opacity(primary ? 0.8 : 0.18)))
    }
}
struct Credits: View {
    var body: some View {
        HStack(spacing: 5) { Text("Questions:"); Link("Open Trivia DB", destination: URL(string: "https://opentdb.com/")!); Text("·"); Link("CC BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!) }.font(.system(size: 10)).foregroundStyle(muted).tint(muted)
    }
}
struct Launcher: View {
    let app: AppDelegate
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("rabbit hole ↘").font(.system(size: 27, weight: .heavy)).foregroundStyle(lime)
            Text("Follow your\ncuriosity.").font(.system(size: 46, weight: .bold, design: .serif))
            Text("A little curiosity break.").foregroundStyle(muted)
            Button("Play now  ↘") { app.playNow() }.buttonStyle(RabbitButton(primary: true))
            Text("Ten questions · difficulty · chill or timed · 50/50").font(.system(size: 12)).foregroundStyle(muted)
            Button("Play from background") { app.startBackground() }.buttonStyle(RabbitButton())
            Text("Three questions per turn. A quiet prompt every 15 minutes. Use the ↘ menu-bar icon to pause, change the interval, or quit.").font(.system(size: 13)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
            Credits()
        }.padding(32).frame(width: 490).frame(maxHeight: .infinity).background(ink).foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.91))
    }
}
struct TurnView: View {
    @ObservedObject var turn: Turn
    let app: AppDelegate
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header.frame(height: 26)
            if turn.phase == .teaser {
                Button("Got a minute? Follow a rabbit hole.") { app.expand() }.buttonStyle(RabbitButton(primary: true))
            } else {
                ScrollView {
                        VStack(alignment: .leading, spacing: 13) {
                            if turn.phase == .category || turn.phase == .loading { categories }
                            if let q = turn.question, turn.phase == .question { question(q) }
                            if turn.phase == .result { result }
                            Credits().padding(.top, 8)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                }.clipped()
            }
        }.padding(18).background(ink).foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.91))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(lime.opacity(0.35))).padding(1)
        .id("\(turn.phase)-\(turn.index)")
    }
    var header: some View {
        HStack {
            Text("rabbit hole ↘").font(.system(size: 19, weight: .heavy)).foregroundStyle(lime)
            Spacer()
            Button(action: { app.dismiss() }) { Image(systemName: "xmark") }
                .buttonStyle(.plain).accessibilityLabel("Dismiss turn").help("Dismiss until the next reminder")
        }
    }
    var categories: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Pick your rabbit hole.").font(.system(size: 25, weight: .semibold))
            Text("Three questions. No timer. Just curiosity.").foregroundStyle(muted).font(.system(size: 13))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(topics, id: \.0) { topic in
                    Button(topic.1) { app.fetchTurn(topic.0) }.buttonStyle(RabbitButton()).disabled(turn.phase == .loading)
                }
            }
            if turn.phase == .loading { ProgressView().controlSize(.small) }
            if !turn.message.isEmpty { Text(turn.message).font(.system(size: 13)).foregroundStyle(lime) }
        }
    }
    func question(_ q: Question) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text("QUESTION \(turn.index + 1)/3"); Spacer(); Text("\(turn.score) pts") }
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(lime)
            Text("\(q.category) / \(q.difficulty)").font(.system(size: 11)).foregroundStyle(muted)
            Text(q.text).font(.system(size: 22, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            ForEach(q.choices.indices, id: \.self) { i in answerButton(q, i) }
            if let choice = turn.selected {
                Text(q.choices[choice].correct ? "Exactly right!" : "A fact for next time.").foregroundStyle(lime).fontWeight(.semibold)
                Text("Correct answer: \(q.choices.first(where: { $0.correct })!.text)").fixedSize(horizontal: false, vertical: true)
                Button(turn.index == 2 ? "See turn result →" : "Next question →") { app.next() }.buttonStyle(RabbitButton(primary: true))
            }
        }
    }
    func answerButton(_ q: Question, _ i: Int) -> some View {
        let border: Color = turn.selected != nil && q.choices[i].correct ? lime : turn.selected == i ? Color(red: 1, green: 0.67, blue: 0.63) : .clear
        return Button(action: { app.answer(i) }) {
            HStack(alignment: .top) {
                Text("\(i + 1)").foregroundStyle(muted)
                Text(q.choices[i].text).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if turn.selected != nil && q.choices[i].correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(lime) }
            }
        }.buttonStyle(RabbitButton()).disabled(turn.selected != nil)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(border, lineWidth: 2))
    }
    var result: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("3/3 COMPLETE").font(.system(size: 11, weight: .semibold)).foregroundStyle(lime)
            Text(turn.finalFeedback).fixedSize(horizontal: false, vertical: true).foregroundStyle(lime)
            Text("Back from the rabbit hole").font(.system(size: 24, weight: .semibold))
            Text("\(turn.score)").font(.system(size: 68, weight: .heavy)).foregroundStyle(lime)
            Text("curiosity points · \(turn.correct)/3 correct").foregroundStyle(muted)
            Text(app.paused ? "Reminders are paused. This turn closes in a moment." : "A little wiser. See you in \(app.intervalLabel). This turn closes in a moment.").font(.system(size: 13)).foregroundStyle(muted)
            Button("Done →") { app.dismiss() }.buttonStyle(RabbitButton(primary: true))
        }
    }
}
final class QuietPanel: NSPanel {
    var dismissTurn: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { dismissTurn?() }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
    let turn = Turn(), service = TriviaService()
    var window: NSWindow?, panel: QuietPanel?, web: WKWebView?, status: NSStatusItem?
    var reminder: Timer?, expiry: Timer?, request: Task<Void, Never>?
    var webRequests: [UUID: Task<Void, Never>] = [:]
    var background = false, paused = false, sleeping = false
    var interval: TimeInterval = 900
    var intervalLabel: String { interval < 60 ? "\(Int(interval)) seconds" : "\(Int(interval / 60)) minutes" }
    var nextDue: Date?
    var panelScreen: NSScreen?
    var epoch = 0
    var lockFD: Int32 = -1
    let testing = CommandLine.arguments.contains("--self-test") || CommandLine.arguments.contains("--online-test")
    func applicationDidFinishLaunching(_ notification: Notification) {
        // flock also covers direct executable launches and simultaneous launch races.
        let path = NSTemporaryDirectory() + "rabbit-hole-\(getuid())\(testing ? "-test" : "").lock"
        lockFD = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: "nl.barbarosisik.rabbit-hole") where app.processIdentifier != getpid() { app.activate(options: []) }
            NSApp.terminate(nil); return
        }
        NSApp.appearance = NSAppearance(named: .darkAqua)
        makeMenu()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        nc.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(didWake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        showLauncher()
        if testing { Task { await self.runTests(online: CommandLine.arguments.contains("--online-test")) } }
    }
    func makeMenu() {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector?, _ key: String = "") { let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item) }
        add(background ? (paused ? "Rabbit Hole — paused" : "Rabbit Hole — every \(intervalLabel)") : "Rabbit Hole", nil)
        add("Play now", #selector(playNow)); add("Play from background", #selector(startBackground))
        add("Question turn now", #selector(questionNow)); add(paused ? "Resume reminders" : "Pause reminders", #selector(togglePause))
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Reminder interval", action: nil, keyEquivalent: "")
        let intervals = NSMenu()
        for minutes in [5, 15, 30, 60] { let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(changeInterval(_:)), keyEquivalent: ""); item.tag = minutes; item.target = self; item.state = interval == Double(minutes * 60) ? .on : .off; intervals.addItem(item) }
        settings.submenu = intervals; menu.addItem(settings)
        menu.addItem(.separator()); add("Quit Rabbit Hole", #selector(quit), "q")
        if status == nil { status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength); status?.button?.title = "↘"; status?.button?.setAccessibilityLabel("Rabbit Hole") }
        status?.button?.toolTip = background ? (paused ? "Rabbit Hole — paused" : "Rabbit Hole — background trivia") : "Rabbit Hole"
        status?.menu = menu
        let main = NSMenu(); let root = NSMenuItem(); root.submenu = menu.copy() as? NSMenu; main.addItem(root)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); let em = NSMenu(title: "Edit")
        for (title, action, key) in [("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] { em.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }; edit.submenu = em; main.addItem(edit); NSApp.mainMenu = main
    }
    func mainWindow(size: NSSize) -> NSWindow {
        clearMain()
        NSApp.setActivationPolicy(.regular)
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Rabbit Hole"; w.isRestorable = false; w.isReleasedWhenClosed = false; w.delegate = self; w.backgroundColor = NSColor(red: 0.067, green: 0.075, blue: 0.059, alpha: 1); w.center(); window = w
        return w
    }
    func showLauncher() {
        dismiss(schedule: false); reminder?.invalidate(); reminder = nil; nextDue = nil
        let w = mainWindow(size: NSSize(width: 490, height: 570)); w.styleMask.remove(.resizable)
        w.contentView = NSHostingView(rootView: Launcher(app: self)); w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func clearMain() {
        for task in webRequests.values { task.cancel() }; webRequests.removeAll()
        web?.configuration.userContentController.removeScriptMessageHandler(forName: "trivia")
        web?.stopLoading(); web?.loadHTMLString("", baseURL: nil); web = nil
        window?.delegate = nil; window?.close(); window = nil
    }
    @objc func playNow() {
        dismiss(schedule: false); reminder?.invalidate(); reminder = nil; nextDue = nil
        let w = mainWindow(size: NSSize(width: 1060, height: 840)); w.minSize = NSSize(width: 660, height: 550)
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "trivia")
        let script = """
        window.rabbitHoleFetch = async function(url, options) {
          if (options?.signal?.aborted) throw new DOMException('Aborted', 'AbortError');
          const reply = await window.webkit.messageHandlers.trivia.postMessage(String(url));
          if (options?.signal?.aborted) throw new DOMException('Aborted', 'AbortError');
          return {ok:true, status:200, json:async()=>JSON.parse(reply)};
        };
        """
        config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: config); web = view; view.navigationDelegate = self; w.contentView = view
        let url = Bundle.main.url(forResource: "game", withExtension: "html")!
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame, let body = message.body as? String, let url = URLComponents(string: body), url.scheme == "https", url.host == "opentdb.com", url.path == "/api.php" else { replyHandler(nil, "Invalid request"); return }
        func value(_ key: String) -> String { url.queryItems?.first(where: { $0.name == key })?.value ?? "" }
        let amount = Int(value("amount")) ?? 0, category = value("category"), difficulty = value("difficulty"), id = UUID()
        webRequests[id] = Task {
            defer { webRequests[id] = nil }
            do { let data = try await service.fetch(amount: amount, category: category, difficulty: difficulty); try Task.checkCancellation(); replyHandler(String(decoding: data, as: UTF8.self), nil) }
            catch { replyHandler(nil, error is CancellationError ? "Request cancelled" : error.localizedDescription) }
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.isFileURL { decisionHandler(.allow) } else {
            if ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        }
    }
    @objc func startBackground() {
        background = true; paused = false; clearMain(); NSApp.setActivationPolicy(.accessory); dismiss(); makeMenu()
    }
    @objc func questionNow() {
        background = true; clearMain(); NSApp.setActivationPolicy(.accessory)
        if turn.phase != .closed { return }
        showReminder(); makeMenu()
    }
    func scheduleNext() {
        reminder?.invalidate(); reminder = nil; nextDue = nil
        guard background, !paused, !sleeping, window == nil, turn.phase == .closed else { return }
        nextDue = Date().addingTimeInterval(interval)
        reminder = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.showReminder() } }
    }
    func showReminder() {
        guard !sleeping, turn.phase == .closed else { return }
        reminder?.invalidate(); reminder = nil; nextDue = nil; epoch += 1
        turn.reset(); turn.phase = .teaser
        panelScreen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        let p = QuietPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.dismissTurn = { [weak self] in self?.dismiss() }
        p.isRestorable = false; p.isReleasedWhenClosed = false; p.level = .floating; p.hidesOnDeactivate = false; p.isFloatingPanel = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.backgroundColor = .clear; p.isOpaque = false; p.hasShadow = true
        let hosting = NSHostingView(rootView: TurnView(turn: turn, app: self))
        hosting.sizingOptions = []
        p.contentView = hosting; panel = p
        positionPanel(); p.orderFrontRegardless(); expire(after: 45)
    }
    func expand() { guard turn.phase == .teaser else { return }; turn.phase = .category; positionPanel(animated: true); panel?.makeKey(); expire(after: 300) }
    @objc func screenChanged() { panelScreen = nil; positionPanel() }
    func positionPanel(animated: Bool = false) {
        guard let p = panel, let screen = panelScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let area = screen.visibleFrame
        let width = min(430, area.width - 32), height = min(turn.phase == .teaser ? 120 : 610, area.height - 32)
        p.setFrame(NSRect(x: area.maxX - width - 16, y: area.minY + 16, width: width, height: height), display: true, animate: animated)
    }
    func fetchTurn(_ category: String) {
        guard turn.phase == .category else { return }
        turn.phase = .loading; turn.message = "Finding three fresh questions… This may take a moment if the service is busy."; expire(after: 300)
        let token = epoch
        request = Task {
            do {
                let data = try await service.fetch(amount: 3, category: category)
                let envelope = try JSONDecoder().decode(APIEnvelope.self, from: data)
                let rows = try envelope.results!.map(Question.init)
                guard !Task.isCancelled, epoch == token else { return }
                turn.load(rows); expire(after: 300)
            } catch {
                guard !Task.isCancelled, epoch == token else { return }
                turn.phase = .category; turn.message = error.localizedDescription
            }
            request = nil
        }
    }
    func answer(_ choice: Int) { guard turn.phase == .question, turn.selected == nil else { return }; turn.answer(choice); expire(after: turn.phase == .result ? 8 : 300) }
    func next() { guard turn.phase == .question, turn.selected != nil else { return }; turn.next(); expire(after: 300) }
    func expire(after seconds: TimeInterval) {
        expiry?.invalidate()
        expiry = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.fade() } }
    }
    func fade() {
        expiry?.invalidate(); expiry = nil
        guard let p = panel else { return }; let token = epoch
        NSAnimationContext.runAnimationGroup { context in context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.45; p.animator().alphaValue = 0 } completionHandler: { [weak self] in
            MainActor.assumeIsolated { guard let self, self.epoch == token else { return }; self.dismiss() }
        }
    }
    func dismiss(schedule: Bool = true) {
        epoch += 1; request?.cancel(); request = nil; expiry?.invalidate(); expiry = nil
        panel?.orderOut(nil); panel?.contentView = nil; panel?.close(); panel = nil; turn.reset()
        if schedule { scheduleNext() }
    }
    @objc func togglePause() { paused.toggle(); dismiss(); makeMenu() }
    @objc func changeInterval(_ sender: NSMenuItem) { interval = Double(sender.tag * 60); if turn.phase == .closed { scheduleNext() }; makeMenu() }
    @objc func willSleep() { sleeping = true; dismiss(); reminder?.invalidate(); reminder = nil; nextDue = nil }
    @objc func didWake() { sleeping = false; scheduleNext() }
    func windowWillClose(_ notification: Notification) {
        clearMain()
        if background { NSApp.setActivationPolicy(.accessory); scheduleNext() } else { quit() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { if window == nil { showLauncher() }; return true }
    func applicationShouldSaveSecureApplicationState(_ app: NSApplication) -> Bool { false }
    func applicationShouldRestoreSecureApplicationState(_ app: NSApplication) -> Bool { false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        background = false; dismiss(schedule: false); reminder?.invalidate(); reminder = nil; nextDue = nil; clearMain()
        if let status { NSStatusBar.system.removeStatusItem(status) }; status = nil
        service.session.invalidateAndCancel()
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
    }
}

@main struct RabbitHoleApp {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-test") || CommandLine.arguments.contains("--online-test") { setbuf(stdout, nil) }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
