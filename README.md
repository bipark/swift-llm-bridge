# Swift LLM Bridge

A Swift package for iOS and macOS that connects to Ollama, LMStudio, Claude, and OpenAI servers for interactive AI model conversations.

## Features

- ✅ Ollama server support
- ✅ LMStudio server support  
- ✅ Claude API support (Anthropic)
- ✅ OpenAI API support
- ✅ Real-time streaming responses
- ✅ Image input support (Ollama, Claude & OpenAI)
- ✅ Conversation history management
- ✅ iOS/macOS cross-platform support
- ✅ SwiftUI ObservableObject support
- ✅ Enhanced SSE (Server-Sent Events) handling
- ✅ Debug logging for troubleshooting
- ✅ API key authentication (Claude & OpenAI)

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

// Connect to Claude API
let claudeBridge = LLMBridge(
    target: .claude, 
    apiKey: "your-claude-api-key"
)

// Connect to OpenAI API
let openAIBridge = LLMBridge(
    target: .openai,
    apiKey: "your-openai-api-key"
)
```

### Getting Available Models

#### Ollama & LMStudio
```swift
do {
    let models = try await bridge.getAvailableModels()
    print("Available models: \(models)")
} catch {
    print("Failed to fetch models: \(error)")
}
```

#### Claude
```swift
do {
    let models = try await claudeBridge.getAvailableModels()
    print("Claude models: \(models)")
    // Output: ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022", "claude-3-opus-20240229"]
} catch {
    print("Failed to fetch Claude models: \(error)")
}
```

#### OpenAI
```swift
do {
    let models = try await openAIBridge.getAvailableModels()
    print("OpenAI models: \(models)")
    // Output: ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo-preview", "gpt-4-vision-preview", ...]
} catch {
    print("Failed to fetch OpenAI models: \(error)")
}
```

### Sending Messages

#### Basic Text Messages
```swift
// Ollama/LMStudio
do {
    let response = try await bridge.sendMessage(
        content: "Hello! How can you help me?",
        model: "llama3.2"
    )
    print("AI response: \(response.content)")
} catch {
    print("Failed to send message: \(error)")
}

// Claude
do {
    let response = try await claudeBridge.sendMessage(
        content: "Hello! How can you help me?",
        model: "claude-3-5-sonnet-20241022"
    )
    print("Claude response: \(response.content)")
} catch {
    print("Failed to send message: \(error)")
}

// OpenAI
do {
    let response = try await openAIBridge.sendMessage(
        content: "Hello! How can you help me?",
        model: "gpt-4"
    )
    print("OpenAI response: \(response.content)")
} catch {
    print("Failed to send message: \(error)")
}
```

### Sending Messages with Images

#### Ollama (with vision models like llava)
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

#### Claude (supports vision across all models)
```swift
#if canImport(UIKit)
import UIKit

let image = UIImage(named: "example")
do {
    let response = try await claudeBridge.sendMessage(
        content: "Please analyze this image in detail",
        image: image,
        model: "claude-3-5-sonnet-20241022"
    )
    print("Claude analysis: \(response.content)")
} catch {
    print("Failed to send message: \(error)")
}
#endif
```

#### OpenAI (supports vision with GPT-4V models)
```swift
#if canImport(UIKit)
import UIKit

