//
//  swift_llm_bridgeTests.swift
//  swift-llm-bridge
//
//  Created by BillyPark on 6/1/25.
//


import Testing
@testable import swift_llm_bridge

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testLLMBridgeInitialization() async throws {
    let bridge = await LLMBridge(baseURL: "http://localhost", port: 11434, target: .ollama)
    
    await MainActor.run {
        #expect(bridge.getPort() == 11434)
        #expect(bridge.getTarget() == .ollama)
        #expect(bridge.getBaseURL().absoluteString == "http://localhost:11434")
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testLLMBridgeConfigurationUpdate() async throws {
    let bridge = await LLMBridge()
    
    let newBridge = await bridge.createNewSession(baseURL: "http://192.168.1.100", port: 1234, target: .lmstudio)
    
    await MainActor.run {
        #expect(newBridge.getPort() == 1234)
        #expect(newBridge.getTarget() == .lmstudio)
        #expect(newBridge.getBaseURL().absoluteString == "http://192.168.1.100:1234")
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testClaudeInitialization() async throws {
    let claudeBridge = await LLMBridge(target: .claude, apiKey: "test-api-key")
    
    await MainActor.run {
        #expect(claudeBridge.getPort() == 443)
        #expect(claudeBridge.getTarget() == .claude)
        #expect(claudeBridge.getBaseURL().absoluteString == "https://api.anthropic.com")
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testClaudeWithoutAPIKey() async throws {
    let claudeBridge = await LLMBridge(target: .claude)
    
    await MainActor.run {
        #expect(claudeBridge.getTarget() == .claude)
    }
    
    do {
        _ = try await claudeBridge.getAvailableModels()
        #expect(Bool(false), "Should throw error without API key")
    } catch {
        #expect(error.localizedDescription.contains("Claude API key is required"))
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testClaudeModels() async throws {
    let claudeBridge = await LLMBridge(target: .claude, apiKey: "test-api-key")
    
    do {
        let models = try await claudeBridge.getAvailableModels()
        #expect(models.contains("claude-3-5-sonnet-20241022"))
        #expect(models.contains("claude-3-5-haiku-20241022"))
        #expect(models.contains("claude-3-opus-20240229"))
    } catch {
        print("Expected error for invalid API key: \(error)")
    }
}

@Test func testMessageCreation() async throws {
    let message = LLMBridge.Message(content: "Test message", isUser: true)
    
    #expect(message.content == "Test message")
    #expect(message.isUser == true)
    #expect(message.image == nil)
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testClearMessages() async throws {
    let bridge = await LLMBridge()
    
    await MainActor.run {
        let userMessage = LLMBridge.Message(content: "User message", isUser: true)
        bridge.messages.append(userMessage)
        
        #expect(bridge.messages.count == 1)
        
        bridge.clearMessages()
        
        #expect(bridge.messages.count == 0)
        #expect(bridge.errorMessage == nil)
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testLLMTargetEnum() async throws {
    #expect(LLMTarget.ollama == .ollama)
    #expect(LLMTarget.lmstudio == .lmstudio)
    #expect(LLMTarget.claude == .claude)
    #expect(LLMTarget.openai == .openai)
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testCreateNewSessionWithAPIKey() async throws {
    let bridge = await LLMBridge()
    
    let claudeBridge = await bridge.createNewSession(
        baseURL: "https://api.anthropic.com", 
        port: 443, 
        target: .claude, 
        apiKey: "test-key"
    )
    
    await MainActor.run {
        #expect(claudeBridge.getTarget() == .claude)
        #expect(claudeBridge.getPort() == 443)
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testOpenAIInitialization() async throws {
    let openAIBridge = await LLMBridge(target: .openai, apiKey: "test-api-key")
    
    await MainActor.run {
        #expect(openAIBridge.getPort() == 443)
        #expect(openAIBridge.getTarget() == .openai)
        #expect(openAIBridge.getBaseURL().absoluteString == "https://api.openai.com")
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testOpenAIWithoutAPIKey() async throws {
    let openAIBridge = await LLMBridge(target: .openai)
    
    await MainActor.run {
        #expect(openAIBridge.getTarget() == .openai)
    }
    
    do {
        _ = try await openAIBridge.getAvailableModels()
        #expect(Bool(false), "Should throw error without API key")
    } catch {
        #expect(error.localizedDescription.contains("OpenAI API key is required"))
    }
}

@available(iOS 15.0, macOS 12.0, *)
@Test func testOpenAIModels() async throws {
    let openAIBridge = await LLMBridge(target: .openai, apiKey: "test-api-key")
    
    do {
        let models = try await openAIBridge.getAvailableModels()
        #expect(models.contains("gpt-3.5-turbo") || models.contains("gpt-4"))
    } catch {
        print("Expected error for invalid API key: \(error)")
    }
}
