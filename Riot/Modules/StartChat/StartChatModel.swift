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

@objcMembers
class StartChatModel: NSObject {
  static func sendFetchListRequest(_ completionHandler:@escaping(_ list: [Users]?, _ error: String?) -> Void) {
    NetworkManager.shared.sendPostRequest(urlString: Constants.userListURL, parameters: nil, isAuthorizationRequired: true, requestType: .Get) { (data, error) in
                                            guard let data = data, let response = parseJsonResponse(data) else {
                                              if let error = error {
                                                completionHandler(nil, error)
                                              }
                                              completionHandler(nil, "Error in User List")
                                              return
                                            }
      completionHandler(response.users, nil)
    }
  }
  
  private static func parseJsonResponse(_ data: Data) -> UserModel? {
    var users = [Users]()
    if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
      let count = jsonResponse["total"] as? Int,
       let usersResponse = jsonResponse["users"] as? [[String: Any]] {
      for user in usersResponse {
        if let name = user["name"] as? String,
          let isGuest = user["is_guest"] as? Int,
          let admin = user["admin"] as? Int,
          let deactivated = user["deactivated"] as? Int,
          let displayname = user["displayname"] as? String {
          let userType = user["user_type"] as? String
          let avatar_url = user["avatar_url"] as? String
          let user = Users()
          user.name = name
          user.isGuest = isGuest == 0 ? false: true
          user.isAdmin = admin == 0 ? false : true
          user.isDeactivated = deactivated == 0 ? false : true
          user.displayName = displayname
          user.userType = userType
          user.avatarUrl = avatar_url
          users.append(user)
        }
      }
      let responseModel = UserModel()
      responseModel.total = count
      responseModel.users = users
      return responseModel
    }
    return nil
  }
}

@objcMembers
class UserModel: NSObject {
  var total: Int = 0
  var users: [Users]!
}

@objcMembers
class Users: NSObject {
  var name: String = ""
  var userType: String?
  var isGuest: Bool = false
  var isAdmin: Bool = false
  var isDeactivated: Bool = false
  var displayName: String = ""
  var avatarUrl: String?
}
