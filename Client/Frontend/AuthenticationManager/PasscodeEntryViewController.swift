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
    private var keyboardIntersectionHeight: CGFloat?
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
        KeyboardHelper.defaultHelper.addDelegate(self)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        passcodePane.codeInputView.delegate = self
        passcodePane.codeInputView.becomeFirstResponder()
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
            authenticationInfo?.recordValidationTime()
            KeychainWrapper.setAuthenticationInfo(authenticationInfo)
            delegate?.passcodeValidationDidSucceed()
        } else {
            displayError("Incorrect passcode. Try again.")
            passcodePane.codeInputView.resetCode()
        }
    }

    private func displayError(text: String) {
        guard let keyboardSpace = keyboardIntersectionHeight else {
            return
        }

        errorToast?.removeFromSuperview()
        errorToast = {
            let toast = ErrorToast()
            toast.textLabel.text = text
            view.addSubview(toast)
            toast.snp_makeConstraints { make in
                make.centerX.equalTo(self.view)
                make.bottom.equalTo(self.view).offset(-(keyboardSpace + errorPadding))
                make.left.greaterThanOrEqualTo(self.view).offset(errorPadding)
                make.right.lessThanOrEqualTo(self.view).offset(-errorPadding)
            }
            return toast
        }()
    }
}

extension PasscodeEntryViewController: KeyboardHelperDelegate {
    func keyboardHelper(keyboardHelper: KeyboardHelper, keyboardDidShowWithState state: KeyboardState) {
        keyboardIntersectionHeight = state.intersectionHeightForView(self.view)
    }

    func keyboardHelper(keyboardHelper: KeyboardHelper, keyboardWillHideWithState state: KeyboardState) {}
    func keyboardHelper(keyboardHelper: KeyboardHelper, keyboardWillShowWithState state: KeyboardState) {}
}
