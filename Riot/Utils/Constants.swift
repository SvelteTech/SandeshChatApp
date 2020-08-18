/*
 Copyright 2020 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

enum Constants {
    
    static let toBeRemovedNotificationCategoryIdentifier = "TO_BE_REMOVED"
    static let callInviteNotificationCategoryIdentifier = "CALL_INVITE"
  static let loginURL = "http://23.100.84.74/app_api/index.php/Chat_register/login"
  static let verifyOTPURL = "http://23.100.84.74/app_api/index.php/Chat_register/otpVerification"
  static let createPinURL = "http://23.100.84.74/app_api/index.php/Chat_register/savePin"
  static let twoFactorLoginURL = "https://2factor.in/API/V1/b9c5b0b2-e158-11ea-9fa5-0200cd936042/SMS/+91"
  static let twoFactorVerifyOTPURL = "https://2factor.in/API/V1/b9c5b0b2-e158-11ea-9fa5-0200cd936042/SMS/VERIFY"
}
