import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AccessRankDelegate {
    @IBOutlet var tableView : UITableView!
    @IBOutlet var predictionsTextView: UITextView!
    
    private let cellIdentifier = "cellIdentifier"
    private let userDefaultsKey = "accessRank"
    
    private lazy var accessRank: AccessRank = {
        let snapshot = UserDefaults.standard.object(forKey: self.userDefaultsKey) as? [String: Any]
        let accessRank = AccessRank(listStability: .medium, snapshot: snapshot)
        accessRank.delegate = self
        return accessRank
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        setupNotifications()
        updatePredictionList()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - TableView
    
    private func setupTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TestItems.all.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.text = TestItems.all[indexPath.row]["name"]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = TestItems.all[indexPath.row]["id"] else { return }
        accessRank.visitItem(id)
    }
    
    // MARK: - AccessRankDelegate
    
    func accessRankDidUpdatePredictions(_ accessRank: AccessRank) {
        updatePredictionList()
    }
    
    private func updatePredictionList() {
        let predictedItems = accessRank.predictions.map { TestItems.byID[$0]! }
        predictionsTextView.text = predictedItems.joined(separator: "\n")
    }
    
    // MARK: - Persistence
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: .UIApplicationDidEnterBackground, object: nil)
    }
    
    @objc func didEnterBackground() {
        saveToUserDefaults()
    }
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(accessRank.toDictionary(), forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
    }
}
