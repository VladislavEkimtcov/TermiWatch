import CoreLocation
import Foundation
import PMKCoreLocation
import PMKFoundation
import PromiseKit

func OpenWeatherMapAPIKey() -> String {
  return Bundle.main.object(
    forInfoDictionaryKey: "OpenWeatherMapAPIKey"
  ) as! String
}

func OpenWeatherMapURL(
  coordinate: CLLocationCoordinate2D,
  apiKey: String = OpenWeatherMapAPIKey()
) -> URL {
  return URL(
    string: "https://api.openweathermap.org/data/2.5/weather?"
      + "lat=\(coordinate.latitude)"
      + "&lon=\(coordinate.longitude)"
      + "&APPID=\(apiKey)"
  )!
}

let disabledCachingConfig: (URLSessionConfiguration) -> Void = {
  $0.requestCachePolicy = .reloadIgnoringLocalCacheData
  $0.urlCache = nil
}

// MARK: - OpenWeatherMapResponse
struct OpenWeatherMapResponse: Codable {
  struct MainResponse: Codable {
    let temp: Double
  }
  let main: MainResponse
    
  struct SysResponse: Codable {
    let sunrise: Double
    let sunset: Double
  }
  let sys: SysResponse
    
    let timezone: Double
    
}

// MARK: - Temperature in Kelvin
func temperatureInKelvin(at coordinate: CLLocationCoordinate2D)
  -> Promise<Measurement<UnitTemperature>> {
  return Promise { seal in
    let sessionConfig = URLSessionConfiguration.default
    disabledCachingConfig(sessionConfig)

    URLSession(configuration: sessionConfig).dataTask(
      .promise,
      with: OpenWeatherMapURL(coordinate: coordinate)
    ).compactMap {
      try JSONDecoder().decode(OpenWeatherMapResponse.self, from: $0.data)
    }.done {
      let temperatureInKelvin = Measurement(
        value: $0.main.temp,
        unit: UnitTemperature.kelvin
      )

      seal.fulfill(temperatureInKelvin)
    }.catch {
      print("Error:", $0)
    }
  }
}

// MARK: - TemperatureNotifier
public class TemperatureNotifier {
  public static let TemperatureDidChangeNotification = Notification.Name(
    rawValue: "TemperatureNotifier.TemperatureDidChangeNotification"
  )

  public static let shared = TemperatureNotifier()
  private init() {}

  public private(set) var temperature: Measurement<UnitTemperature>?
  private var timer: Timer?

  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }

  public func start(withTimeInterval interval: TimeInterval = 600) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
      CLLocationManager.requestLocation().lastValue.then {
        temperatureInKelvin(at: $0.coordinate)
      }.done { currentTemperature in
        if currentTemperature == self?.temperature {
          return
        }

        self?.temperature = currentTemperature

        NotificationCenter.default.post(
          Notification(
            name: TemperatureNotifier.TemperatureDidChangeNotification,
            object: self?.temperature,
            userInfo: nil
          )
        )
      }.catch {
        print("Error:", $0.localizedDescription)
      }
    }

    timer!.fire()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}

// MARK: - Sun Caller
let calendar = Calendar.current

func callSun(coordinate: CLLocationCoordinate2D)
  -> Promise<String> {
  return Promise { seal in
    let sessionConfig = URLSessionConfiguration.default
    disabledCachingConfig(sessionConfig)

    URLSession(configuration: sessionConfig).dataTask(
      .promise,
      with: OpenWeatherMapURL(coordinate: coordinate)
    ).compactMap {
      try JSONDecoder().decode(OpenWeatherMapResponse.self, from: $0.data)
    }.done {
        let sunUp = Date(timeIntervalSince1970: $0.sys.sunrise+$0.timezone+18000)
        let sunDown = Date(timeIntervalSince1970: $0.sys.sunset+$0.timezone+18000)
        
        let hourUp = calendar.component(.hour, from: sunUp)
        let minutesUp = calendar.component(.minute, from: sunUp)
        
        let hourDown = calendar.component(.hour, from: sunDown)
        let minutesDown = calendar.component(.minute, from: sunDown)

//      seal.fulfill(String(format: "%f:%f up", hourUp, minutesUp))
//        seal.fulfill("\(hourUp):\(minutesUp)//\(hourDown):\(minutesDown)")
        seal.fulfill(String(format: "%02d:%02d//%02d:%02d", hourUp, minutesUp, hourDown, minutesDown))
    }.catch {
      print("Error:", $0)
    }
  }
}


// MARK: - SunNotifier
public class SunNotifier {
  public static let SunDidChange = Notification.Name(
    rawValue: "SunNotifier.SunDidChange"
  )

  public static let shared = SunNotifier()
  private init() {}

  public private(set) var sun: String?
  private var timer: Timer?

  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }

  public func start(withTimeInterval interval: TimeInterval = 600) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
      CLLocationManager.requestLocation().lastValue.then {
        callSun(coordinate: $0.coordinate)
      }.done { sunTimes in
        if sunTimes == self?.sun {
          return
        }

        self?.sun = sunTimes

        NotificationCenter.default.post(
          Notification(
            name: SunNotifier.SunDidChange,
            object: self?.sun,
            userInfo: nil
          )
        )
      }.catch {
        print("Error:", $0.localizedDescription)
      }
    }

    timer!.fire()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}


