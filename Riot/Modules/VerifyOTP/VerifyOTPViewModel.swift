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

@objc class VerifyOTPViewModel: NSObject {
  func sendOtpRequest(_ otp: String, _ mobileNumber: String, success: @escaping(_ status: Bool) -> Void, failure: @escaping(_ errorMessage: String?) -> Void) {
    let imeiNumber = UIDevice.current.identifierForVendor?.uuidString
    let parameters: [String: Any] = ["otp": otp,
                      "imei": imeiNumber,
                      "mobile": mobileNumber]
    
    NetworkManager.shared.sendPostRequest(urlString: Constants.verifyOTPURL, parameters: parameters) { (data, error) in
      if let data = data, error == nil {
        debugPrint("Got Verify OTP response - \(data)")
        success(self.parseResponse(data))
      } else if let errorMessage = error {
        failure(errorMessage)
      }
    }
  }
  
  func parseResponse(_ data: Data) -> Bool {
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
