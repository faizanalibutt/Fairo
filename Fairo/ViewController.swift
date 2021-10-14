//
//  ViewController.swift
//  Fairo
//
//  Created by Faizan Ali Butt on 10/3/21.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var fairoText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let scanSuccessText =
            "Your card has been scanned successfully." +
        "\n\nWe will now capture a selfie to verify your identity. When you’re ready, press the button below."
        fairoText.text = scanSuccessText
    }
    
    @IBAction func closeFairo(_ sender: UIButton) {
        print("Selfie button clicked.")
        let henryHooks = "henrycards://"
        let henryUrl = URL(string: henryHooks)!
        UIApplication.shared.open(henryUrl)
    }
    
}

