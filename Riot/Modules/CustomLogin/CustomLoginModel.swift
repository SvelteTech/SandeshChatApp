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
  static func sendLoginRequest(mobileNumber: String, completionHandler: @escaping(_ status: Bool, _ error: String?) -> Void) {
    let imeiNumber = UIDevice.current.identifierForVendor?.uuidString ?? ""
    let parameters: [String: Any] = ["imei": imeiNumber, "mobile": mobileNumber]
    NetworkManager.shared.sendPostRequest(urlString: Constants.loginURL, parameters: parameters) { (data, error) in
      if let data = data {
        debugPrint("Got login response - \(data)")
        completionHandler(parseData(data), nil)
      } else if let errorMessage = error {
        debugPrint("Error - \(errorMessage)")
        completionHandler(false, errorMessage)
      }
    }
  }
  
  private static func parseData(_ data: Data) -> Bool {
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        if let successResponse = json["success"] as? String, successResponse == "1" {
          return true
        }
      }
    } catch let error as NSError {
      print("Failed to load: \(error.localizedDescription)")
    }
    return false
  }
}
