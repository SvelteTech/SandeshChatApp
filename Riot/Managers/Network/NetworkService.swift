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

enum RequestType: String {
  case Post = "POST"
  case Get = "GET"
  case Put = "PUT"
}

@objcMembers
class NetworkManager: NSObject {
  static let shared = NetworkManager()
  
  private var authorizationHeader: String {
    return "Bearer \(Constants.accessToken)"
  }
  
  private override init() {
    print("Initalized the network manager instance")
  }
  
  func sendPostRequest(urlString: String, parameters: [String: Any]?, isAuthorizationRequired: Bool = false, requestType: RequestType = .Post, completionHandler: @escaping(Data?, String?) -> Void) {
    if let url = URL(string: urlString) {
      var urlRequest = URLRequest(url: url)
      urlRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      // Add the access token to the header
      if isAuthorizationRequired {
        urlRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
      }
      urlRequest.httpMethod = requestType.rawValue
      if let parameters = parameters,
        let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
        urlRequest.httpBody = httpBody
      }
      URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
        completionHandler(data, error?.localizedDescription)
      }.resume()
    } else {
      let errorMessage = "Invalid URL"
      debugPrint(errorMessage)
      completionHandler(nil, errorMessage)
    }
  }
}
