// 
// Copyright 2020 Vector Creations Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit

class ActivityIndicator {
  
  // MARK: - Variables
  var container = UIView()
  var loadingView = UIView()
  var activityIndicator = UIActivityIndicatorView()
  
  // MARK: - Constants
  static let shared = ActivityIndicator()
  
  // MARK: - Methods
  private init() {
    debugPrint("Private method")
  }
  
  func start(_ superView: UIView) {
    superView.endEditing(true)
    container.frame = superView.frame
    container.center = superView.center
    container.backgroundColor = ColorFromHex(rgbValue: 0x000000, alpha: 0.3)
    
    loadingView.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
    loadingView.center = superView.center
    loadingView.backgroundColor = ColorFromHex(rgbValue: 0x444444, alpha: 0.7)
    loadingView.clipsToBounds = true
    loadingView.layer.cornerRadius = 10
    
    activityIndicator.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
    activityIndicator.style = .whiteLarge
    activityIndicator.center = CGPoint(x: loadingView.frame.size.width/2, y: loadingView.frame.size.height/2)
    
    loadingView.addSubview(activityIndicator)
    container.addSubview(loadingView)
    superView.addSubview(container)
    activityIndicator.startAnimating()
  }
  
  func stop(_ superview: UIView) {
    superview.endEditing(false)
    activityIndicator.stopAnimating()
    container.removeFromSuperview()
  }
  
  private func ColorFromHex(rgbValue: UInt32, alpha: Double = 1.0) -> UIColor {
    let red = CGFloat((rgbValue & 0xFF0000) >> 16)/256.0
    let green = CGFloat((rgbValue & 0xFF00) >> 8)/256.0
    let blue = CGFloat(rgbValue & 0xFF)/256.0
    return UIColor(red:red, green:green, blue:blue, alpha:CGFloat(alpha))
  }
}
