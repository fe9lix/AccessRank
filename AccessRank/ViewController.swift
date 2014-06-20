import UIKit

class ViewController: UIViewController, UITableViewDataSource {
    
    @IBOutlet var tableView : UITableView
    let accessRank: AccessRank = AccessRank(listStability: AccessRank.ListStability.Medium)
    
    init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        accessRank.mostRecentItem = "item1"
        println("predictions: \n\(accessRank.predictions)")
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        return UITableViewCell();
    }
    
}