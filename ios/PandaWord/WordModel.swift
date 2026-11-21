import Foundation
import Combine
import CommonCrypto
import AVFoundation
import Security

typealias JSON = [String: Any]
struct AppFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
enum TokenStore {
    static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.pandaword.native", kSecAttrAccount as String: "token"]
    static func read() -> String {
        var q = query; q[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ token: String) throws {
        SecItemDelete(query as CFDictionary)
        if token.isEmpty { return }
        var q = query; q[kSecValueData as String] = Data(token.utf8)
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw AppFailure(message: "无法安全保存登录凭证") }
    }
}
// Compatible with the legacy CryptoJS AES/CBC/ZeroPadding wire format.
func encrypt(_ text: String) throws -> String {
    let key = Array("gww417038_x8888x".utf8)
    var input = Array(text.utf8)
    if input.count % 16 != 0 { input += Array(repeating: 0, count: 16 - input.count % 16) }
    var output = [UInt8](repeating: 0, count: input.count + 16)
    var written = 0
    let status = key.withUnsafeBytes { k in input.withUnsafeBytes { i in output.withUnsafeMutableBytes { o in
        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(0), k.baseAddress, key.count, k.baseAddress, i.baseAddress, input.count, o.baseAddress, o.count, &written)
    } } }
    guard status == kCCSuccess else { throw AppFailure(message: "登录数据加密失败") }
    return Data(output.prefix(written)).base64EncodedString()
}

