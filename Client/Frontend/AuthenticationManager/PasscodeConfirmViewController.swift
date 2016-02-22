/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import SwiftKeychainWrapper
import Shared

let NotificationPasscodeDidCreate   = "NotificationPasscodeDidCreate"
let NotificationPasscodeDidChange   = "NotificationPasscodeDidChange"
let NotificationPasscodeDidRemove   = "NotificationPasscodeDidRemove"

enum PasscodeConfirmAction {
    case Created
    case Removed
    case Changed
}

private let PaneSwipeDuration: NSTimeInterval = 0.3

/// Presented to the user when creating/removing/changing a passcode.
class PasscodeConfirmViewController: UIViewController {
    private lazy var pager: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.pagingEnabled = true
        scrollView.userInteractionEnabled = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private var panes = [PasscodePane]()
    private var confirmCode: String?
    private var currentPaneIndex: Int = 0

    private let confirmAction: PasscodeConfirmAction
    private var authenticationInfo: AuthenticationKeychainInfo?
    private var keyboardIntersectionHeight: CGFloat?
    private var errorToast: ErrorToast?
    private let errorPadding: CGFloat = 10

    class func newPasscodeVC() -> PasscodeConfirmViewController {
        let passcodeVC = PasscodeConfirmViewController(confirmAction: .Created)
        passcodeVC.panes = [
            PasscodePane(title: AuthenticationStrings.enterAPasscode),
            PasscodePane(title: AuthenticationStrings.reenterPasscode),
        ]
        return passcodeVC
    }

    class func changePasscodeVC() -> PasscodeConfirmViewController {
        let passcodeVC = PasscodeConfirmViewController(confirmAction: .Changed)
        passcodeVC.panes = [
            PasscodePane(title: AuthenticationStrings.enterPasscode),
            PasscodePane(title: AuthenticationStrings.enterNewPasscode),
        ]
        return passcodeVC
    }

    class func removePasscodeVC() -> PasscodeConfirmViewController {
        let passcodeVC = PasscodeConfirmViewController(confirmAction: .Removed)
        passcodeVC.panes = [
            PasscodePane(title: AuthenticationStrings.enterPasscode),
            PasscodePane(title: AuthenticationStrings.reenterPasscode),
        ]
        return passcodeVC
    }

    init(confirmAction: PasscodeConfirmAction) {
        self.confirmAction = confirmAction
        self.authenticationInfo = KeychainWrapper.authenticationInfo()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardHelper.defaultHelper.addDelegate(self)
        view.backgroundColor = UIConstants.TableViewHeaderBackgroundColor
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: Selector("dismiss"))
        view.addSubview(pager)
        automaticallyAdjustsScrollViewInsets = false
        panes.forEach { pager.addSubview($0) }
        pager.snp_makeConstraints { make in
            make.bottom.left.right.equalTo(self.view)
            make.top.equalTo(self.snp_topLayoutGuideBottom)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        panes.enumerate().forEach { index, pane in
            pane.frame = CGRect(origin: CGPoint(x: CGFloat(index) * pager.frame.width, y: 0), size: pager.frame.size)
        }
        pager.contentSize = CGSize(width: CGFloat(panes.count) * pager.frame.width, height: pager.frame.height)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        panes.first?.codeInputView.delegate = self
        panes.first?.codeInputView.becomeFirstResponder()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.endEditing(true)
    }
}

extension PasscodeConfirmViewController {
    private func scrollToNextPane() {
        guard (currentPaneIndex + 1) < panes.count else {
            return
        }
        currentPaneIndex += 1
        scrollToPaneAtIndex(currentPaneIndex)
    }

    private func scrollToPreviousPane() {
        guard (currentPaneIndex - 1) >= 0 else {
            return
        }
        currentPaneIndex -= 1
        scrollToPaneAtIndex(currentPaneIndex)
    }

    private func scrollToPaneAtIndex(index: Int) {
        UIView.animateWithDuration(PaneSwipeDuration, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
            self.pager.contentOffset = CGPoint(x: CGFloat(self.currentPaneIndex) * self.pager.frame.width, y: 0)
        }, completion: nil)
    }

    @objc private func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
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

extension PasscodeConfirmViewController: PasscodeInputViewDelegate {
    func passcodeInputView(inputView: PasscodeInputView, didFinishEnteringCode code: String) {
        if currentPaneIndex == 0 {
            // Constraint: When removing or changing a passcode, we need to make sure that the first passcode they've
            // entered matches the one stored in the keychain
            if (confirmAction == .Removed || confirmAction == .Changed) && code != authenticationInfo?.passcode {
                displayError(AuthenticationStrings.wrongPasscodeError)
                inputView.resetCode()
                inputView.becomeFirstResponder()
                return
            }

            confirmCode = code
            scrollToNextPane()
            let nextPane = panes[currentPaneIndex]
            nextPane.codeInputView.becomeFirstResponder()
            nextPane.codeInputView.delegate = self
        } else if currentPaneIndex == 1 {
            // Constraint: When changing passcodes, the new passcode cannot match their old passcode.
            if confirmAction == .Changed && confirmCode == code {
                let useNewPasscodeError
                    = NSLocalizedString("New passcode must be different than existing code.",
                        tableName: "AuthenticationManager",
                        comment: "Error message displayed when user tries to enter the same passcode as their existing code when changing it.")
                displayError(useNewPasscodeError)
                resetConfirmation()
                return
            }

            // Constraint: When removing/creating passcodes, the first and confirmation codes must match.
            if (confirmAction == .Created || confirmAction == .Removed) && confirmCode != code {
                let mismatchPasscodeError
                    = NSLocalizedString("Passcodes didn't match. Try again.",
                        tableName: "AuthenticationManager",
                        comment: "Error message displayed to user when their confirming passcode doesn't match the first code.")
                displayError(mismatchPasscodeError)
                resetConfirmation()
                return
            }

            performActionAndNotify(confirmAction, forCode: code)
            dismiss()
        }
    }

    private func resetConfirmation() {
        scrollToPreviousPane()
        confirmCode = nil
        let previousPane = panes[currentPaneIndex]
        panes.forEach { $0.codeInputView.resetCode() }
        previousPane.codeInputView.becomeFirstResponder()
    }

    private func performActionAndNotify(confirmAction: PasscodeConfirmAction, forCode code: String) {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        let notificationName: String
        switch confirmAction {
        case .Changed:
            authenticationInfo?.updatePasscode(code)
            notificationName = NotificationPasscodeDidChange
        case .Created:
            authenticationInfo = AuthenticationKeychainInfo(passcode: code)
            notificationName = NotificationPasscodeDidCreate
        case .Removed:
            authenticationInfo = nil
            notificationName = NotificationPasscodeDidRemove
        }

        KeychainWrapper.setAuthenticationInfo(authenticationInfo)
        notificationCenter.postNotificationName(notificationName, object: nil)
    }
}

extension PasscodeConfirmViewController: KeyboardHelperDelegate {
    func keyboardHelper(keyboardHelper: KeyboardHelper, keyboardDidShowWithState state: KeyboardState) {
        keyboardIntersectionHeight = state.intersectionHeightForView(self.view)
    }

    func keyboardHelper(keyboardHelper: KeyboardHelper, keyboardWillHideWithState state: KeyboardState) {}
    func keyboardHelper(keyboardHelper: KeyboardHelper, keyboardWillShowWithState state: KeyboardState) {}
}