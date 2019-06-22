//
//  ViewController.swift
//  Find My Way
//
//  Created by AnDy on 6/19/19.
//  Copyright © 2019 AnDy. All rights reserved.
//

import UIKit
import MapKit
import  CoreLocation

class MapVC: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var view1: UIView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var destinationLabel: UILabel!
    @IBOutlet weak var expectedTimeLabel: UILabel!
    @IBOutlet weak var mapPin: UIImageView!
    @IBOutlet weak var goBtn: UIButton!
    @IBOutlet var view2: UIView!
    
    let locationManager = CLLocationManager()
    let regionRadius : Double = 1000
    let geoCoder = CLGeocoder()
    var myLocation : String?
    var destination : String?
    let annotation = MKPointAnnotation()
    var directionsArray: [MKDirections] = []
    var expectedTravelTime : TimeInterval?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        configureUserLocation()
    }
    
    @IBAction func goBtnPressed(_ sender: UIButton) {
        view1.isHidden = false
        
        goBtn.isHidden = true
        
        destinationLabel.text = destination
        let newExpectedTime = Int(expectedTravelTime ?? 0) / 60
        expectedTimeLabel.text = "\(newExpectedTime) Min"
        getDirections()
        
    }
    
    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        
        view1.isHidden = true
        goBtn.isHidden = false
        mapPin.isHidden = false
        mapView.removeOverlays(mapView.overlays)
        let _ = directionsArray.map { $0.cancel() }
        mapView.removeAnnotations(mapView.annotations)
        centerMapOnUserLocation()
    }
    
    //MARK:- CONFIGURE USER LOCATION
    func configureUserLocation(){
        if CLLocationManager.locationServicesEnabled() {
            configureLocationManager()
            checkAuthorizationStatus()
        }
    }
    
    //MARK:- CONFIGURE THE LOCATION MANAGER
    func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    
    //MARK:- CHECK AUTHORIZATION STATUS
    func checkAuthorizationStatus(){
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways :
            startTrackingUserLocation()
            break
        case .authorizedWhenInUse :
            startTrackingUserLocation()
            break
        case .denied :
            self.showAltertControllerWithAction(title: "Error", message: "Your Location Service isn't Enabled ", altertStyle: .alert, actionTitle: "Dismiss", actionStyle: .default)
            break
        case .notDetermined :
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted :
            self.showAltertControllerWithAction(title: "Error", message: "You are Restricted to Use Location ", altertStyle: .alert, actionTitle: "Dismiss", actionStyle: .default)
            break
        }
    }
    
    //MARK:- START TRACKING LOCATING USER
    func startTrackingUserLocation(){
        mapView.showsUserLocation = true
        centerMapOnUserLocation()
        locationManager.startUpdatingLocation()
        
    }
    
    
    //MARK:- CENTER MAP ON USER LOCATION
    func centerMapOnUserLocation(){
        guard let location = locationManager.location?.coordinate else {return}
        
        let coordinateRegion = MKCoordinateRegion.init(center: location, latitudinalMeters: regionRadius * 2, longitudinalMeters: regionRadius * 2)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    
    //MARK:- GET COORDINATE OF CENTER OF MAP
    func getCenterMapLocation() ->CLLocation{
        let latitude = mapView.centerCoordinate.latitude
        let longitude = mapView.centerCoordinate.longitude
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    
    //MARK:- GET DIRECTIONS
    func getDirections(){
        let request = getDirectionRequest()
        let directions = MKDirections(request: request)
        resetMapView(withNew: directions)
        
        directions.calculate { (response, error) in
            
            guard let response = response else {return}
            
            for routes in response.routes {
                self.mapView.addOverlay(routes.polyline)
                self.mapView.setVisibleMapRect(routes.polyline.boundingMapRect, animated: true)
                DispatchQueue.main.async {
                    self.expectedTravelTime = routes.expectedTravelTime
                }
            }
        }
        
        annotation.title = "Your Destnation"
        annotation.coordinate = getCenterMapLocation().coordinate
        mapView.addAnnotation(annotation)
        
        mapPin.isHidden = true
    }
    
    
    
    //MARK:- GET DIRECTIONS REQUEST
    func getDirectionRequest() -> MKDirections.Request {
        
        guard let location = locationManager.location?.coordinate else {return MKDirections.Request()}
        let destination = getCenterMapLocation().coordinate
        
        let locationCoordinate = MKPlacemark(coordinate: location)
        let destinationCoordinate = MKPlacemark(coordinate: destination)
        
        let requst = MKDirections.Request()
        requst.source = MKMapItem(placemark: locationCoordinate)
        requst.destination = MKMapItem(placemark: destinationCoordinate)
        requst.transportType = .automobile
        requst.requestsAlternateRoutes = false
        return requst
    }
    
    
    //MARK:- RESET ALL DIRECTIONS
    func resetMapView(withNew directions: MKDirections) {
        mapView.removeOverlays(mapView.overlays)
        directionsArray.append(directions)
        let _ = directionsArray.map { $0.cancel() }
    }
    
    
}



//MARK:- MAP VIEW DELEGATE
extension MapVC : MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        let center = getCenterMapLocation()
        
        geoCoder.reverseGeocodeLocation(center) { (placemark, error) in
            guard let placemark = placemark?.first else { return }
            let streetNumber = placemark.subThoroughfare ?? ""
            let streetName = placemark.thoroughfare ?? ""
            
            DispatchQueue.main.async {
                self.destination = "\(streetNumber) \(streetName)"
            }
            
            let request = self.getDirectionRequest()
            let directions = MKDirections(request: request)

            directions.calculate { (response, error) in

                guard let response = response else {return}

                for routes in response.routes {
                    DispatchQueue.main.async {
                        self.expectedTravelTime = routes.expectedTravelTime
                    }
                }
            }
            
        }
    }
    
}



//MARK LOCATION MANAGER DELEGATE
extension MapVC : CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkAuthorizationStatus()
    }
    
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay  as! MKPolyline)
        renderer.strokeColor = .red
        renderer.lineWidth = 4
        return renderer
    }
    
    
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { return nil }
        
        let identifier = "Annotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView!.canShowCallout = true
        } else {
            annotationView!.annotation = annotation
        }
        
        return annotationView
    }
}

