//
//  swift_llm_bridge.swift
//  swift-llm-bridge
//
//  Created by BillyPark on 6/1/25.
//

import Foundation
import Combine

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

public enum LLMTarget: Sendable {
    case ollama
    case lmstudio
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class LLMBridge: ObservableObject {
    
    public struct Message: Identifiable, Equatable {
        public let id = UUID()
        public var content: String
        public let isUser: Bool
        public let timestamp: Date
        public let image: PlatformImage?
        
        public static func == (lhs: Message, rhs: Message) -> Bool {
            return lhs.id == rhs.id
        }
        
        public init(content: String, isUser: Bool, image: PlatformImage? = nil, timestamp: Date = Date()) {
            self.content = content
            self.isUser = isUser
            self.image = image
            self.timestamp = timestamp
        }
    }
    
    @Published public var messages: [Message] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var currentResponse: String = ""
    
    private let baseURL: URL
    private let port: Int
    private let target: LLMTarget
    private var generationTask: Task<Void, Never>?
    private let defaultModel = "llama3.2"
    private var tempResponse: String = ""
    
    private let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300.0
        configuration.timeoutIntervalForResource = 600.0
        configuration.waitsForConnectivity = true
        #if canImport(UIKit)
        configuration.allowsCellularAccess = true
        #endif
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
    
    public init(baseURL: String = "http://localhost", port: Int = 11434, target: LLMTarget = .ollama) {
        guard let url = URL(string: "\(baseURL):\(port)") else {
            fatalError("Invalid base URL")
        }
        self.baseURL = url
        self.port = port
        self.target = target
    }
    
    public func createNewSession(baseURL: String, port: Int, target: LLMTarget) -> LLMBridge {
        return LLMBridge(baseURL: baseURL, port: port, target: target)
    }
    
    public func getAvailableModels() async throws -> [String] {
        let endpoint = getModelsEndpoint()
        let requestURL = baseURL.appendingPathComponent(endpoint)
        
        do {
            let (data, _) = try await urlSession.data(from: requestURL)
            
            switch target {
            case .ollama:
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    return models.compactMap { $0["name"] as? String }
                }
            case .lmstudio:
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [[String: Any]] {
                    return data.compactMap { $0["id"] as? String }
                }
            }
            
            return [defaultModel]
            
        } catch {
            errorMessage = "Failed to fetch model list: \(error.localizedDescription)"
            throw error
        }
    }
    