let image = UIImage(named: "example")
do {
    let response = try await openAIBridge.sendMessage(
        content: "What do you see in this image?",
        image: image,
        model: "gpt-4-vision-preview"
    )
    print("OpenAI analysis: \(response.content)")
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
    @State private var selectedTarget: LLMTarget = .ollama
    @State private var apiKey = ""
    
    var body: some View {
        VStack {
            // Target selection
            Picker("Select LLM", selection: $selectedTarget) {
                Text("Ollama").tag(LLMTarget.ollama)
                Text("LMStudio").tag(LLMTarget.lmstudio)
                Text("Claude").tag(LLMTarget.claude)
                Text("OpenAI").tag(LLMTarget.openai)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // API Key input for Claude
            if selectedTarget == .claude {
                SecureField("Claude API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            }
            
            // API Key input for OpenAI
            if selectedTarget == .openai {
                SecureField("OpenAI API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            }
            
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
            
            if let error = bridge.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            HStack {
                TextField("Enter your message...", text: $inputText)
                
                Button("Send") {
                    Task {
                        let currentBridge = createBridge()
                        try? await currentBridge.sendMessage(content: inputText)
                        inputText = ""
                    }
                }
                .disabled(inputText.isEmpty || bridge.isLoading || (selectedTarget == .claude && apiKey.isEmpty) || (selectedTarget == .openai && apiKey.isEmpty))
            }
            .padding()
        }
    }
    
    private func createBridge() -> LLMBridge {
        switch selectedTarget {
        case .ollama:
            return LLMBridge(target: .ollama)
        case .lmstudio:
            return LLMBridge(baseURL: "http://localhost", port: 1234, target: .lmstudio)
        case .claude:
            return LLMBridge(target: .claude, apiKey: apiKey)
        case .openai:
            return LLMBridge(target: .openai, apiKey: apiKey)
        }
    }
}

struct MessageView: View {
    let message: LLMBridge.Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing) {
                    if let image = message.image {
                        #if canImport(UIKit)
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(8)
                        #elseif canImport(AppKit)
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(8)
                        #endif
                    }
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                VStack(alignment: .leading) {
                    Text(message.content)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
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

// Create Claude session with API key
let claudeSession = bridge.createNewSession(
    baseURL: "",
    port: 0,
    target: .claude,
    apiKey: "your-api-key"
)

// Create OpenAI session with API key
let openAISession = bridge.createNewSession(
    baseURL: "",
    port: 0,
    target: .openai,
    apiKey: "your-openai-api-key"
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
- `init(baseURL: String, port: Int, target: LLMTarget, apiKey: String?)`: Initialize with custom configuration
- For Claude: `LLMBridge(target: .claude, apiKey: "your-api-key")`
- For OpenAI: `LLMBridge(target: .openai, apiKey: "your-api-key")`

#### Main Methods
- `getAvailableModels() async throws -> [String]`: Returns available model list
- `sendMessage(content: String, image: PlatformImage?, model: String?) async throws -> Message`: Send message
- `cancelGeneration()`: Cancel current response generation
- `clearMessages()`: Clear message history
- `createNewSession(baseURL: String, port: Int, target: LLMTarget, apiKey: String?) -> LLMBridge`: Create new session

#### Published Properties
- `messages: [Message]`: Array of conversation messages
- `isLoading: Bool`: Loading state
- `errorMessage: String?`: Error message
- `currentResponse: String`: Current streaming response

### LLMTarget Enumeration
- `.ollama`: Ollama server
- `.lmstudio`: LMStudio server
- `.claude`: Claude API (Anthropic)
- `.openai`: OpenAI API

### Message Structure
- `id: UUID`: Unique identifier
- `content: String`: Message content
- `isUser: Bool`: Whether it's a user message
- `timestamp: Date`: Creation time
- `image: PlatformImage?`: Attached image

## Platform-Specific Features

### Claude API
- **Models**: claude-3-5-sonnet-20241022, claude-3-5-haiku-20241022, claude-3-opus-20240229
- **Authentication**: Requires API key from Anthropic
- **Vision**: All models support image analysis
- **Streaming**: Real-time response streaming
- **Rate Limits**: Follows Anthropic's API rate limits

### Ollama
- **Models**: User-installed local models
- **Vision**: Requires vision-capable models (e.g., llava)
- **Local**: Runs on local machine
- **No API Key**: No authentication required

### LMStudio
- **Models**: User-loaded models
- **Local**: Runs on local machine
- **OpenAI Compatible**: Uses OpenAI-style API format
- **No API Key**: No authentication required

### OpenAI
- **Models**: gpt-3.5-turbo, gpt-4, gpt-4-turbo-preview, gpt-4-vision-preview, and more
- **Authentication**: Requires API key from OpenAI
- **Vision**: GPT-4V models support image analysis
- **Streaming**: Real-time response streaming
- **Rate Limits**: Follows OpenAI's API rate limits

## Error Handling

```swift
do {
    let response = try await bridge.sendMessage(content: "Hello")
} catch {
    switch error {
    case let nsError as NSError where nsError.domain == "LLMBridgeError":
        if nsError.code == 401 {
            print("Authentication error: Check your API key")
        }
    default:
        print("Network or other error: \(error.localizedDescription)")
    }
}
```

## Recent Updates

### Version 1.3.0
- ✅ **Claude Model Update**: Added support for Claude-3 Opus, Sonnet, and Haiku models
  - claude-opus-4-20250514
  - claude-sonnet-4-20250514
  - claude-3-7-sonnet-20250219
  - claude-3-5-sonnet-20241022
  - claude-3-5-haiku-20241022
  - claude-3-opus-20240229
  - claude-3-sonnet-20240229
  - claude-3-haiku-20240307
- ✅ **Image Processing Enhancement**: Optimized image resizing and compression
- ✅ **Stream Processing Improvement**: Optimized streaming logic for each platform
- ✅ **Debug Logging Enhancement**: Added detailed request/response logging
- ✅ **Memory Management Optimization**: Optimized memory usage for image processing
- ✅ **Error Handling Enhancement**: Detailed error messages for each platform

### Version 1.2.0
- ✅ **OpenAI API Integration**: Full support for OpenAI's GPT models
- ✅ **Vision Support Enhancement**: Image analysis with OpenAI GPT-4V models
- ✅ **Four-Platform Support**: Complete integration of Ollama, LMStudio, Claude, and OpenAI
- ✅ **Unified API**: Seamless switching between all four LLM platforms
- ✅ **Enhanced Testing**: Comprehensive test coverage for OpenAI functionality

### Version 1.1.0
- ✅ **Claude API Integration**: Full support for Anthropic's Claude models
- ✅ **API Key Authentication**: Secure API key handling for Claude
- ✅ **Enhanced Vision Support**: Image analysis with both Ollama and Claude
- ✅ **Multi-Platform Targeting**: Seamless switching between Ollama, LMStudio, and Claude
- ✅ **Improved Error Handling**: Better error messages and authentication validation
- ✅ **Updated Tests**: Comprehensive test coverage for all three platforms

### Version 1.0.0
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
- For Claude: Valid Anthropic API key
- For OpenAI: Valid OpenAI API key

## Getting Claude API Key

1. Visit [Anthropic Console](https://console.anthropic.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Generate a new API key
5. Keep your API key secure and never commit it to version control

## Getting OpenAI API Key

1. Visit [OpenAI Platform](https://platform.openai.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Generate a new API key
5. Keep your API key secure and never commit it to version control

## License

GPL License

## Contributing

Pull requests and issue reports are welcome. 