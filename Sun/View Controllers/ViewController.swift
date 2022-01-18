//
//  ViewController.swift
//  Sun
//

import UIKit
import CoreLocation
import PubNub
import PubNubChat
import PubNubChatComponents

class ViewController: UIViewController {
    var chatProvider: PubNubChatProvider?
    var channelId = "San Francisco" // Default channel
    var chatView: UIView!
    
    // Create PubNub Configuration
    lazy var pubnubConfiguration = {
      return PubNubConfiguration(
        publishKey: PUBNUB_PUBLISH_KEY, // see Constants.swift to set PubNub API keys
        subscribeKey: PUBNUB_SUBSCRIBE_KEY,
        uuid: randomString(length: 6)
      )
    }()
    
    func randomString(length: Int) -> String { // Used to create a random username/uuid for chat
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    @IBOutlet weak var weatherIconImageView: UIImageView!
    @IBOutlet weak var cityLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var feelsLikeTemperatureLabel: UILabel!
    
    var networkWeatherManager = NetworkWeatherManager()
    lazy var locationManager: CLLocationManager = {
        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyKilometer
        lm.requestWhenInUseAuthorization()
        return lm
    }()
   
    @IBAction func searchPressed(_ sender: UIButton) {
        self.presentSearchAlertController(withTitle: "Enter city name", message: nil, style: .alert) { [unowned self] city in
            self.networkWeatherManager.fetchCurrentWeather(forRequestType: .cityName(city: city))
        }
    }
    
    @IBAction func startChat(_ sender: UIButton) { // Show chat for current city / location
        chatView=UIView(frame: self.view.bounds)

        // PubNub.log.levels = [.all]
        // PubNub.log.writers = [ConsoleLogWriter()]
        
        guard let messageListViewModel = try! chatProvider?.messageListComponentViewModel(pubnubChannelId: channelId) else {
           preconditionFailure("Could not create intial view models")
        }

        /*messageListViewModel.componentDidLoad = { (viewModel) in
            let request = MessageHistoryRequest(channels: [self.channelId], limit: 10, start: nil)
            viewModel?.provider.dataProvider.syncRemoteMessages(request, completion: nil)
        }*/
        
        let navigation = UINavigationController()
        navigation.viewControllers = [messageListViewModel.configuredComponentView()]
    
        self.show(navigation, sender: nil)
    }
    
    func preloadData(_ chatProvider: PubNubChatProvider) {
        // Create a user object with UUID
        let user = PubNubChatUser(
          id: chatProvider.pubnubConfig.uuid,
          name: chatProvider.pubnubConfig.uuid,
          avatarURL: URL(string: "https://picsum.photos/seed/\(chatProvider.pubnubConfig.uuid)/200")
        )
        
        // Create a channel object
        let channel = PubNubChatChannel(
          id: channelId,
          name: channelId,
          type: "direct",
          avatarURL: URL(string: "https://picsum.photos/seed/\(channelId)/200")
        )
        
        // Create a membership between the User and the Channel for subscription purposes
        let membership = PubNubChatMember(channel: channel, member: user)
        
        // Subscribe to the channel
        chatProvider.pubnubProvider.subscribe(.init(channels: [channelId], withPresence: true))
        
        // Fill database with the user, channel, and memberships data
        chatProvider.dataProvider.load(members: [membership])
      }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        networkWeatherManager.onCompletion = { [weak self] currentWeather in
            guard let self = self else { return }
            self.updateInterfaceWith(weather: currentWeather)
        }
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
        }
        
        // Create a new ChatProvider
        let provider = PubNubChatProvider(
        pubnubConfiguration: pubnubConfiguration
        )
        // Preload Data
        preloadData(provider)
        // Assign for future use
        chatProvider = provider

    }
    
    func updateInterfaceWith(weather: CurrentWeather) {
        DispatchQueue.main.async {
            self.channelId = weather.cityName
            if let provider = self.chatProvider {
                self.preloadData(provider) // Update chat provider with new channel data
              }
            self.cityLabel.text = weather.cityName
            self.temperatureLabel.text = weather.temperatureString
            self.feelsLikeTemperatureLabel.text = weather.feelsLikeTemperatureString
            self.weatherIconImageView.image = UIImage(systemName: weather.systemIconNameString)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        networkWeatherManager.fetchCurrentWeather(forRequestType: .coordinate(latitude: latitude, longitude: longitude))
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
}
