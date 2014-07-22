import UIKit

class AccessRankViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AccessRankDelegate {
    
    @IBOutlet var tableView : UITableView!
    @IBOutlet var predictionsTextView: UITextView!
    
    private let itemCellIdentifier = "ItemCellIdentifier"
    private let accessRankuserDefaultsKey = "accessRank"
    
    private var accessRank: AccessRank
    
    public init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        let data: AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey(accessRankuserDefaultsKey)
        accessRank = AccessRank(
            listStability: AccessRank.ListStability.Medium,
            data: data as? [String: AnyObject])
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        accessRank.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        updatePredictionList()
    }
    
    //MARK: Table view
    
    private func setupTableView() {
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: itemCellIdentifier)
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return Items.all.count
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let cell = tableView.dequeueReusableCellWithIdentifier(itemCellIdentifier, forIndexPath: indexPath) as UITableViewCell
        cell.textLabel.text = Items.all[indexPath.row]["name"]
        return cell
    }
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        if let id = Items.all[indexPath.row]["id"] {
            accessRank.visitItem(id)
        }
    }
    
    //MARK: AccessRankDelegate
    
    func accessRankDidUpdatePredictions(accessRank: AccessRank) {
        updatePredictionList()
    }
    
    private func updatePredictionList() {
        let predictedItems = accessRank.predictions.map { Items.byID[$0]! }
        predictionsTextView.text = join("\n", predictedItems)
    }
    
    //MARK: Persistence (called in AppDelegate)
    
    public func saveToUserDefaults() {
        NSUserDefaults.standardUserDefaults().setObject(accessRank.toDictionary(), forKey: accessRankuserDefaultsKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
}