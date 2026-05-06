import Foundation

struct DashboardSnapshot {
    var subjectCount: Int
    var topicCount: Int
    var questionCount: Int
    var userCount: Int
    var learningPathCount: Int
    var dailyChallengeCount: Int
    var currentChallengeCount: Int
    var badgeCount: Int
    var featuredChallenges: [Challenge]
    var lastSyncedAt: Date

    static let empty = DashboardSnapshot(
        subjectCount: 0,
        topicCount: 0,
        questionCount: 0,
        userCount: 0,
        learningPathCount: 0,
        dailyChallengeCount: 0,
        currentChallengeCount: 0,
        badgeCount: 0,
        featuredChallenges: [],
        lastSyncedAt: .now
    )
}

@MainActor
final class AdminDashboardViewModel: ObservableObject {
    @Published private(set) var snapshot = DashboardSnapshot.empty
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let subjectsRepository = SubjectsRepository()
    private let topicsRepository = TopicsRepository()
    private let questionsRepository = QuestionsRepository()
    private let usersRepository = UsersRepository()
    private let learningPathsRepository = LearningPathsRepository()
    private let dailyChallengesRepository = DailyChallengesRepository()
    private let challengesRepository = ChallengesRepository()
    private let badgesRepository = BadgesRepository()

    private var hasLoaded = false

    func load(force: Bool = false) {
        guard hasLoaded == false || force else { return }

        hasLoaded = true
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()

        var subjectCount = snapshot.subjectCount
        var topicCount = snapshot.topicCount
        var questionCount = snapshot.questionCount
        var userCount = snapshot.userCount
        var learningPathCount = snapshot.learningPathCount
        var dailyChallengeCount = snapshot.dailyChallengeCount
        var currentChallengeCount = snapshot.currentChallengeCount
        var badgeCount = snapshot.badgeCount
        var featuredChallenges = snapshot.featuredChallenges
        var capturedErrors: [String] = []

        func captureCount(
            using work: (@escaping (Result<Int, Error>) -> Void) -> Void,
            assign: @escaping (Int) -> Void
        ) {
            group.enter()
            work { result in
                defer { group.leave() }

                switch result {
                case .success(let count):
                    assign(count)
                case .failure(let error):
                    capturedErrors.append(error.localizedDescription)
                }
            }
        }

        captureCount(using: subjectsRepository.countAll) { subjectCount = $0 }
        captureCount(using: topicsRepository.countAll) { topicCount = $0 }
        captureCount(using: questionsRepository.countAll) { questionCount = $0 }
        captureCount(using: usersRepository.countAll) { userCount = $0 }
        captureCount(using: learningPathsRepository.countAll) { learningPathCount = $0 }
        captureCount(using: dailyChallengesRepository.countAll) { dailyChallengeCount = $0 }
        captureCount(using: { completion in
            self.challengesRepository.countCurrentChallenges(completion: completion)
        }) { currentChallengeCount = $0 }
        captureCount(using: badgesRepository.countAll) { badgeCount = $0 }

        group.enter()
        challengesRepository.fetchCurrentChallengesPreview { result in
            defer { group.leave() }

            switch result {
            case .success(let challenges):
                featuredChallenges = challenges
            case .failure(let error):
                capturedErrors.append(error.localizedDescription)
            }
        }

        group.notify(queue: .main) {
            self.snapshot = DashboardSnapshot(
                subjectCount: subjectCount,
                topicCount: topicCount,
                questionCount: questionCount,
                userCount: userCount,
                learningPathCount: learningPathCount,
                dailyChallengeCount: dailyChallengeCount,
                currentChallengeCount: currentChallengeCount,
                badgeCount: badgeCount,
                featuredChallenges: featuredChallenges,
                lastSyncedAt: .now
            )
            self.isLoading = false

            if capturedErrors.isEmpty == false {
                self.errorMessage = capturedErrors.joined(separator: "\n")
            }
        }
    }
}
