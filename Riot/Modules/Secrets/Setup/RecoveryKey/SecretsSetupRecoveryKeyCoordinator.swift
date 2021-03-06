// File created from ScreenTemplate
// $ createScreen.sh SecretsSetupRecoveryKey SecretsSetupRecoveryKey
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
import UIKit

final class SecretsSetupRecoveryKeyCoordinator: SecretsSetupRecoveryKeyCoordinatorType {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private var secretsSetupRecoveryKeyViewModel: SecretsSetupRecoveryKeyViewModelType
    private let secretsSetupRecoveryKeyViewController: SecretsSetupRecoveryKeyViewController
    
    // MARK: Public

    // Must be used only internally
    var childCoordinators: [Coordinator] = []
    
    weak var delegate: SecretsSetupRecoveryKeyCoordinatorDelegate?
    
    // MARK: - Setup
    
    init(recoveryService: MXRecoveryService, passphrase: String?) {        
        let secretsSetupRecoveryKeyViewModel = SecretsSetupRecoveryKeyViewModel(recoveryService: recoveryService, passphrase: passphrase)
        let secretsSetupRecoveryKeyViewController = SecretsSetupRecoveryKeyViewController.instantiate(with: secretsSetupRecoveryKeyViewModel)
        self.secretsSetupRecoveryKeyViewModel = secretsSetupRecoveryKeyViewModel
        self.secretsSetupRecoveryKeyViewController = secretsSetupRecoveryKeyViewController
    }
    
    // MARK: - Public methods
    
    func start() {            
        self.secretsSetupRecoveryKeyViewModel.coordinatorDelegate = self
    }
    
    func toPresentable() -> UIViewController {
        return self.secretsSetupRecoveryKeyViewController
    }
}

// MARK: - SecretsSetupRecoveryKeyViewModelCoordinatorDelegate
extension SecretsSetupRecoveryKeyCoordinator: SecretsSetupRecoveryKeyViewModelCoordinatorDelegate {
    
    func secretsSetupRecoveryKeyViewModelDidComplete(_ viewModel: SecretsSetupRecoveryKeyViewModelType) {
        self.delegate?.secretsSetupRecoveryKeyCoordinatorDidComplete(self)
    }
    
    func secretsSetupRecoveryKeyViewModelDidFailed(_ viewModel: SecretsSetupRecoveryKeyViewModelType) {
        self.delegate?.secretsSetupRecoveryKeyCoordinatorDidFailed(self)
    }
    
    func secretsSetupRecoveryKeyViewModelDidCancel(_ viewModel: SecretsSetupRecoveryKeyViewModelType) {
        self.delegate?.secretsSetupRecoveryKeyCoordinatorDidCancel(self)
    }
}