    public func sendMessage(content: String, image: PlatformImage? = nil, model: String? = nil) async throws -> Message {
        isLoading = true
        errorMessage = nil
        tempResponse = ""
        currentResponse = ""
        
        let userMessage = Message(content: content, isUser: true, image: image)
        messages.append(userMessage)
        
        generationTask?.cancel()
        
        var aiMessage: Message?
        let selectedModel = model ?? defaultModel
        
        generationTask = Task {
            defer { isLoading = false }
            
            do {
                let endpoint = getChatEndpoint()
                let requestURL = baseURL.appendingPathComponent(endpoint)
                var request = URLRequest(url: requestURL)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                if target == .lmstudio {
                    request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
                } else {
                    request.addValue("application/json", forHTTPHeaderField: "Accept")
                }
                
                request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
                request.timeoutInterval = 300.0
                
                let requestData = try createChatRequest(content: content, model: selectedModel, image: image)
                request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
                
                print("Request URL: \(requestURL)")
                print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
                print("Request body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
                
                try await self.processStream(request: request)
                
                if !tempResponse.isEmpty {
                    let message = Message(content: tempResponse, isUser: false, image: nil, timestamp: Date())
                    messages.append(message)
                    aiMessage = message
                    
                    tempResponse = ""
                    currentResponse = ""
                }
                
            } catch {
                errorMessage = error.localizedDescription
                
                if !Task.isCancelled && !tempResponse.isEmpty {
                    let message = Message(content: tempResponse + "\nAn error occurred.", isUser: false, image: nil, timestamp: Date())
                    messages.append(message)
                    aiMessage = message
                    
                    tempResponse = ""
                    currentResponse = ""
                }
            }
        }
        
        await generationTask?.value
        
        return aiMessage ?? Message(content: "Failed to generate response.", isUser: false, image: nil, timestamp: Date())
    }
    
    public func cancelGeneration() {
        generationTask?.cancel()
        
        if !tempResponse.isEmpty {
            let message = Message(content: tempResponse + "\nCancelled by user.", isUser: false, image: nil, timestamp: Date())
            messages.append(message)
            
            tempResponse = ""
            currentResponse = ""
        }
    }
    
    public func clearMessages() {
        messages.removeAll()
        errorMessage = nil
        tempResponse = ""
        currentResponse = ""
    }
    
    private func getModelsEndpoint() -> String {
        switch target {
        case .ollama:
            return "api/tags"
        case .lmstudio:
            return "v1/models"
        }
    }
    
    private func getChatEndpoint() -> String {
        switch target {
        case .ollama:
            return "api/chat"
        case .lmstudio:
            return "v1/chat/completions"
        }
    }
    
    private func createChatRequest(content: String, model: String, image: PlatformImage?) throws -> [String: Any] {
        switch target {
        case .ollama:
            return createOllamaChatRequest(content: content, model: model, image: image)
        case .lmstudio:
            return createLMStudioChatRequest(content: content, model: model, image: image)
        }
    }
    
    private func createOllamaChatRequest(content: String, model: String, image: PlatformImage?) -> [String: Any] {
        var chatMessages: [[String: Any]] = []
        
        for message in messages.dropLast() {
            let role = message.isUser ? "user" : "assistant"
            chatMessages.append(["role": role, "content": message.content])
        }
        
        var currentUserMessage: [String: Any] = [
            "role": "user",
            "content": content
        ]
        
        if let userImage = image,
           let imageBase64 = encodeImageToBase64(userImage) {
            currentUserMessage["images"] = [imageBase64]
        }
        
        chatMessages.append(currentUserMessage)
        
        return [
            "model": model,
            "messages": chatMessages,
            "stream": true,
            "temperature": 0.7,
            "top_p": 0.9,
            "top_k": 40
        ]
    }
    
    private func createLMStudioChatRequest(content: String, model: String, image: PlatformImage?) -> [String: Any] {
        var chatMessages: [[String: Any]] = []
        
        for message in messages.dropLast() {
            let role = message.isUser ? "user" : "assistant"
            let messageDict: [String: Any] = [
                "role": role,
                "content": message.content
            ]
            chatMessages.append(messageDict)
        }
        
        let currentUserMessage: [String: Any] = [
            "role": "user",
            "content": content
        ]
        
        chatMessages.append(currentUserMessage)
        
        return [
            "model": model,
            "messages": chatMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
    }
    
    private func processStream(request: URLRequest) async throws {
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = "Server error: HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "LLMBridgeError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        do {
            for try await line in asyncBytes.lines {
                if Task.isCancelled { break }
                
                if line.isEmpty { continue }
                
                await processStreamLine(line)
            }
        } catch {
            if !Task.isCancelled {
                throw error
            }
        }
    }
    
    private func processStreamLine(_ line: String) async {
        var jsonLine = line
        
        if target == .lmstudio {
            print("LMStudio raw line: '\(line)'")
            
            // LMStudio SSE format processing
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("LMStudio extracted JSON: '\(jsonLine)'")
                
                if jsonLine == "[DONE]" || jsonLine.isEmpty { 
                    print("LMStudio stream finished")
                    return 
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                print("LMStudio skipping SSE metadata: '\(line)'")
                return
            } else if !line.hasPrefix("{") {
                print("LMStudio skipping non-JSON line: '\(line)'")
                return
            }
        }
        
        guard !jsonLine.isEmpty,
              let data = jsonLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Failed to parse JSON: '\(jsonLine)'")
            return
        }
        
        switch target {
        case .ollama:
            await processOllamaStream(json)
        case .lmstudio:
            await processLMStudioStream(json)
        }
    }
    
    private func processOllamaStream(_ json: [String: Any]) async {
        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            tempResponse += content
            currentResponse = tempResponse
            print("Ollama content: \(currentResponse)")
        }
        
        if let done = json["done"] as? Bool, done {
            return
        }
    }
    
    private func processLMStudioStream(_ json: [String: Any]) async {
        print("LMStudio JSON: \(json)")
        
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            print("LMStudio content chunk: '\(content)'")
            tempResponse += content
            currentResponse = tempResponse
            print("LMStudio accumulated: '\(currentResponse)'")
        }
        
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let finishReason = firstChoice["finish_reason"] as? String,
           finishReason == "stop" {
            print("LMStudio stream completed with finish_reason: stop")
            return
        }
    }
    
    private func encodeImageToBase64(_ image: PlatformImage, compressionQuality: CGFloat = 0.8) -> String? {
        #if canImport(UIKit)
        let resizedImage = resizeImageIfNeeded(image, maxSize: 1024)
        guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
        #elseif canImport(AppKit)
        let resizedImage = resizeImageIfNeeded(image, maxSize: 1024)
        guard let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else {
            return nil
        }
        return imageData.base64EncodedString()
        #endif
    }
    
    #if canImport(UIKit)
    private func resizeImageIfNeeded(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        if maxDimension <= maxSize {
            return image
        }
        
        let scaleFactor = maxSize / maxDimension
        let newWidth = size.width * scaleFactor
        let newHeight = size.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    #elseif canImport(AppKit)
    private func resizeImageIfNeeded(_ image: NSImage, maxSize: CGFloat) -> NSImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        if maxDimension <= maxSize {
            return image
        }
        
        let scaleFactor = maxSize / maxDimension
        let newWidth = size.width * scaleFactor
        let newHeight = size.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    #endif
    
    public func getBaseURL() -> URL {
        return baseURL
    }
    
    public func getPort() -> Int {
        return port
    }
    
    public func getTarget() -> LLMTarget {
        return target
    }
}
