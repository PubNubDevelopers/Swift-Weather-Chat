//
//  ViewController.swift
//  Sun
//
//  Created by Геворг on 17.11.2021.
//

import UIKit
import CoreLocation
import PubNub
import PubNubChat
import PubNubChatComponents

let PUBNUB_PUBLISH_KEY = "pub-c-537af6b0-bad6-4ff9-84d2-8cd90bd77bc1" // "pub-c-key"
let PUBNUB_SUBSCRIBE_KEY = "sub-c-bc933fc4-7584-11ec-87be-4a1e879706fb" // "sub-c-key"

class ViewController: UIViewController {
    var chatProvider: PubNubChatProvider?
    var defaultChannelId = "my-current-channel"
    var chatView: UIView!

    
    // Create PubNub Configuration
    lazy var pubnubConfiguration = {
      return PubNubConfiguration(
        publishKey: PUBNUB_PUBLISH_KEY,
        subscribeKey: PUBNUB_SUBSCRIBE_KEY,
        uuid: UUID().uuidString
      )
    }()
    

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
    
    @IBAction func startChat(_ sender: UIButton) {
        chatView=UIView(frame: self.view.bounds)
       // guard let windowScene = (scene as? UIWindowScene) else { return }
        PubNub.log.levels = [.all]
        PubNub.log.writers = [ConsoleLogWriter()]
        
        if chatProvider == nil {
             // Create a new ChatProvider
             let provider = PubNubChatProvider(
               pubnubConfiguration: pubnubConfiguration
             )
             
             // Preload Dummy Data
           //  preloadData(provider)
            
            
             
             // Assign for future use
             chatProvider = provider
           }
        chatProvider?.pubnubProvider.subscribe(.init(channels: [defaultChannelId], withPresence: true))

        
        guard let messageListViewModel = try? chatProvider?.messageListComponentViewModel(pubnubChannelId: "defaultChannelId") else {
           preconditionFailure("Could not create intial view models")
         }
        
        let button = UIButton(frame: CGRect(x: self.view.frame.size.width-120, y: 40, width: 100, height: 40))
        button.backgroundColor = .black
        button.setTitle("Close Chat", for: .normal)
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)

    
        chatView.addSubview(messageListViewModel.configuredComponentView().view)
        chatView.addSubview(button)
        self.view.addSubview(chatView)
    }
    
    @objc func buttonAction(sender: UIButton!) {
        chatView.removeFromSuperview()
        self.chatProvider!.pubnubProvider.unsubscribe(from: [defaultChannelId], and: [defaultChannelId], presenceOnly: false)
        
    }
    
    func preloadData(_ chatProvider: PubNubChatProvider) {
        // Create a user object with UUID
      /*  let user = PubNubChatUser(
          id: chatProvider.pubnubConfig.uuid,
          name: "You",
          avatarURL: URL(string: "https://picsum.photos/seed/\(chatProvider.pubnubConfig.uuid)/200")
        )
        
        // Create a channel object
        let channel = PubNubChatChannel(
          id: defaultChannelId,
          name: "Default",
          type: "direct",
          avatarURL: URL(string: "https://picsum.photos/seed/\(defaultChannelId)/200")
        )*/
        
        // Create a membership between the User and the Channel for subscription purposes
       // let membership = PubNubChatMember(channel: channel, member: user)
        
        // Subscribe to the default channel
       // chatProvider.pubnubProvider.subscribe(.init(channels: [defaultChannelId], withPresence: true))
        
        // Fill database with the user, channel, and memberships data
       // chatProvider.dataProvider.load(members: [membership])
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
    }
    
    func updateInterfaceWith(weather: CurrentWeather) {
        DispatchQueue.main.async {
            self.defaultChannelId = weather.cityName
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
