# Swift LLM Bridge

A Swift package for iOS and macOS that connects to Ollama and LMStudio servers for interactive AI model conversations.

## Features

- ✅ Ollama server support
- ✅ LMStudio server support  
- ✅ Real-time streaming responses
- ✅ Image input support (Ollama)
- ✅ Conversation history management
- ✅ iOS/macOS cross-platform support
- ✅ SwiftUI ObservableObject support
- ✅ Enhanced SSE (Server-Sent Events) handling
- ✅ Debug logging for troubleshooting

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/bipark/swift-llm-bridge.git", from: "1.0.0")
]
```

## Usage

### Basic Setup

```swift
import swift_llm_bridge

// Connect to Ollama server
let bridge = LLMBridge(
    baseURL: "http://localhost", 
    port: 11434, 
    target: .ollama
)

// Connect to LMStudio server
let lmStudioBridge = LLMBridge(
    baseURL: "http://localhost", 
    port: 1234, 
    target: .lmstudio
)
```

### Getting Available Models

```swift
do {
    let models = try await bridge.getAvailableModels()
    print("Available models: \(models)")
} catch {
    print("Failed to fetch models: \(error)")
}
```

### Sending Messages

```swift
do {
    let response = try await bridge.sendMessage(
        content: "Hello! How can you help me?",
        model: "llama3.2"
    )
    print("AI response: \(response.content)")
} catch {
    print("Failed to send message: \(error)")
}
```

### Sending Messages with Images (iOS)

```swift
#if canImport(UIKit)
import UIKit

let image = UIImage(named: "example")
do {
    let response = try await bridge.sendMessage(
        content: "Please describe this image",
        image: image,
        model: "llava"
    )
    print("AI response: \(response.content)")
} catch {
    print("Failed to send message: \(error)")
}
#endif
```

### Using with SwiftUI

```swift
import SwiftUI
import swift_llm_bridge

struct ChatView: View {
    @StateObject private var bridge = LLMBridge()
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    ForEach(bridge.messages) { message in
                        MessageView(message: message)
                    }
                }
            }
            
            if bridge.isLoading {
                ProgressView("Generating response...")
            }
            
            HStack {
                TextField("Enter your message...", text: $inputText)
                
                Button("Send") {
                    Task {
                        try? await bridge.sendMessage(content: inputText)
                        inputText = ""
                    }
                }
                .disabled(inputText.isEmpty || bridge.isLoading)
            }
            .padding()
        }
    }
}

struct MessageView: View {
    let message: LLMBridge.Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            } else {
                Text(message.content)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}
```

### Configuration Changes

```swift
// Create new session with different settings
let newBridge = bridge.createNewSession(
    baseURL: "http://192.168.1.100",
    port: 11434,
    target: .ollama
)
```

### Conversation Management

```swift
// Clear message history
bridge.clearMessages()

// Cancel response generation
bridge.cancelGeneration()

// Check current streaming response
print("Current response: \(bridge.currentResponse)")
```

## API Reference

### LLMBridge Class

#### Initialization
- `init(baseURL: String, port: Int, target: LLMTarget)`

#### Main Methods
- `getAvailableModels() async throws -> [String]`: Returns available model list
- `sendMessage(content: String, image: PlatformImage?, model: String?) async throws -> Message`: Send message
- `cancelGeneration()`: Cancel current response generation
- `clearMessages()`: Clear message history
- `createNewSession(baseURL: String, port: Int, target: LLMTarget) -> LLMBridge`: Create new session with different configuration

#### Published Properties
- `messages: [Message]`: Array of conversation messages
- `isLoading: Bool`: Loading state
- `errorMessage: String?`: Error message
- `currentResponse: String`: Current streaming response

### LLMTarget Enumeration
- `.ollama`: Ollama server
- `.lmstudio`: LMStudio server

### Message Structure
- `id: UUID`: Unique identifier
- `content: String`: Message content
- `isUser: Bool`: Whether it's a user message
- `timestamp: Date`: Creation time
- `image: PlatformImage?`: Attached image

## Recent Updates

### Version 1.1.0
- ✅ Enhanced SSE (Server-Sent Events) handling for LMStudio
- ✅ Improved stream processing with better error handling
- ✅ Added debug logging for troubleshooting connection issues
- ✅ Optimized URLSession configuration for streaming
- ✅ Better handling of different SSE formats between Ollama and LMStudio
- ✅ Internationalization: All strings converted to English

### Debug Features
When troubleshooting connection issues, the library now provides detailed console logs:
- Raw SSE line processing
- JSON parsing steps
- Content chunk accumulation
- Stream completion detection
- Request headers and URLs

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 6.1+
- Xcode 15.0+

## License

GPL License

## Contributing

Pull requests and issue reports are welcome. 