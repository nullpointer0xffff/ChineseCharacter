import Foundation

struct BackendClient {
    var baseURL: URL
    var deviceID: String
    var userEmail: String? = nil
    var session: URLSession = .shared

    func extractLearningText(audioURL: URL) async throws -> BackendExtractionResult {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "/api/voice/extract"))
        request.httpMethod = "POST"
        addIdentityHeaders(to: &request)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(boundary: boundary, fileURL: audioURL)

        let data = try await send(request)
        return try JSONDecoder().decode(BackendExtractionResult.self, from: data)
    }

    func fetchUsage() async throws -> BackendUsage {
        var request = URLRequest(url: baseURL.appending(path: "/api/me"))
        addIdentityHeaders(to: &request)

        let data = try await send(request)
        return try JSONDecoder().decode(BackendUsage.self, from: data)
    }

    func recordSession() async throws -> BackendUsage {
        var request = URLRequest(url: baseURL.appending(path: "/api/session"))
        request.httpMethod = "POST"
        addIdentityHeaders(to: &request)

        let data = try await send(request)
        return try JSONDecoder().decode(BackendUsage.self, from: data)
    }

    private func addIdentityHeaders(to request: inout URLRequest) {
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-Id")
        if let userEmail, !userEmail.isEmpty {
            request.setValue(userEmail, forHTTPHeaderField: "X-User-Email")
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = apiErrorMessage(from: data) ?? "后端请求失败：HTTP \(httpResponse.statusCode)"
            throw BackendClientError.api(message)
        }
        return data
    }

    private func apiErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["error"] as? String
        else {
            return String(data: data, encoding: .utf8)
        }

        return message
    }

    private func multipartBody(boundary: String, fileURL: URL) throws -> Data {
        var body = Data()
        appendText("--\(boundary)\r\n", to: &body)
        appendText("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileURL.lastPathComponent)\"\r\n", to: &body)
        appendText("Content-Type: audio/m4a\r\n\r\n", to: &body)
        body.append(try Data(contentsOf: fileURL))
        appendText("\r\n--\(boundary)--\r\n", to: &body)
        return body
    }

    private func appendText(_ string: String, to data: inout Data) {
        data.append(Data(string.utf8))
    }
}

struct BackendExtractionResult: Decodable {
    let transcript: String
    let targetText: String
    let remainingCredits: Int
    let accountType: String?
    let isVip: Bool?
}

struct BackendUsage: Decodable {
    let email: String?
    let accountType: String?
    let remainingCredits: Int
    let isVip: Bool?
    let isBlocked: Bool?
    let loginCount: Int?
    let totalUsageCount: Int?
}

enum BackendClientError: LocalizedError {
    case invalidResponse
    case invalidBaseURL
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "后端返回了无效响应。"
        case .invalidBaseURL:
            return "请先在设置里填写 Vercel 后端地址。"
        case .api(let message):
            return message
        }
    }
}
