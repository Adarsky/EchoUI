import SwiftUI

// MARK: - Preview
#Preview {
    let previewBot = Bot(
        id: UUID(),
        name: "PreviewBot",
        avatarSystemName: "brain.head.profile",
        iconColor: .blue,
        subtitle: "Helpful assistant",
        date: "24.09.2020",
        isPinned: false,
        greeting: "Hello, how can I help you today?",
        avatarData: nil
    )
    let previewMessages: [ChatMessageModel] = [
        ChatMessageModel(content: "Hey, can you help me plan my week?", isUser: true),
        ChatMessageModel(content: "Absolutely. What are your top 3 priorities this week?", isUser: false),
        ChatMessageModel(content: "Ship onboarding UI, clean up tech debt, and prepare demo notes.", isUser: true),
        ChatMessageModel(content: "Great set. Want a day-by-day schedule or a priority matrix first?", isUser: false),
        ChatMessageModel(content: "Day-by-day please.", isUser: true),
        ChatMessageModel(content: "Monday: scope + blockers. Tuesday: core UI. Wednesday: polish and tests.", isUser: false),
        ChatMessageModel(content: "Continue.", isUser: true),
        ChatMessageModel(content: "Thursday: bugfix and edge cases. Friday: demo run-through and release prep.", isUser: false),
        ChatMessageModel(content: "Can you add buffer time?", isUser: true),
        ChatMessageModel(content: "Yes. Add two 45-minute buffers on Tue and Thu for unexpected issues.", isUser: false),
        ChatMessageModel(content: "Also remind me to write release notes.", isUser: true),
        ChatMessageModel(content: "Added: Friday 10:00 AM release notes draft, 2:00 PM final pass.", isUser: false),
        ChatMessageModel(content: "What should I cut if I slip a day?", isUser: true),
        ChatMessageModel(content: "Cut non-critical animations first, then defer low-risk refactors.", isUser: false),
        ChatMessageModel(content: "Give me a quick standup format.", isUser: true),
        ChatMessageModel(content: "Yesterday, Today, Blockers, Risks. Keep each section to one sentence.", isUser: false),
        ChatMessageModel(content: "Nice. Can you summarize all this in 5 bullets?", isUser: true),
        ChatMessageModel(content: "1) Focus on onboarding UI.\n2) Timebox tech debt.\n3) Add buffer slots.\n4) Prepare demo early.\n5) Ship with clear release notes.", isUser: false),
        ChatMessageModel(content: "Looks good. Add a motivational line.", isUser: true),
        ChatMessageModel(content: "Progress beats perfection. Ship small, improve fast.", isUser: false),
        ChatMessageModel(content: "Thanks!", isUser: true),
        ChatMessageModel(content: "Anytime. I can also generate a checklist if you want.", isUser: false)
    ]

    ChatView(bot: previewBot, previewMessages: previewMessages)
        .environmentObject(APIManager())
        .environment(PersonaManager())
}
