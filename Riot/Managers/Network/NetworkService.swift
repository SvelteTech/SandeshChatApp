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
  
  private override init() {
    print("Initalized the network manager instance")
  }
  
  func sendPostRequest(urlString: String, parameters: [String :Any]?, completionHandler: @escaping(Data?, Error?) -> Void) {
    // 1. Make URL from UrlString
    let url = URL(string: urlString)
    // 2. Create the URLRequest object
    var urlRequest = URLRequest(url: url!)
    // 3. Set httpMethod like POST, GET etc
//    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    urlRequest.httpMethod = "POST"
    if let parameters = parameters,
      let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
      // 4. Add if any parameter
      urlRequest.httpBody = httpBody
    }
    URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
      completionHandler(data, error)
    }.resume()
  }
}
