import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView : UITableView
    @IBOutlet var predictionsTextView: UITextView
    let countryCellIdentifier = "CountryCellIdentifier"
    
    let accessRank: AccessRank = AccessRank(listStability: AccessRank.ListStability.Medium)
    
    init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
    }
    
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
            accessRank.mostRecentItem = code
            println(accessRank.markovDescription())
            println(accessRank.predictionListDescription())
            updatePredictions()
        }
    }
    
    func updatePredictions() {
        let predictedCountries: String[] = accessRank.predictions.map { Countries.byCode[$0]! }
        predictionsTextView.text = join("\n", predictedCountries)
    }
    
}