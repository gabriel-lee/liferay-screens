/**
* Copyright (c) 2000-present Liferay, Inc. All rights reserved.
*
* This library is free software; you can redistribute it and/or modify it under
* the terms of the GNU Lesser General Public License as published by the Free
* Software Foundation; either version 2.1 of the License, or (at your option)
* any later version.
*
* This library is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
* details.
*/
import UIKit

@objc protocol ForgotPasswordWidgetDelegate {

	optional func onForgotPasswordResponse(newPasswordSent:Bool)
	optional func onForgotPasswordError(error: NSError)

}

@IBDesignable public class ForgotPasswordWidget: BaseWidget {

	@IBInspectable var anonymousApiUserName: String?
	@IBInspectable var anonymousApiPassword: String?

	@IBOutlet var delegate: ForgotPasswordWidgetDelegate?


	private typealias ResetClosureType = (String, LRMobilewidgetsuserService_v62, (NSError)->()) -> (Void)

	private let resetClosures = [
		AuthType.Email.toRaw(): resetPasswordWithEmail,
		AuthType.ScreenName.toRaw(): resetPasswordWithScreenName,
		AuthType.UserId.toRaw(): resetPasswordWithUserId]

	private var resetClosure: ResetClosureType?

	
	public func setAuthType(authType:String) {
		forgotPasswordView().setAuthType(authType)

		resetClosure = resetClosures[authType]
	}

	// MARK: BaseWidget METHODS

	override internal func onCreated() {
		setAuthType(AuthType.Email.toRaw())

		if let userName = LiferayContext.instance.currentSession?.username {
			forgotPasswordView().setUserName(userName)
		}
	}

	override internal func onCustomAction(actionName: String?, sender: AnyObject?) {
		sendForgotPasswordRequest(forgotPasswordView().getUserName())
	}

	override internal func onServerError(error: NSError) {
		delegate?.onForgotPasswordError?(error)

		finishOperationWithError(error, message:"Error requesting password!")
	}

	override internal func onServerResult(result: [String:AnyObject]) {
		if let resultValue:AnyObject = result["result"] {
			let newPasswordSent = resultValue as Bool

			delegate?.onForgotPasswordResponse?(newPasswordSent)

			let userMessage = newPasswordSent ? "New password generated" : "New password reset link sent"

			finishOperationWithMessage(userMessage, details: "Check your email inbox")
		}
		else {
			var errorMsg:String? = result["error"]?.description

			if errorMsg == nil {
				errorMsg = result["exception.localizedMessage"]?.description
			}

			finishOperationWithMessage("An error happened", details: errorMsg)
		}
	}


	private func forgotPasswordView() -> ForgotPasswordView {
		return widgetView as ForgotPasswordView
	}

	private func sendForgotPasswordRequest(username:String) {
		if anonymousApiUserName == nil || anonymousApiPassword == nil {
			println(
				"ERROR: The credentials to use for anonymous API calls must be set in order to use " +
					"ForgotPasswordWidget")

			return
		}

		startOperationWithMessage("Sending password request...", details:"Wait few seconds...")

		let session = LiferayContext.instance.createSession(anonymousApiUserName!, password: anonymousApiPassword!)

		session.callback = self

		let companyId: CLongLong = (LiferayContext.instance.companyId as NSNumber).longLongValue

		resetClosure!(username, LRMobilewidgetsuserService_v62(session: session)) {error in
			self.onFailure(error)
		}
	}
}

func resetPasswordWithEmail(email:String, service:LRMobilewidgetsuserService_v62, onError:(NSError)->()) {
	let companyId = (LiferayContext.instance.companyId as NSNumber).longLongValue

	var outError: NSError?

	service.sendPasswordByEmailAddressWithCompanyId(companyId, emailAddress: email, error: &outError)

	if let error = outError {
		onError(error)
	}
}

func resetPasswordWithScreenName(screenName:String, service:LRMobilewidgetsuserService_v62, onError:(NSError)->()) {
	let companyId = (LiferayContext.instance.companyId as NSNumber).longLongValue

	var outError: NSError?

	service.sendPasswordByScreenNameWithCompanyId(companyId, screenName: screenName, error: &outError)

	if let error = outError {
		onError(error)
	}
}

func resetPasswordWithUserId(userId:String, service:LRMobilewidgetsuserService_v62, onError:(NSError)->()) {

	let userIdValue = (userId.toInt()! as NSNumber).longLongValue

	var outError: NSError?

	service.sendPasswordByUserIdWithUserId(userIdValue, error: &outError)

	if let error = outError {
		onError(error)
	}
}