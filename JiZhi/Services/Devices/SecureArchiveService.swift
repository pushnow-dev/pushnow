import CryptoKit
import Foundation

@MainActor
enum SecureArchiveService {
    static func load(user: String) throws -> SecureArchiveKeys? {
        try SecureKeyStore().read("archive:\(user)").map { try JSONDecoder.api.decode(SecureArchiveKeys.self, from: $0) }
    }

    static func save(_ keys: SecureArchiveKeys, local: SecureLocalKeys) throws {
        guard let identity = local.identityPublicKey else { throw SecureFailure.pending }
        try SecureV2Crypto.verify(keys.archive, user: local.userId, identity: identity)
        let key = try P256.KeyAgreement.PrivateKey(rawRepresentation: keys.privateKey)
        guard key.publicKey.x963Representation.base64EncodedString() == keys.archive.publicKey else { throw SecureFailure.invalid }
        if let pinned = try load(user: local.userId), pinned.archive != keys.archive { throw SecureFailure.invalid }
        try SecureKeyStore().write(JSONEncoder.api.encode(keys), account: "archive:\(local.userId)")
    }

    static func ensure(service: SecureDeviceService) async throws -> SecureArchiveKeys {
        let generation = service.auth.generation
        guard let local = service.keys, let identity = local.identityPublicKey,
              let secret = local.identityPrivateKey, service.trusted else { throw SecureFailure.pending }
        let response: ArchiveResponse = try await service.api.getJSON("/v2/archive", accessToken: await service.auth.requireAccessToken())
        try check(service, local: local, generation: generation)
        if let archive = response.archive {
            try SecureV2Crypto.verify(archive, user: local.userId, identity: identity)
            if let stored = try load(user: local.userId) {
                guard stored.archive == archive else { throw SecureFailure.invalid }
                return stored
            }
            if let data = try service.store.read("archive-provisional:\(local.userId)") {
                let provisional = try JSONDecoder.api.decode(SecureArchiveKeys.self, from: data)
                if provisional.archive == archive {
                    try save(provisional, local: local)
                    try service.store.write(nil, account: "archive-provisional:\(local.userId)")
                    return provisional
                }
                try service.store.write(nil, account: "archive-provisional:\(local.userId)")
            }
            if let transfer = local.archiveTransfer {
                guard transfer.archiveId == archive.id else { throw SecureFailure.invalid }
                let keys = SecureArchiveKeys(archive: archive, privateKey: try SecureCrypto.decode(transfer.archivePrivateKey))
                try save(keys, local: local)
                return keys
            }
            let result: ArchiveGrantResponse = try await service.api.getJSON("/v2/archive/grants/\(local.deviceId)",
                accessToken: await service.auth.requireAccessToken())
            try check(service, local: local, generation: generation)
            guard let grant = result.grant else { throw SecureFailure.pending }
            let transfer: SecureArchiveTransfer = try SecureV2Crypto.openGrant(grant, privateKey: local.privateKey,
                info: "pushnow-archive-grant-v2", aad: SecureV2Crypto.aad([2, "archive-grant", local.userId, local.deviceId, archive.id]))
            guard transfer.archiveId == archive.id else { throw SecureFailure.invalid }
            let keys = SecureArchiveKeys(archive: archive, privateKey: try SecureCrypto.decode(transfer.archivePrivateKey))
            try save(keys, local: local)
            return keys
        }
        guard try load(user: local.userId) == nil else { throw SecureFailure.invalid }
        let key = P256.KeyAgreement.PrivateKey()
        let id = UUID().uuidString.lowercased()
        let publicKey = key.publicKey.x963Representation.base64EncodedString()
        let archive = SecureArchive(id: id, publicKey: publicKey,
            certificate: try SecureCrypto.sign(SecureCrypto.text("archive", user: local.userId, id: id, key: publicKey), privateKey: secret))
        let generated = SecureArchiveKeys(archive: archive, privateKey: key.rawRepresentation)
        let provisional: SecureArchiveKeys
        if let data = try service.store.read("archive-provisional:\(local.userId)") {
            provisional = try JSONDecoder.api.decode(SecureArchiveKeys.self, from: data)
        } else { provisional = generated }
        try service.store.write(JSONEncoder.api.encode(provisional), account: "archive-provisional:\(local.userId)")
        let result: ArchiveResponse
        do {
            result = try await service.api.postJSON("/v2/archive", body: provisional.archive,
                accessToken: await service.auth.requireAccessToken())
        } catch {
            try check(service, local: local, generation: generation)
            let remote: ArchiveResponse = try await service.api.getJSON("/v2/archive", accessToken: await service.auth.requireAccessToken())
            try check(service, local: local, generation: generation)
            guard remote.archive == provisional.archive else {
                if remote.archive != nil { try service.store.write(nil, account: "archive-provisional:\(local.userId)") }
                throw SecureFailure.pending
            }
            result = remote
        }
        try check(service, local: local, generation: generation)
        guard result.archive == provisional.archive else { throw SecureFailure.invalid }
        try save(provisional, local: local)
        try service.store.write(nil, account: "archive-provisional:\(local.userId)")
        return provisional
    }

    static func grant(to device: SecureDevice, service: SecureDeviceService) async throws {
        let archive = try await ensure(service: service)
        guard let local = service.keys, device.userId == local.userId, device.status == "active",
              let certificate = device.certificate, let identity = local.identityPublicKey else { throw SecureFailure.invalid }
        try SecureCrypto.verify(certificate, data: SecureCrypto.text("device", user: local.userId, id: device.id, key: device.publicKey), identity: identity)
        let transfer = SecureArchiveTransfer(archiveId: archive.archive.id, archivePrivateKey: archive.privateKey.base64EncodedString())
        let grant = try SecureV2Crypto.sealGrant(transfer, publicKey: device.publicKey, info: "pushnow-archive-grant-v2",
            aad: SecureV2Crypto.aad([2, "archive-grant", local.userId, device.id, archive.archive.id]))
        try await service.api.postJSONNoResponse("/v2/archive/grants/\(device.id)", body: grant,
            accessToken: await service.auth.requireAccessToken())
    }

    private static func check(_ service: SecureDeviceService, local: SecureLocalKeys, generation: UUID) throws {
        guard service.auth.generation == generation, service.auth.session?.userID == local.userId,
              try service.store.active()?.deviceId == local.deviceId else { throw SecureFailure.invalid }
    }
}

struct ArchiveResponse: Decodable { var archive: SecureArchive? }
private struct ArchiveGrantResponse: Decodable { var grant: SecureApproval? }
