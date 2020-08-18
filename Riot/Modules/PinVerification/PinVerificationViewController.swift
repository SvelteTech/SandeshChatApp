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

class PinVerificationViewController: UIViewController, PinViewDelegate {
  
  // MARK: - IBOutlets
  @IBOutlet weak var enterPinView: PinView!
  @IBOutlet weak var confirmPinView: PinView!
  
  // MARK: - Variables
  var enteredPin: String = ""
  var confirmedPin: String = ""
  var pinVerificationModel = PinVerificationModel()
  var userId: String = ""
  
  // MARK: - Methods
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configurePinView(enterPinView)
    configurePinView(confirmPinView)
  }
  
  func configurePinView(_ pinView: PinView) {
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
    configurePinViewForBoxStyle(pinView)
    pinView.keyboardType = .phonePad
    if pinView == enterPinView {
     pinView.didFinishCallback = didFinishEnteringPin(pin:)
    } else if pinView == confirmPinView {
      pinView.didFinishCallback = didFinishEnteringConfirmedPin(pin:)
    }
    pinView.didChangeCallback = { pin in
      print("The entered pin is \(pin)")
    }
    pinView.delegate = self
    pinView.clearPin()
  }
  
  func configurePinViewForBoxStyle(_ pinView: PinView) {
    pinView.activeBorderLineThickness = 4
    pinView.fieldBackgroundColor = UIColor.clear
    pinView.activeFieldBackgroundColor = UIColor.clear
    pinView.fieldCornerRadius = 0
    pinView.activeFieldCornerRadius = 0
    pinView.style = .box
  }
  
  func didFinishEnteringPin(pin: String) {
    debugPrint("User has entered \(pin)")
    enteredPin = pin
  }
  
  func didFinishEnteringConfirmedPin(pin: String) {
    debugPrint("User has entered \(pin)")
    confirmedPin = pin
  }
  
  func successResponse(_ status: Bool) {
    DispatchQueue.main.async {
      ActivityIndicator.shared.stop(self.view)
      if status {
        debugPrint("Pin set successfully.")
        self.showAlert("PIN set successfully.")
      } else {
        debugPrint("Set Pin failed.")
      }
    }
  }
  
  func failureResponse(_ errorMessage: String?) {
    DispatchQueue.main.async {
      ActivityIndicator.shared.stop(self.view)
      debugPrint("PIN set failed - \(String(describing: errorMessage))")
      if let errorMessage = errorMessage {
        self.showAlert(errorMessage, "Error", UIAlertAction(title: "OK", style: .default, handler: { _  in
          self.cancelButtonPressed()
        }))
      }
    }
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
  
  // MARK: - IBAction methods
  @IBAction private func confirmButtonPressed() {
    if enteredPin == confirmedPin {
//      ActivityIndicator.shared.start(self.view)
//      pinVerificationModel.sendSetPinRequest(userId, enteredPin, success: successResponse(_:), failure: failureResponse(_:))
      UserDefault.save("AppPin", enteredPin)
      self.showAlert("Pin Set Successfully.")
    } else {
      self.showAlert("PIN is not matched. Please enter the same PIN.")
    }
  }
  
  @IBAction private func cancelButtonPressed() {
    self.dismiss(animated: true, completion: nil)
  }
  
  // MARK: - Delegate methods
  func pinDidBeginEditing() {
    debugPrint("Pin editing begin")
  }
}
