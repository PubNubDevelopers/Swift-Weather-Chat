//
//  ViewController.swift
//  Sun
//

import UIKit
import CoreLocation
import PubNub
import PubNubChat
import PubNubChatComponents

class WeatherViewController: UIViewController {
    var chatProvider: PubNubChatProvider?
    var defaultCityName: String?

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
    
    /// Present the Message List Component
    @IBAction func startChat(_ sender: UIButton) { // Show chat for current city / location
        
      guard let channelID = cityLabel.text?.sanitizedChannelID(),
            let messageListViewModel = try? chatProvider?.messageListComponentViewModel(pubnubChannelId: channelID) else {
           preconditionFailure("Could not create intial view models")
        }
        
        // Wrap the Message List inside a Navgiation View Controller to allow for Member List navigation
        let navigation = UINavigationController()
        navigation.viewControllers = [messageListViewModel.configuredComponentView()]
    
        // Present the Message List component as a Modal on top of the current view
        self.show(navigation, sender: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        networkWeatherManager.onCompletion = { currentWeather in
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update the Component Cache with New City
            self.updateComponentWith(cityName: currentWeather.cityName)

            // Update the UI with the searched results
            self.updateInterfaceWith(weather: currentWeather)
          }
        }
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
        }
      
      // Process default city that was passed in from Scene Delegate
      displayDefaultCity()
    }
  
    func displayDefaultCity() {
      if let defaultCityName = defaultCityName {
        // Fetch the default city
        networkWeatherManager.fetchCurrentWeather(forRequestType: .cityName(city: defaultCityName))
        
        // Preempt the label update while in case we need to wait for permissions
        cityLabel?.text = defaultCityName
        
        // Clear the default after initial load
        self.defaultCityName = nil
      }
    }
  
  
    func updateComponentWith(cityName: String) {
      // Ensure that the City is valid, and not a duplicate of current city
      guard !cityName.isEmpty, cityName != cityLabel.text, let currentUserId = chatProvider?.currentUserId else {
        print("New City \(cityName) was empty or a duplicate of the current city.")
        return
      }
      
      // Unsubscribe from old city (if it exists)
      if let oldCity = cityLabel.text {
        chatProvider?.pubnubProvider.unsubscribe(.init(channels: [oldCity]))
      }
      
      // Create cached Channel for new city
      let channel = PubNubChatChannel(
        id: cityName.sanitizedChannelID(),
        name: cityName,
        type: "direct",
        avatarURL: URL(randomImageSeed: cityName)
      )
      
      // Create a membership between the User and the Channel for Member Presence
      var membership = PubNubChatMember(pubnubChannelId: channel.id, pubnubUserId: currentUserId)
      // Set the channel to also store it when storing this membership
      membership.channel = channel
      
      // Store the Membership (and Channel) and then start subscribing after it's completed
      chatProvider?.dataProvider.load(members: [membership], completion: { [weak self] in
        // Search History for the Channel
        self?.chatProvider?.dataProvider.syncRemoteMessages(MessageHistoryRequest(channels: [channel.id]), completion: nil)
        
        // Subscribe to the Channel
        self?.chatProvider?.pubnubProvider.subscribe(.init(channels: [channel.id], withPresence: true))
      })
    }
    
    func updateInterfaceWith(weather: CurrentWeather) {
        cityLabel.text = weather.cityName
        temperatureLabel.text = weather.temperatureString
        feelsLikeTemperatureLabel.text = weather.feelsLikeTemperatureString
        weatherIconImageView.image = UIImage(systemName: weather.systemIconNameString)
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        networkWeatherManager.fetchCurrentWeather(forRequestType: .coordinate(latitude: latitude, longitude: longitude))
    }
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // Query for the city if permission changes
    if let cityLabelText = cityLabel.text {
      networkWeatherManager.fetchCurrentWeather(forRequestType: .cityName(city: cityLabelText))
    }
  }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
}
