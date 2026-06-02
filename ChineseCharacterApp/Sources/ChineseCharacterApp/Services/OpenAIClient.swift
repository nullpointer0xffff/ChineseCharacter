import Foundation

struct OpenAIClient {
    var apiKey: String
    var session: URLSession = .shared

    func transcribe(audioURL: URL) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(
            boundary: boundary,
            fields: [
                "model": "gpt-4o-transcribe",
                "language": "zh",
                "response_format": "json"
            ],
            fileURL: audioURL,
            fileFieldName: "file",
            mimeType: "audio/m4a"
        )

        let data = try await send(request)
        let response = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractTargetText(from transcript: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: extractionPayload(transcript: transcript))

        let data = try await send(request)
        let outputText = try responseOutputText(from: data)
        let extraction = try JSONDecoder().decode(ExtractionResponse.self, from: Data(outputText.utf8))
        return extraction.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = apiErrorMessage(from: data) ?? "OpenAI 请求失败：HTTP \(httpResponse.statusCode)"
            throw OpenAIClientError.api(message)
        }
        return data
    }

    private func apiErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return String(data: data, encoding: .utf8)
        }

        return "OpenAI 请求失败：\(message)"
    }

    private func extractionPayload(transcript: String) -> [String: Any] {
        [
            "model": "gpt-5.2",
            "reasoning": [
                "effort": "none"
            ],
            "input": [
                [
                    "role": "system",
                    "content": [
                        [
                            "type": "input_text",
                            "text": """
                            你是儿童中文书写 app 的文本提取器。用户会用中文语音问“某句话怎么写”。
                            只提取用户真正想学习书写的中文内容，不要包含“怎么写”“我想学”“请问”等询问语。
                            如果用户说“我想去公园怎么写”，target_text 必须是“我想去公园”。
                            只输出符合 schema 的 JSON。
                            """
                        ]
                    ]
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": transcript
                        ]
                    ]
                ]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "learning_text_extraction",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "target_text": [
                                "type": "string",
                                "description": "用户真正想显示并学习书写的中文，可以是一个字、词语或一句话。"
                            ]
                        ],
                        "required": ["target_text"]
                    ]
                ]
            ]
        ]
    }

    private func multipartBody(
        boundary: String,
        fields: [String: String],
        fileURL: URL,
        fileFieldName: String,
        mimeType: String
    ) throws -> Data {
        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private func responseOutputText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        if let text = findOutputText(in: object) {
            return text
        }
        throw OpenAIClientError.missingOutputText
    }

    private func findOutputText(in object: Any) -> String? {
        if let dictionary = object as? [String: Any] {
            if dictionary["type"] as? String == "output_text", let text = dictionary["text"] as? String {
                return text
            }
            if let outputText = dictionary["output_text"] as? String {
                return outputText
            }
            for value in dictionary.values {
                if let text = findOutputText(in: value) {
                    return text
                }
            }
        }

        if let array = object as? [Any] {
            for item in array {
                if let text = findOutputText(in: item) {
                    return text
                }
            }
        }

        return nil
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

private struct ExtractionResponse: Decodable {
    let targetText: String

    enum CodingKeys: String, CodingKey {
        case targetText = "target_text"
    }
}

enum OpenAIClientError: LocalizedError {
    case invalidResponse
    case missingOutputText
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "OpenAI 返回了无效响应。"
        case .missingOutputText:
            return "OpenAI 响应中没有找到可解析的文本。"
        case .api(let message):
            return message
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
