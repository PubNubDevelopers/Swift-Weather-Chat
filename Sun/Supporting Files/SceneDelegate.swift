import UIKit

import PubNub
import PubNubChat
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?
  
  // Create PubNub Configuration
  lazy var pubnubConfiguration = {
    return PubNubConfiguration(
      publishKey: Constants.Pubnub.publishKey, // see Constants.swift to set PubNub API keys
      subscribeKey: Constants.Pubnub.subscribeKey,
      uuid: String(random: 6)
    )
  }()

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
      guard let _ = (scene as? UIWindowScene) else { return }
    
      let rootVC = self.window?.rootViewController as? WeatherViewController
      
    // Perform initial setup of the Chat Components
    if rootVC?.chatProvider == nil {
      
      // Create the ChatProvider using your configured PubNub object
      let provider = PubNubChatProvider(
        pubnubProvider: PubNub(configuration: pubnubConfiguration)
      )
      
      // Preload the Current User of the application
      preloadData(provider, initialChannelId: "San Francisco")

      // Assign for future use
      rootVC?.chatProvider = provider
    }
    
    // Set the default City inside the Weather UI
    rootVC?.defaultCityName = "San Francisco"
  }
  
  // MARK: Helpers
  
  func preloadData(_ chatProvider: PubNubChatProvider, initialChannelId: String) {
    // Create a user object with UUID
    let user = PubNubChatUser(
      id: chatProvider.pubnubConfig.uuid,
      name: chatProvider.pubnubConfig.uuid,
      avatarURL: URL(randomImageSeed: initialChannelId)
    )
    
    // Fill database with the user, channel, and memberships data
    chatProvider.dataProvider.load(users: [user])
  }
}

// MARK: Ext Helpers

extension String {
  static let alphaNumerics = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  
  /// Creates a new string containing alpha-numeric characters of length `count`
  ///
  ///  - Parameter random: The size of the String to create
  init(random count: Int) {
    self.init((0..<count).compactMap{ _ in String.alphaNumerics.randomElement() })
  }
  
  /// A String that has been lowercased and has had any whitespaces removed
  func sanitizedChannelID() -> String {
    return self.filter { !$0.isWhitespace }.lowercased()
  }
}

extension URL {
  init?(randomImageSeed: String) {
    self.init(string: "https://picsum.photos/seed/\(randomImageSeed)/200")
  }
}
