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
