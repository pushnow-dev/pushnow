#!/usr/bin/env python3
"""Run production read/cache algorithms in macOS SwiftPM, without an iOS runtime."""
from pathlib import Path
import tempfile, subprocess, hashlib, json
root = Path(__file__).resolve().parents[2]
pkg = Path(tempfile.mkdtemp(prefix='pushnow-read-state-macos-'))
src = pkg/'Sources/JiZhi'; src.mkdir(parents=True)
tests = pkg/'Tests/JiZhiTests'; tests.mkdir(parents=True)
manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ReadStateHarness", platforms: [.macOS(.v14)], products: [], targets: [.target(name: "JiZhi"), .testTarget(name: "JiZhiTests", dependencies: ["JiZhi"])], swiftLanguageModes: [.v6])
'''
(pkg/'Package.swift').write_text(manifest)
hashes = {}
def read(path):
    text = (root/path).read_text(); hashes[path] = hashlib.sha256(text.encode()).hexdigest(); return text
for path in ['JiZhi/Services/Encryption/SecureV2Models.swift','JiZhi/Repositories/NotificationHistoryCache.swift','JiZhi/Services/Storage/EncryptedNotificationCache.swift','JiZhi/Support/ViewState.swift','JiZhi/Services/Networking/APIJSONCoding.swift','JiZhi/ViewModels/HomeRefreshSchedule.swift']:
    (src/Path(path).name).write_text(read(path))
home = read('JiZhi/ViewModels/HomeViewModel.swift')
(src/'InboxViewModel.swift').write_text(home.split('@MainActor\n@Observable\nfinal class DetailViewModel')[0])
feature = read('JiZhi/Models/FeatureItem.swift')
(src/'FeatureItem.swift').write_text('import Foundation\nenum JiZhiPriority: String, Codable, Sendable { case normal, important, urgent, custom }\n'+feature[feature.index('struct InboxItem:'):])
secure = read('JiZhi/Services/Encryption/SecureModels.swift')
(src/'SecureModels.swift').write_text(secure.split('enum SecureFailure:')[0])
for name in ['InboxReadStateTests.swift', 'HomeRefreshTests.swift']:
    (tests/name).write_text(read('JiZhi/Tests/'+name))
(src/'BoundaryStubs.swift').write_text('''import Foundation
import CryptoKit
// Only platform/network/keychain boundaries are stubbed; no read-state/cache algorithm.
enum SecureFailure: Error { case invalid }
enum AppLocalization {
    static func text(_ key: String, locale: Locale) -> String { key }
}
struct APIStatusError: Error { var statusCode: Int }
enum AppError: Error { case repositoryUnavailable; init(_ error: Error) { self = .repositoryUnavailable } }
@MainActor protocol JiZhiRepository { func cachedInbox() -> [InboxItem]?; func loadInbox() async throws -> [InboxItem] }
extension JiZhiRepository { func cachedInbox() -> [InboxItem]? { nil } }
@MainActor final class AuthService { var isVerified = false; var session: AuthSession? }
struct SecureKeyStore {
    func active() throws -> SecureLocalKeys? { nil }
    func deletedMessageIDs(user: String) throws -> Set<String> { [] }
    func read(_ key: String) throws -> Data? { nil }
}
enum ServerEnvironment: Hashable { case production, sandbox
    static var current: Self { .production }
    func key(_ value: String) -> String { self == .production ? value : value + ".sandbox" }
}
@MainActor protocol NotificationCacheKeyStoring { func key(user: String, create: Bool) throws -> Data?; func remove(user: String) throws }
@MainActor final class KeychainNotificationCacheKeys: NotificationCacheKeyStoring {
    init(environment: ServerEnvironment) {}
    func key(user: String, create: Bool) throws -> Data? { fatalError("Tests must inject isolated keys") }
    func remove(user: String) throws { fatalError("Tests must inject isolated keys") }
}
extension String { var jzRelativeLabel: String { self } }
''')
print('Harness:', pkg, flush=True)
(pkg/'source-hashes.json').write_text(json.dumps(hashes, indent=2))
result = subprocess.run(['swift', 'test', '--package-path', str(pkg)], cwd=root)
raise SystemExit(result.returncode)
