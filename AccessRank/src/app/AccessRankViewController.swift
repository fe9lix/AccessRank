import UIKit

class AccessRankViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AccessRankDelegate {
    
    @IBOutlet var tableView : UITableView
    @IBOutlet var predictionsTextView: UITextView
    
    let countryCellIdentifier = "CountryCellIdentifier"
    let accessRankuserDefaultsKey = "accessRank"
    
    var accessRank: AccessRank
    
    init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        let data: AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey(accessRankuserDefaultsKey)
        accessRank = AccessRank(
            listStability: AccessRank.ListStability.Medium,
            data: data as? Dictionary<String, AnyObject>)
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        accessRank.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        updatePredictionList()
    }
    
    // Table view
    
    func setupTableView() {
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: countryCellIdentifier)
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return Countries.all.count
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let cell = tableView.dequeueReusableCellWithIdentifier(countryCellIdentifier, forIndexPath: indexPath) as UITableViewCell
        cell.textLabel.text = Countries.all[indexPath.row]["name"]
        return cell
    }
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        if let code = Countries.all[indexPath.row]["code"] {
            accessRank.visitItem(code)
        }
    }
    
    // AccessRankDelegate
    
    func accessRankDidUpdatePredictions(accessRank: AccessRank) {
        updatePredictionList()
    }
    
    func updatePredictionList() {
        let predictedCountries: String[] = accessRank.predictions.map { Countries.byCode[$0]! }
        predictionsTextView.text = join("\n", predictedCountries)
    }
    
    // Persistence (called in AppDelegate)
    
    func saveToUserDefaults() {
        NSUserDefaults.standardUserDefaults().setObject(accessRank.toDictionary(), forKey: accessRankuserDefaultsKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
}