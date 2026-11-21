import Foundation

struct Vector: Decodable { let plain: String; let base64: String }
let vectorsURL = URL(fileURLWithPath: CommandLine.arguments[1])
let vectors = try JSONDecoder().decode([Vector].self, from: Data(contentsOf: vectorsURL))
for vector in vectors { let actual = try encrypt(vector.plain); precondition(actual == vector.base64, "AES wire format mismatch") }
print("PASS: native CommonCrypto matches all legacy CryptoJS fixtures")
