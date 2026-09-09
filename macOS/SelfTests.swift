import AppKit
import WebKit

// Generated mechanics-only placeholders, never a question collection or saved API data.
final class StubProtocol: URLProtocol {
    static var code = 0, count = 3, status = 200
    static var failure: URLError.Code?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let failure = Self.failure { client?.urlProtocol(self, didFailWithError: URLError(failure)); return }
        let row: [String: Any] = ["question": "Test%20prompt", "category": "Test", "difficulty": "easy", "correct_answer": "A", "incorrect_answers": ["B", "C", "D"]]
        let data = try! JSONSerialization.data(withJSONObject: ["response_code": Self.code, "results": Array(repeating: row, count: Self.count)])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
struct TestFailure: Error { let description: String }
@MainActor extension AppDelegate {
    func check(_ condition: Bool, _ description: String) throws { if !condition { throw TestFailure(description: description) }; print("PASS: \(description)") }
    func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
    func js(_ source: String) async throws -> Any? {
        guard let web else { throw TestFailure(description: "Missing web view") }
        return try await withCheckedThrowingContinuation { continuation in web.evaluateJavaScript(source) { result, error in if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: result) } } }
    }
    func waitFor(_ predicate: () -> Bool, seconds: Double = 30) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !predicate() && Date() < deadline { await wait(0.1) }
        try check(predicate(), "Asynchronous operation completed")
    }
    func capture(_ name: String) {
        guard CommandLine.arguments.contains("--screenshots"), let view = panel?.contentView ?? window?.contentView else { return }
        view.layoutSubtreeIfNeeded(); view.needsDisplay = true; view.display()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rabbit-hole-qa")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: dir.appendingPathComponent(name + ".png")) }
    }
    func runTests(online: Bool) async {
        do {
            await wait(0.7); capture("launcher")
            try check(interval == 900, "Default interval is 15 minutes")
            try check(window?.isRestorable == false && !applicationShouldSaveSecureApplicationState(NSApp), "Window and application state restoration disabled")
            startBackground(); await wait(0.8); interval = 0.3; scheduleNext()
            let wasActive = NSApp.isActive, key = NSApp.keyWindow
            try await waitFor({ turn.phase == .teaser }, seconds: 3)
            try check(NSApp.isActive == wasActive && NSApp.keyWindow === key, "Scheduled teaser does not activate app or take key focus")
            try check(window == nil && panel != nil, "Background mode closes main window and shows native panel")
            capture("teaser"); let bottom = panel!.frame.minY
            expand(); await wait(0.4); capture("categories")
            try check(abs(panel!.frame.minY - bottom) < 0.5 && panel!.frame.height > 120, "Panel expands upward from screen edge (bottom \(bottom) → \(panel!.frame.minY))")
            if online {
                fetchTurn("17")
                try await waitFor({ turn.phase == .question || (turn.phase == .category && !turn.message.isEmpty) }, seconds: 65)
                try check(turn.questions.count == 3, "Live category fetch returns exactly three questions in memory")
            } else {
                let row = APIQuestion(question: "Test%20prompt", category: "Test", difficulty: "easy", correct_answer: "A", incorrect_answers: ["B", "C", "D"])
                turn.load(try (0..<3).map { _ in try Question(row) })
            }
            for i in 0..<3 {
                try check(turn.index == i && turn.selected == nil, "Question \(i + 1)/3 is ready")
                let correct = turn.question!.choices.firstIndex(where: { $0.correct })!
                answer(correct); let points = turn.score; answer(correct)
                try check(turn.selected == correct && turn.score == points, "Answer feedback and duplicate-answer guard \(i + 1)/3")
                if !online { await wait(0.2); capture("feedback-\(i + 1)") }
                next()
            }
            try check(turn.phase == .result && turn.correct == 3 && turn.questions.isEmpty, "Third answer automatically shows result and discards questions")
            if !online { try check(turn.score == 375, "Turn scoring includes streak bonuses"); await wait(0.3); capture("result") }
            interval = 30
            // Exercise the actual eight-second result expiry, animation and reschedule.
            try await waitFor({ turn.phase == .closed }, seconds: 10)
            try check(panel == nil && turn.questions.isEmpty && nextDue != nil, "Result expires, fades, clears memory and schedules next interval")
            try check(nextDue!.timeIntervalSinceNow > 29, "Interval starts after fade closes the turn")
            togglePause(); try check(paused && reminder == nil && nextDue == nil, "Pause cancels reminders")
            questionNow(); try check(turn.phase == .teaser && paused, "Manual turn while paused does not resume reminders")
            dismiss(); try check(reminder == nil, "Dismissed paused turn stays paused")
            togglePause(); try check(!paused && reminder != nil, "Resume starts a fresh interval")
            showReminder(); expand(); fetchTurn("15"); dismiss()
            try check(request == nil && turn.questions.isEmpty, "Dismiss cancels in-flight request and clears memory")
            willSleep(); try check(sleeping && reminder == nil && panel == nil, "Sleep cancels reminder and panel")
            didWake(); didWake(); try check(!sleeping && nextDue != nil && turn.phase == .closed, "Repeated wake schedules one future reminder without backlog")
            playNow(); try check(reminder == nil && nextDue == nil, "Normal play suspends background reminders")
            try await waitFor({ web != nil && web?.isLoading == false }, seconds: 15)
            await wait(1)
            if online {
                _ = try await js("$('difficulty').value='easy'; $('pace').value='0'; start(); undefined")
                var ready = false
                for _ in 0..<650 { if try await js("screen") as? String != "loading" { ready = true; break }; await wait(0.1) }
                try check(ready, "Live normal round request completed")
                try check(try await js("questions.length") as? Int == 10, "Live normal game fetched ten questions through native bridge")
            } else {
                _ = try await js("window.rabbitHoleFetch=async()=>({ok:true,status:200,json:async()=>({response_code:0,results:Array.from({length:10},()=>({question:'Test%20prompt',category:'Test',difficulty:'easy',correct_answer:'A',incorrect_answers:['B','C','D']}))})}); $('pace').value='0'; start(); undefined")
                await wait(0.3)
            }
            _ = try await js("$('lifeline').click(); undefined")
            try check(try await js("[...$('answers').children].filter(b=>b.disabled).length") as? Int == 2, "Normal 50/50 eliminates two wrong answers")
            _ = try await js("for(let i=0;i<10;i++){answer(questions[index].answers.findIndex(a=>a.correct));next();} undefined")
            try check(try await js("screen") as? String == "result", "Normal ten-question game completes")
            try check(try await js("questions.length") as? Int == 0, "Normal completed round clears memory")
            if !online {
                try check(try await js("score") as? Int == 1875, "Normal scoring and streaks preserved")
                _ = try await js("home(); $('pace').value='20'; lastFetch=0; start(); undefined"); await wait(0.2)
                _ = try await js("deadline=0; answer(questions[index].answers.findIndex(a=>a.correct)); undefined")
                try check(try await js("answered && score===0") as? Bool == true, "Timed game rejects answers after deadline")
                _ = try await js("home(); $('pace').value='0'; lastFetch=0; start(); undefined"); await wait(0.2)
                _ = try await js("answer(questions[index].answers.findIndex(a=>!a.correct)); undefined")
                try check(try await js("score===0 && $('feedback').className.includes('bad')") as? Bool == true, "Normal wrong-answer feedback")
                _ = try await js("home(); window.rabbitHoleFetch=async()=>{throw new TypeError('offline')}; lastFetch=0; start(); undefined"); await wait(0.2)
                try check(try await js("screen") as? String == "error", "Normal network failure offers retry")
                _ = try await js("home(); undefined")
                await wait(0.3)
                if CommandLine.arguments.contains("--screenshots"), let image = try? await web?.takeSnapshot(configuration: nil), let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rabbit-hole-qa/normal.png")) }
                try await testNetworkFailures()
                startBackground(); showReminder(); expand()
                let long = Array(repeating: "Long layout placeholder with punctuation & accents — café.", count: 12).joined(separator: " ")
                let row = APIQuestion(question: long, category: "Synthetic layout test", difficulty: "hard", correct_answer: String(repeating: "Long answer placeholder. ", count: 8), incorrect_answers: ["B", "C", "D"])
                turn.load(try (0..<3).map { _ in try Question(row) }); await wait(0.3); capture("long-question")
                func scrollView(_ view: NSView) -> NSScrollView? {
                    if let scroll = view as? NSScrollView { return scroll }
                    return view.subviews.compactMap { scrollView($0) }.first
                }
                if let scroll = scrollView(panel!.contentView!), let document = scroll.documentView {
                    try check(document.bounds.height > scroll.contentView.bounds.height, "Long question content is scrollable")
                    document.scroll(NSPoint(x: 0, y: document.bounds.maxY)); await wait(0.3); capture("long-answers")
                }
                try check(panel!.frame.maxY <= (panelScreen?.visibleFrame.maxY ?? .infinity), "Long question panel remains within visible screen")
                answer(turn.question!.choices.firstIndex(where: { !$0.correct })!)
                try check(turn.score == 0 && turn.selected != nil, "Background wrong answer reveals feedback without points")
                next(); await wait(0.3); capture("long-next")
            }
            interval = 900; background = false; dismiss(); clearMain()
            try check(interval == 900 && reminder == nil && panel == nil && web == nil, "Default restored and windows/tasks cleaned up")
            print("ALL \(online ? "ONLINE" : "OFFLINE") MACOS TESTS PASSED")
            quit()
        } catch {
            print("FAIL: \(error)")
            applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            exit(1)
        }
    }
    func testNetworkFailures() async throws {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [StubProtocol.self]
        let client = TriviaService(configuration: configuration)
        _ = try await client.fetch(amount: 3, category: "")
        try check(client.session.configuration.urlCache == nil && client.session.configuration.httpCookieStorage == nil, "Native networking has no response cache or cookies")
        for code in [1, 2, 5] {
            StubProtocol.code = code; client.nextRequest = .distantPast
            do { _ = try await client.fetch(amount: 3, category: ""); throw TestFailure(description: "Expected API error \(code)") }
            catch is TriviaError { print("PASS: API response code \(code)") }
        }
        StubProtocol.code = 0; StubProtocol.status = 429; client.nextRequest = .distantPast
        do { _ = try await client.fetch(amount: 3, category: ""); throw TestFailure(description: "Expected HTTP 429") } catch is TriviaError { print("PASS: HTTP 429 bounded retries") }
        StubProtocol.status = 200; StubProtocol.count = 2; client.nextRequest = .distantPast
        do { _ = try await client.fetch(amount: 3, category: ""); throw TestFailure(description: "Expected incomplete response") } catch is TriviaError { print("PASS: Incomplete batch rejected") }
        StubProtocol.count = 3
        for failure in [URLError.Code.notConnectedToInternet, .timedOut] {
            StubProtocol.failure = failure; client.nextRequest = .distantPast
            do { _ = try await client.fetch(amount: 3, category: ""); throw TestFailure(description: "Expected network failure") } catch is URLError { print("PASS: Offline/timeout returned without blocking UI") }
        }
        StubProtocol.failure = nil; client.session.invalidateAndCancel()
    }
}
