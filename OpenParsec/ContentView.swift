import SwiftUI

enum ViewType
{
	case login
	case main
	case parsec
}

struct ContentView:View
{
	@State var curView:ViewType = .login

	let defaultTransition = AnyTransition.move(edge:.trailing)

	var body:some View
	{
		ZStack()
		{
			switch curView
			{
				case .login:
					LoginView(self)
				case .main:
					MainView(self)
						.transition(defaultTransition)
				case .parsec:
					ParsecView(self)
			 }
		}
		.onAppear(perform:initApp)
		.background(Rectangle().fill(Color.black).edgesIgnoringSafeArea(.all))
	}

	func initApp()
	{
		CParsec.initialize()

		// Check to see if we have old session data
		if let data = loadFromKeychain(key: GLBDataModel.shared.SessionKeyChainKey)
		{
			let decoder = JSONDecoder()

			NSLog("Retrieved data from keychain: \(data).\nTrying to restore session.")
			NetworkHandler.clinfo = try? decoder.decode(ClientInfo.self, from:data)
			if NetworkHandler.clinfo != nil
			{
				curView = .main
				NSLog("Session restored and moved to the main page.")
			}
			else
			{
				NSLog("Unable to restore session, falling back to login page.")
			}
		}

		NSLog("Initialized")
	}

	func loadFromKeychain(key: String) -> Data?
	{
		let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecReturnData as String: kCFBooleanTrue!, kSecMatchLimit as String: kSecMatchLimitOne]
		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		guard status == errSecSuccess else
		{
			if status != errSecItemNotFound
			{
				NSLog("Error loading from keychain: \(status)")
			}
			return nil
		}
		guard let data = item as? Data else
		{
			return nil
		}
		return data
	}

	public func setView(_ t:ViewType)
	{
		withAnimation(.easeInOut) { curView = t }
	}
}

struct ContentView_Previews:PreviewProvider
{
	static var previews:some View
	{
		ContentView()
	}
}
