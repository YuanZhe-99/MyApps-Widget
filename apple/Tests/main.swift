import Foundation

// Contract check for MyAppsWidgetKit, run by tool/check_swift_contract.sh. Named main.swift
// so it may hold top-level code; swiftc compiles this file together with MyAppsWidgetKit.swift and runs it
// from the repository root. Exits non-zero on the first mismatch.

/// Purpose: Stop with a message when a check fails.
/// Inputs: `ok`, `message`.
/// Returns: None.
/// Side effects: Exits the process on failure.
/// Notes: None.
func check(_ ok: Bool, _ message: @autoclosure () -> String) {
  if !ok {
    FileHandle.standardError.write((message() + "\n").data(using: .utf8)!)
    exit(1)
  }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("contract")
let expectationsData = try! Data(contentsOf: root.appendingPathComponent("expectations.json"))
let expectations = try! JSONSerialization.jsonObject(with: expectationsData) as! [String: Any]
let kind = expectations["expectedKind"] as! String
let cases = expectations["cases"] as! [String: [String: Any]]
let files = Set(try! FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("fixtures").path))
check(files == Set(cases.keys), "fixtures and expectations differ")

for (name, want) in cases.sorted(by: { $0.key < $1.key }) {
  let raw = try! String(contentsOf: root.appendingPathComponent("fixtures/\(name)"), encoding: .utf8)
  let read = WidgetEnvelopeRead.decode(raw, expectedKind: kind)
  check("\(read.status)" == want["status"] as! String, "\(name): status \(read.status)")
  guard let e = read.envelope else { continue }
  check(e.payloadVersion == want["payloadVersion"] as! Int, "\(name): pv")
  check(e.generatedAt == (want["generatedAt"] as! NSNumber).int64Value, "\(name): generatedAt")
  check(abs(e.textScale - (want["textScale"] as! NSNumber).doubleValue) < 1e-9, "\(name): textScale")
  check(e.privacy.rawValue == want["privacy"] as! String, "\(name): privacy")
  check(e.refreshAt == (want["refreshAt"] as! [NSNumber]).map { $0.int64Value }, "\(name): refreshAt")
  check(e.instanceId == want["instanceId"] as? String, "\(name): instanceId")
}
check(WidgetEnvelopeRead.decode(nil).status == .missing, "nil input")
check(WidgetEnvelopeRead.decode("").status == .missing, "empty input")

let actionData = try! Data(contentsOf: root.appendingPathComponent("action_expectations.json"))
let actionCases =
  (try! JSONSerialization.jsonObject(with: actionData) as! [String: Any])["cases"] as! [String: [[String: Any]]]
let actionFiles = Set(try! FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("actions").path))
check(actionFiles == Set(actionCases.keys), "action fixtures and expectations differ")
for (name, want) in actionCases.sorted(by: { $0.key < $1.key }) {
  let raw = try! String(contentsOf: root.appendingPathComponent("actions/\(name)"), encoding: .utf8)
  let read = WidgetActionQueue.decode(raw)
  check(read.count == want.count, "\(name): count \(read.count)")
  for (a, w) in zip(read, want) {
    check(a.id == w["id"] as! String, "\(name): id")
    check(a.kind == w["kind"] as! String, "\(name): kind")
    check(a.action == w["action"] as! String, "\(name): action")
    check(a.at == (w["at"] as! NSNumber).int64Value, "\(name): at")
    check(NSDictionary(dictionary: a.args).isEqual(to: w["args"] as! [String: Any]), "\(name): args")
    check(a.instanceId == w["instanceId"] as? String, "\(name): instanceId")
  }
}
check(WidgetActionQueue.decode(nil).isEmpty, "nil queue")
print("Swift contract verified: \(cases.count) fixtures, \(actionCases.count) action fixtures")
