//
//  GpsUtils.swift
//  TermiWatch WatchKit Extension
//
//  Created by Vlad Ekimtcov on 10/10/20.
//  Copyright © 2020 Librecz Gábor. All rights reserved.
//

import Foundation
import HealthKit
import PMKCoreLocation
import PMKHealthKit
import CoreLocation
import PromiseKit
import Swizzle
import WatchKit


// MARK: - Distance to base
func distToBase(at coordinate: CLLocationCoordinate2D) -> Promise<Measurement<UnitLength>> {
    return Promise { seal in
        let coordinate1 = CLLocation(latitude: 40.109434, longitude: -88.234863)
        
        let getLat: CLLocationDegrees = coordinate.latitude
        let getLon: CLLocationDegrees = coordinate.longitude
        let coordinate2: CLLocation =  CLLocation(latitude: getLat, longitude: getLon)
        
        var output = Measurement(value:coordinate1.distance(from: coordinate2), unit: UnitLength.meters)
        
        switch output.value {
        case _ where output.value > 10000:
            output = Measurement(value:output.value/1000, unit: UnitLength.kilometers)
        case _ where output.value < 100:
            output = Measurement(value:0, unit: UnitLength.meters)
        default:
            ()
        }
        
        seal.fulfill(output)
    }
}




// MARK: - GPS location checker
public class LocationNotifier {
  public static let LocationDidChange = Notification.Name(
    rawValue: "LocationNotifier.LocationDidChange"
  )

  public static let shared = LocationNotifier()
  private init() {}

  public private(set) var dist: Measurement<UnitLength>?
  private var timer: Timer?

  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }

  public func start(withTimeInterval interval: TimeInterval = 60) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
      CLLocationManager.requestLocation().lastValue.then {
        distToBase(at: $0.coordinate)
      }.done { currentDist in
        if currentDist == self?.dist {
          return
        }

        self?.dist = currentDist

        NotificationCenter.default.post(
          Notification(
            name: LocationNotifier.LocationDidChange,
            object: self?.dist,
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
