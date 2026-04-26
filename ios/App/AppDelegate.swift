import UIKit
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {

    private static let bgRefreshTaskID = "com.example.couplesmvp.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        registerBGTask()
        return true
    }

    // MARK: - Background App Refresh

    private func registerBGTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgRefreshTaskID,
            using: nil
        ) { task in
            self.handleAppRefresh(task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleAppRefresh()

        guard let pairIDString = UserDefaults(suiteName: SharedConstants.appGroupID)?
            .string(forKey: "cached_pair_id"),
              let pairID = UUID(uuidString: pairIDString) else {
            task.setTaskCompleted(success: false)
            return
        }

        let refreshTask = Task {
            await HomeViewModel.backgroundRefresh(pairID: pairID)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
