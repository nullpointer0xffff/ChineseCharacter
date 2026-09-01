import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var deviceIdentity: DeviceIdentityStore
    @ObservedObject var accountStore: AccountStore

    @StateObject private var purchaseStore = PurchaseStore()
    @State private var emailDraft = ""
    @State private var remainingCredits: Int?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.93).ignoresSafeArea()

                Form {
                    Section("账号") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(accountStore.isRegistered ? "邮箱账号" : "Guest 模式")
                                .font(.headline)
                            Text(accountStore.normalizedEmail ?? "免费 10 次；注册邮箱后免费 20 次")
                                .foregroundStyle(.secondary)
                            if let remainingCredits {
                                Text("剩余额度：\(remainingCredits) 次")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.10, green: 0.40, blue: 0.36))
                            }
                        }

                        TextField("输入邮箱注册", text: $emailDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)

                        Button(accountStore.isRegistered ? "更新邮箱账号" : "注册邮箱账号") {
                            Task { await registerEmail() }
                        }
                        .disabled(isLoading)

                        if accountStore.isRegistered {
                            Button("切回 Guest 模式") {
                                accountStore.signOutToGuest()
                                emailDraft = ""
                                Task { await refreshAccount(recordLogin: true) }
                            }
                            .foregroundStyle(.red)
                            .disabled(isLoading)
                        }
                    }

                    Section("购买") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("100 次练习包")
                                .font(.headline)
                            Text("一次性购买，适合继续试用和小范围内测。")
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            Task { await buyCredits() }
                        } label: {
                            HStack {
                                Text("购买 100 次")
                                Spacer()
                                Text(purchaseStore.creditPack?.displayPrice ?? "$0.99")
                            }
                        }
                        .disabled(isLoading || purchaseStore.isLoading || purchaseStore.isPurchasing || purchaseStore.creditPack == nil)

                        if purchaseStore.creditPack == nil {
                            Text("如果这里暂时不可购买，请先在 App Store Connect 创建商品 com.jiehu.ChineseCharacter.credits100。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Text("OpenAI API key 只保存在后端，App 不会保存或显示 key。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let statusMessage {
                        Section {
                            Text(statusMessage)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                emailDraft = accountStore.email
                Task { await refreshAccount(recordLogin: false) }
                Task { await purchaseStore.loadProducts() }
            }
            .alert("需要处理一下", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func registerEmail() async {
        let email = emailDraft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
            errorMessage = "请输入有效的邮箱地址。"
            return
        }

        accountStore.email = email
        await refreshAccount(recordLogin: true)
    }

    private func refreshAccount(recordLogin: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let client = BackendClient(
                baseURL: AppEnvironment.backendBaseURL,
                deviceID: deviceIdentity.deviceID,
                userEmail: accountStore.normalizedEmail
            )
            let usage = recordLogin ? try await client.recordSession() : try await client.fetchUsage()
            remainingCredits = usage.remainingCredits
            statusMessage = accountStore.isRegistered ? "邮箱账号已同步。" : "Guest 账号已同步。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buyCredits() async {
        let client = BackendClient(
            baseURL: AppEnvironment.backendBaseURL,
            deviceID: deviceIdentity.deviceID,
            userEmail: accountStore.normalizedEmail
        )

        do {
            let result = try await purchaseStore.buyCreditPack(client: client)
            remainingCredits = result.remainingCredits
            statusMessage = result.addedCredits > 0 ? "购买成功，已增加 \(result.addedCredits) 次。" : "这笔购买已经兑换过，额度已同步。"
        } catch PurchaseStoreError.cancelled {
            statusMessage = "购买已取消。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
