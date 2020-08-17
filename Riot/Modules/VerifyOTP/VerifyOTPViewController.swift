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
import MatrixKit

@objcMembers
class VerifyOTPViewController: UIViewController {
  // MARK: - IBOutlets
  @IBOutlet var pinView: PinView!
  
  // MARK: - Variables
  var verifyOTPModel = VerifyOTPViewModel()
  var enteredOTP: String = ""
  var mobileNumber: String = ""
  
  // MARK: - Methodss
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.title = "Verify OTP"
    configurePinView()
  }
  
  func configurePinView() {
    pinView.pinLength = 4
    pinView.secureCharacter = "\u{25CF}"
    pinView.interSpace = 10
    pinView.textColor = UIColor.blue
    pinView.borderLineColor = UIColor.blue
    pinView.activeBorderLineColor = UIColor.gray
    pinView.borderLineThickness = 1
    pinView.shouldSecureText = true
    pinView.allowsWhitespaces = false
    pinView.placeholder = "******"
    pinView.shouldDismissKeyboardOnEmptyFirstField = false
    pinView.font = UIFont.systemFont(ofSize: 15)
    configurePinViewForBoxStyle()
    pinView.keyboardType = .phonePad
    pinView.didFinishCallback = didFinishEnteringPin(pin:)
    pinView.didChangeCallback = { pin in
      print("The entered pin is \(pin)")
    }
    pinView.delegate = self
    pinView.clearPin()
  }
  
  func configurePinViewForBoxStyle() {
    pinView.activeBorderLineThickness = 4
    pinView.fieldBackgroundColor = UIColor.clear
    pinView.activeFieldBackgroundColor = UIColor.clear
    pinView.fieldCornerRadius = 0
    pinView.activeFieldCornerRadius = 0
    pinView.style = .box
  }
  
  func didFinishEnteringPin(pin: String) {
    debugPrint("User has entered \(pin)")
    enteredOTP = pin
  }
  
  func successResponse(_ status: Bool) {
    DispatchQueue.main.async {
      ActivityIndicator.shared.stop(self.view)
      if status {
        debugPrint("OTP Verify successfully.")
        self.showAlert("OTP Verify successfully.")
      } else {
        debugPrint("Invalid OTP.")
      }
    }
  }
  
  func failureResponse(_ errorMessage: String?) {
    DispatchQueue.main.async {
      ActivityIndicator.shared.stop(self.view)
      debugPrint("Verify OTP failed - \(String(describing: errorMessage))")
      if let errorMessage = errorMessage {
        self.showAlert(errorMessage, "Error", UIAlertAction(title: "OK", style: .default, handler: { _  in
          self.cancelButtonPressed()
        }))
      }
    }
  }
  
  // MARK: - IBAction methods
  @IBAction private func resendOTPButtonPressed() {
  }
  
  @IBAction private func verifyOTPButtonPressed() {
    ActivityIndicator.shared.start(self.view)
    verifyOTPModel.sendOtpRequest(enteredOTP, mobileNumber, success: successResponse(_:), failure: failureResponse(_:))
  }
  
  @IBAction private func cancelButtonPressed() {
    self.dismiss(animated: true, completion: nil)
  }
  
  func showAlert(_ message: String, _ title: String? = nil, _ okButton: UIAlertAction? = nil) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
    if let okButton = okButton {
      alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
      alert.addAction(okButton)
    } else {
      alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
    }
    self.present(alert, animated: true, completion: nil)
  }
}

extension VerifyOTPViewController: PinViewDelegate {
  func pinDidBeginEditing() {
    debugPrint("Pin editing begin")
  }
}
