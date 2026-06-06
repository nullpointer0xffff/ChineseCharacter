import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var deviceIdentity: DeviceIdentityStore
    @ObservedObject var accountStore: AccountStore

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
}