@MainActor final class WordModel: ObservableObject {
    @Published var token = TokenStore.read()
    @Published var baseURL = UserDefaults.standard.string(forKey: "apiURL") ?? "http://47.97.107.100:8088/api/"
    @Published var busy = false
    @Published var message = ""
    @Published var profile: JSON = [:]
    @Published var libraries: [JSON] = []
    @Published var words: [JSON] = []
    @Published var records: [JSON] = []
    @Published var queue: [JSON] = []
    @Published var cursor = 0
    @Published var studyLoaded = false
    @Published var revealed = false
    @Published var selectedTab = 0
    private var player: AVPlayer?
    let intervals = [1,1,2,4,7,15,30,45,60,90,135,180,210,270,300,365,545,730,1095,1460]
    var current: JSON? { cursor < queue.count ? queue[cursor] : nil }
    func run(_ work: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task { defer { busy = false }; do { try await work() } catch { message = error.localizedDescription } }
    }
    func post(_ endpoint: String, _ body: Any = JSON()) async throws -> Any {
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), ["http", "https"].contains(url.scheme ?? "") else { throw AppFailure(message: "接口地址无效") }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw AppFailure(message: "服务器请求失败") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? JSON else { throw AppFailure(message: "服务器返回格式无效") }
        if (json["errorCode"] as? Int) == 1000 && (json["subCode"] as? Int) == 1 { try TokenStore.save(""); token = ""; clearUser() }
        guard (json["code"] as? Int) == 200 || (json["status"] as? Int) == 0 else { throw AppFailure(message: json["subMessage"] as? String ?? json["errorMessage"] as? String ?? "请求失败") }
        return json["data"] ?? NSNull()
    }
    func authenticate(mode: Int, mobile: String, password: String, name: String, code: String) async throws {
        guard mobile.range(of: "^[0-9]{11}$", options: .regularExpression) != nil, password.count >= 6 else { throw AppFailure(message: "请输入11位手机号和至少6位密码") }
        if mode != 0 && code.isEmpty { throw AppFailure(message: "请输入验证码") }
        if mode == 1 && name.isEmpty { throw AppFailure(message: "请输入昵称") }
        var body: JSON = ["mobile": try encrypt(mobile), "password": try encrypt(password)]
        if mode != 0 { body["verificationCode"] = code }
        if mode == 1 { body["username"] = name; body["roles"] = "editor"; body["avatar"] = "https://lemoncity.oss-cn-shanghai.aliyuncs.com/avatar/avater01.png" }
        let result = try await post(mode == 0 ? "user/login" : mode == 1 ? "user/register" : "user/change/password", body)
        if mode == 0 {
            guard let value = result as? String, !value.isEmpty else { throw AppFailure(message: "登录未返回凭证") }
            try TokenStore.save(value); token = value
        } else { message = mode == 1 ? "注册成功，请登录" : "密码已修改，请登录" }
    }
    func loadStudy() async throws {
        studyLoaded = false
        profile = try await post("user/info") as? JSON ?? [:]
        let result = try await post("userWordRecord/load") as? JSON ?? [:]
        let raw = result["recordComplete"] as? String ?? "[]"
        records = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [JSON] ?? []
        if (profile["vip"] as? Int ?? 0) == 0 && records.count > 200 { throw AppFailure(message: "普通会员最多学习200个单词，请在我的页面查看会员状态") }
        let due = records.filter { item in
            let level = item["level"] as? Int ?? 0
            guard intervals.indices.contains(level) else { return false }
            return Date().timeIntervalSince1970 * 1000 - (item["reviewTime"] as? Double ?? 0) >= Double(intervals[level]) * 86_400_000
        }
        var details: [JSON] = []
        if !due.isEmpty { details = try await post("userWordRecord/load/adv", due) as? [JSON] ?? [] }
        queue = details; cursor = 0; revealed = false; studyLoaded = true
    }
    func grade(_ delta: Int?) async throws {
        guard let word = current?["word"] as? String, let index = records.firstIndex(where: { $0["word"] as? String == word }) else { throw AppFailure(message: "学习记录与单词不匹配，请刷新") }
        var next = records
        next[index]["level"] = delta.map { min(12, max(0, (next[index]["level"] as? Int ?? 0) + $0)) } ?? 0
        next[index]["reviewTime"] = Date().timeIntervalSince1970 * 1000
        try await save(next); records = next; cursor += 1; revealed = false
    }
    func save(_ values: [JSON]) async throws {
        let data = try JSONSerialization.data(withJSONObject: values)
        _ = try await post("userWordRecord/update", ["recordComplete": String(decoding: data, as: UTF8.self)])
    }
    func editTranslation(_ text: String) async throws {
        guard let word = current?["word"] as? String, let index = records.firstIndex(where: { $0["word"] as? String == word }) else { return }
        var next = records; next[index]["translation"] = text
        try await save(next); records = next; queue[cursor]["translation"] = text
    }
    func speak() async throws {
        guard let word = current?["word"] as? String else { return }
        let value = try await post("userWordRecord/soundMark", ["soundMark": "AmericanEnglishMp3/\(word)_us.mp3"])
        guard let string = value as? String, let url = URL(string: string), ["http", "https"].contains(url.scheme ?? "") else { throw AppFailure(message: "发音地址无效") }
        player = AVPlayer(url: url); player?.play()
    }
    func clearUser() { profile = [:]; records = []; queue = []; libraries = []; words = []; player?.pause() }
    func logout() async throws { _ = try await post("user/logout"); try TokenStore.save(""); token = ""; clearUser() }
    func dictionaryContent(_ item: JSON) -> JSON {
        let vocabulary = item["vocabulary"] as? JSON ?? [:]
        return (vocabulary["content"] as? String).flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? JSON } ?? [:]
    }
    func officialDefinition(_ item: JSON) -> String {
        let basic = dictionaryContent(item)["basic"] as? JSON ?? [:]
        return (basic["explains"] as? [String] ?? []).joined(separator: "\n")
    }
    func phrases(_ item: JSON) -> String {
        (dictionaryContent(item)["web"] as? [JSON] ?? []).map { ($0["key"] as? String ?? "") + "：" + (($0["value"] as? [String] ?? []).joined(separator: "；")) }.joined(separator: "\n")
    }
    func definition(_ item: JSON) -> String {
        let vocabulary = item["vocabulary"] as? JSON ?? [:]
        let content = (vocabulary["content"] as? String).flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? JSON } ?? [:]
        let basic = content["basic"] as? JSON ?? [:]
        let explains = basic["explains"] as? [String] ?? []
        let phrases = (content["web"] as? [JSON] ?? []).map { entry in
            (entry["key"] as? String ?? "") + "：" + ((entry["value"] as? [String])?.joined(separator: "；") ?? "")
        }
        return (explains + phrases).joined(separator: "\n")
    }
}
