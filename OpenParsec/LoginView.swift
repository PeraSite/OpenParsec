import SwiftUI
import os

struct LoginView:View
{
	var controller:ContentView?

	@State var inputEmail:String = ""
	@State var inputPassword:String = ""
	@State var inputTFA:String = ""
	@State var isTFAOn:Bool = false
	@State private var presentTFAAlert = false
	@State var isLoading:Bool = false
	@State var showAlert:Bool = false
	@State var alertText:String = ""

	init(_ controller:ContentView?)
	{
		self.controller = controller
	}

	var body:some View
	{
		ZStack()
		{
			// Background
			Rectangle()
				.fill(Color("BackgroundGray"))
				.edgesIgnoringSafeArea(.all)

			// Login controls
			VStack(spacing:8)
			{
				HStack(spacing:2)
				{
					Image("IconTransparent")
						.resizable()
						.aspectRatio(contentMode: .fit)
					Image("LogoShadow")
						.resizable()
						.aspectRatio(contentMode: .fit)
						.padding([.top, .bottom, .trailing])
				}
				.frame(height:80)
				TextField("Email", text:$inputEmail)
					.padding()
					.background(Rectangle().fill(Color("BackgroundField")))
					.cornerRadius(8)
					.disableAutocorrection(true)
					.autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
					.keyboardType(.emailAddress)
					.textContentType(.emailAddress)
				SecureField("Password", text:$inputPassword)
					.padding()
					.background(Rectangle().fill(Color("BackgroundField")))
					.cornerRadius(8)
					.disableAutocorrection(true)
					.autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
					.textContentType(.password)
				Button(action:{authenticate()})
				{
					ZStack()
					{
						Rectangle()
							.fill(Color("AccentColor"))
							.cornerRadius(8)
						Text("Login")
							.foregroundColor(.white)
					}
					.frame(height:54)
				}
			}
			
			.padding()
			.frame(maxWidth:400)
			.disabled(isLoading) // Disable when loading

			// Loading elements
			if isLoading || presentTFAAlert
			{
				ZStack()
				{
					Rectangle() // Darken background
						.fill(Color.black)
						.opacity(0.5)
						.edgesIgnoringSafeArea(.all)
					VStack()
					{
						if isLoading
						{
							ActivityIndicator(isAnimating:$isLoading, style:.large, tint:.white)
							 .padding()
						 Text("Loading...")
							 .multilineTextAlignment(.center)
						}
						else if presentTFAAlert
						{
							Text("Please enter your 2FA code from your authenticator app")
								.multilineTextAlignment(.center)
							SecureField("2FA Code", text:$inputTFA)
								.padding()
								.background(Rectangle().fill(Color("BackgroundField")))
								.foregroundColor(Color("Foreground"))
								.cornerRadius(8)
								.disableAutocorrection(true)
								.autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
								.textContentType(.oneTimeCode)
							HStack()
							{
								Button(action:{presentTFAAlert = false})
								{
									ZStack()
									{
										Rectangle()
											.fill(Color("BackgroundButton"))
											.cornerRadius(8)
										Text("Cancel")
											.foregroundColor(Color("Foreground"))
									}
									.frame(height:54)
								}
								Button(action:{authenticate(inputTFA)})
								{
									ZStack()
									{
										Rectangle()
											.fill(Color("AccentColor"))
											.cornerRadius(8)
										Text("Enter")
											.foregroundColor(.white)
									}
									.frame(height:54)
								}
							}
						}
					}
					.padding()
					.background(Rectangle().fill(Color("BackgroundPrompt")))
					.cornerRadius(8)
					.padding()
				}
			}
		}
		.foregroundColor(Color("Foreground"))
		.alert(isPresented:$showAlert)
		{
			Alert(title:Text(alertText))
		}
	}

	func saveToKeychain(data: Data, key: String)
	{
		let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecValueData as String: data]
		let status = SecItemAdd(query as CFDictionary, nil)
		guard status == errSecSuccess else
		{
			NSLog("Error saving to Keychain: \(status)")
			return
		}
		NSLog("Data saved to Keychain.")
	}

	func authenticate(_ tfa:String? = "")
	{
		#if DEBUG
		if inputEmail == "test@example.com" // skip authentication (DEBUG ONLY)
		{
			if let c = controller
			{
				c.setView(.main)
			}
			return
		}
		#endif

		withAnimation { isLoading = true }

		let apiURL = URL(string:"https://kessel-api.parsec.app/v1/auth")!

		var request = URLRequest(url:apiURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
		request.httpMethod = "POST";
		request.allHTTPHeaderFields = [
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1",
            "Content-Type": "application/json"
        ]
		request.httpBody = try? JSONSerialization.data(withJSONObject:
		[
			"email":inputEmail,
			"password":inputPassword,
			"tfa": tfa
		], options:[])

		let task = URLSession.shared.dataTask(with:request)
		{ (data, response, error) in
			isLoading = false
			if let data = data
			{
				let statusCode:Int = (response as! HTTPURLResponse).statusCode
				let decoder = JSONDecoder()

				NSLog("Login Information:")
				NSLog(String(statusCode))
                let longString = String(data: data, encoding: .utf8)!

                let chunkLength = 1024
                var chunks: [String] = []
                let stringLength = longString.count
                var startIndex = longString.startIndex

                while startIndex < longString.endIndex {
                    let endIndex = longString.index(startIndex, offsetBy: chunkLength, limitedBy: longString.endIndex) ?? longString.endIndex
                    let chunk = String(longString[startIndex..<endIndex])
                    chunks.append(chunk)
                    startIndex = endIndex
                }

                // Print chunks to verify
                for (index, chunk) in chunks.enumerated() {
                    NSLog(chunk)
                }

				if statusCode == 201 // 201 Created
				{
					// store it and recover it from the next app opening, so people won't swear
					NetworkHandler.clinfo = try? decoder.decode(ClientInfo.self, from:data)

					saveToKeychain(data: data, key: GLBDataModel.shared.SessionKeyChainKey)

					if let c = controller
					{
						NSLog("*** Login succeeded! ***")
						c.setView(.main)
					}
				}
				else if statusCode >= 400 // 4XX client errors
				{
					let info:ErrorInfo = try! decoder.decode(ErrorInfo.self, from:data)

					do
					{
						let json = try JSONSerialization.jsonObject(with: data, options: [])
						if let dict = json as? [String: Any], let isTFARequired = dict["tfa_required"] as? Bool {
							NSLog("Code output:")
							NSLog(dict.description)
							if isTFARequired
							{
								presentTFAAlert = true
							}
							else
							{
								alertText = "Error: \(info)"
								showAlert = true
							}
						}
					}
					catch
					{
						NSLog("Error on trying JSON Serialization on error data!")
					}
				}
			}
		}
		task.resume()
	}
}

struct LoginView_Previews:PreviewProvider
{
	static var previews:some View
	{
		LoginView(nil)
	}
}
