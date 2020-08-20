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
import Foundation
import UIKit

@objcMembers
class CustomLoginModel: NSObject {
  static func sendLoginRequest(mobileNumber: String, completionHandler: @escaping(_ status: Bool, _ sessionId: String?, _ error: String?) -> Void) {
    let randomOtp = String(format: "%04d", arc4random_uniform(10000))
    let verifyOTPURL = Constants.twoFactorLoginURL + mobileNumber + "/" + randomOtp + "/Sandesh"
//    let imeiNumber = UIDevice.current.identifierForVendor?.uuidString ?? ""
//    let parameters: [String: Any] = ["imei": imeiNumber, "mobile": mobileNumber]
    NetworkManager.shared.sendPostRequest(urlString: verifyOTPURL, parameters: nil) { (data, error) in
      if let data = data {
        debugPrint("Got login response - \(data)")
        let response = parseData(data)
        completionHandler(response.0, response.1, nil)
      } else if let errorMessage = error {
        debugPrint("Error - \(errorMessage)")
        completionHandler(false, nil, errorMessage)
      }
    }
  }
  
  private static func parseData(_ data: Data) -> (Bool, String?) {
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let sessionId = json["Details"] as? String {
        if let successResponse = json["Status"] as? String, successResponse == "Success" {
          return (true, sessionId)
        }
      }
    } catch let error as NSError {
      print("Failed to load: \(error.localizedDescription)")
    }
    return (false, nil)
  }
}
