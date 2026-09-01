import Foundation
import StoreKit

@MainActor
final class PurchaseStore: ObservableObject {
    static let creditPackProductID = "com.jiehu.ChineseCharacter.credits100"

    @Published private(set) var creditPack: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false

    func loadProducts() async {
        guard creditPack == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [Self.creditPackProductID])
            creditPack = products.first(where: { $0.id == Self.creditPackProductID })
        } catch {
            creditPack = nil
        }
    }

    func buyCreditPack(client: BackendClient) async throws -> PurchaseRedemptionResult {
        guard let creditPack else {
            throw PurchaseStoreError.productUnavailable
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await creditPack.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            let redemption = try await client.redeemPurchase(
                productID: transaction.productID,
                transactionJWS: verification.jwsRepresentation
            )
            await transaction.finish()
            return redemption
        case .pending:
            throw PurchaseStoreError.pending
        case .userCancelled:
            throw PurchaseStoreError.cancelled
        @unknown default:
            throw PurchaseStoreError.unknown
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw PurchaseStoreError.unverified
        }
    }
}

enum PurchaseStoreError: LocalizedError {
    case productUnavailable
    case pending
    case cancelled
    case unverified
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "购买项目还没有准备好。请确认 App Store Connect 已创建 100 次包。"
        case .pending:
            return "购买正在等待确认，请稍后再查看额度。"
        case .cancelled:
            return "购买已取消。"
        case .unverified:
            return "购买凭证未通过 Apple 校验。"
        case .unknown:
            return "购买没有完成，请稍后再试。"
        }
    }
}
