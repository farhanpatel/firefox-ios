/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import SnapKit
import Shared
import SwiftKeychainWrapper

/// Delegate available for PasscodeEntryViewController consumers to be notified of the validation of a passcode.
@objc protocol PasscodeEntryDelegate: class {
    func passcodeValidationDidSucceed()
}

/// Presented to the to user when asking for their passcode to validate entry into a part of the app.
class PasscodeEntryViewController: UIViewController {
    weak var delegate: PasscodeEntryDelegate?
    private let passcodePane = PasscodePane()
    private var authenticationInfo: AuthenticationKeychainInfo?
    private var errorToast: ErrorToast?
    private let errorPadding: CGFloat = 10

    init() {
        self.authenticationInfo = KeychainWrapper.authenticationInfo()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AuthenticationStrings.enterPasscodeTitle
        view.backgroundColor = UIConstants.TableViewHeaderBackgroundColor
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: Selector("dismiss"))
        automaticallyAdjustsScrollViewInsets = false
        view.addSubview(passcodePane)
        passcodePane.snp_makeConstraints { make in
            make.bottom.left.right.equalTo(self.view)
            make.top.equalTo(self.snp_topLayoutGuideBottom)
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        passcodePane.codeInputView.delegate = self

        // Don't show the keyboard or allow typing if we're locked out. Also display the error.
        if authenticationInfo?.isLocked() ?? false {
            displayError(AuthenticationStrings.maximumAttemptsReached)
            passcodePane.codeInputView.userInteractionEnabled = false
        } else {
            passcodePane.codeInputView.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.endEditing(true)
    }
}

extension PasscodeEntryViewController {
    @objc private func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension PasscodeEntryViewController: PasscodeInputViewDelegate {
    func passcodeInputView(inputView: PasscodeInputView, didFinishEnteringCode code: String) {
        if let passcode = authenticationInfo?.passcode where passcode == code {
            authenticationInfo?.recordValidation()
            KeychainWrapper.setAuthenticationInfo(authenticationInfo)
            delegate?.passcodeValidationDidSucceed()
        } else {
            authenticationInfo?.recordFailedAttempt()
            let numberOfAttempts = authenticationInfo?.failedAttempts ?? 0
            if numberOfAttempts == AllowedPasscodeFailedAttempts {
                authenticationInfo?.lockOutUser()
                displayError(AuthenticationStrings.maximumAttemptsReached)
                passcodePane.codeInputView.userInteractionEnabled = false
                resignFirstResponder()
            } else {
                displayError(String(format: AuthenticationStrings.incorrectAttemptsRemaining, (AllowedPasscodeFailedAttempts - numberOfAttempts)))
            }
            passcodePane.codeInputView.resetCode()

            // Store mutations on authentication info object
            KeychainWrapper.setAuthenticationInfo(authenticationInfo)
        }
    }

    private func displayError(text: String) {
        errorToast?.removeFromSuperview()
        errorToast = {
            let toast = ErrorToast()
            toast.textLabel.text = text
            view.addSubview(toast)
            toast.snp_makeConstraints { make in
                make.center.equalTo(self.view)
                make.left.greaterThanOrEqualTo(self.view).offset(errorPadding)
                make.right.lessThanOrEqualTo(self.view).offset(-errorPadding)
            }
            return toast
        }()
    }
}
