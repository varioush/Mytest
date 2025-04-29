You are a Swift iOS developer helping me extend an existing project using MVVM architecture.

Context:
- This project uses Swift 5, UIKit, MVVM, Combine for reactive programming, and no Storyboards.
- I want to add a new feature where the user types a paragraph, and the app summarizes it using an LLM API.

Feature requirements:
- Add a new ViewController named `SummarizerViewController`.
- It should have a ViewModel called `SummarizerViewModel`.
- Use URLSession to make API calls to the summarization service.
- The API endpoint is: POST https://api.example.com/summarize
- Request body: { "text": "<user text>" }
- Response: { "summary": ["point 1", "point 2", "point 3"] }

Constraints:
- Must follow existing project architecture.
- No third-party libraries should be introduced.
- Error handling must be implemented for network failures.
- Show activity indicator while the request is being made.

Please generate the necessary Swift classes, methods, and UI components, following best practices.
