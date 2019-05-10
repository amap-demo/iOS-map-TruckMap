//
//  ViewController.swift
//  TrackMapDemo-swift
//
//  Created by zuola on 2019/5/10.
//  Copyright © 2019 zuola. All rights reserved.
//

import UIKit

class ViewController: UIViewController, MAMapViewDelegate, AMapSearchDelegate {
    let kLocationName: String = "您的位置"
    let kPointGas: String = "加油站"
    let kPointViolation: String = "违章点"
    
    var limits:Array<Any> = []
    var search: AMapSearchAPI!
    var mapView: MAMapView!
    var startCoordinate: CLLocationCoordinate2D!
    var destinationCoordinate: CLLocationCoordinate2D!
    var totalCourse: NSInteger = 0
    var previousItem: UIBarButtonItem!
    var nextItem: UIBarButtonItem!
    var pAnnotations: Array<Any>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.gray
        
        startCoordinate        = CLLocationCoordinate2DMake(39.910267, 116.370888)
        destinationCoordinate  = CLLocationCoordinate2DMake(40.589872, 117.081956)
        pAnnotations = Array.init()
        initMapView()
        initSearch()
        let sws = makeSwitchsPannelView()
        sws.center = CGPoint.init(x: sws.bounds.midX + 10, y: self.view.bounds.height - sws.bounds.midY - 70)
        
        sws.autoresizingMask = [UIView.AutoresizingMask.flexibleTopMargin, UIView.AutoresizingMask.flexibleRightMargin]
        self.view.addSubview(sws)
        initTrucklimitAreaOverlay()
        searchGasPOI()
        getViolationPOI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mapView.addOverlays(limits)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initMapView() {
        mapView = MAMapView(frame: self.view.bounds)
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = MAUserTrackingMode.follow;
        mapView.userLocation.title = kLocationName;
        self.view.addSubview(mapView)
    }
    
    func initSearch() {
        search = AMapSearchAPI()
        search.delegate = self
    }
    
    func makeSwitchsPannelView() -> UIView {
        let ret = UIView.init()
        ret.backgroundColor = UIColor.white
        let sw1 = UISwitch.init()
        let l1 = UILabel.init(frame: CGRect.init(x: 0, y: 0, width: 70, height: sw1.bounds.height))
        l1.text = "路况:"
        ret.addSubview(l1)
        ret.addSubview(sw1)
        var temp = sw1.frame
        temp.origin.x = l1.frame.maxX + 5
        sw1.frame = temp
        sw1.addTarget(self, action: #selector(self.switchTraffic(sender:)), for: UIControl.Event.valueChanged)
        sw1.isOn = mapView.isShowTraffic
        ret.bounds = CGRect.init(x: 0, y: 0, width: sw1.frame.maxX, height: l1.frame.maxY)
        return ret
    }
    
    @objc func switchTraffic(sender: UISwitch) {
        mapView.isShowTraffic = sender.isOn
    }
    
    func searchRoutePlanningTruck() {
        let request = AMapTruckRouteSearchRequest()
        request.origin = AMapGeoPoint.location(withLatitude: CGFloat(startCoordinate.latitude), longitude: CGFloat(startCoordinate.longitude))
        request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destinationCoordinate.latitude), longitude: CGFloat(destinationCoordinate.longitude))
        search.aMapTruckRouteSearch(request)
    }
    
    func presentAnnomation(pois: Array<AMapPOI>) -> Void {
        if(pAnnotations!.count > 0){
            mapView.removeAnnotations(pAnnotations)
        }
        for poi: AMapPOI in pois {
            let annotation = MAPointAnnotation.init()
            annotation.coordinate = CLLocationCoordinate2DMake(CLLocationDegrees(poi.location!.latitude), CLLocationDegrees(poi.location!.longitude))
            annotation.title = poi.name
            annotation.subtitle = kPointGas
            mapView.addAnnotation(annotation)
            pAnnotations?.append(annotation)
        }
    }
    
    func initTrucklimitAreaOverlay() -> Void {
        let mData: Data? = try! Data.init(contentsOf: URL.init(fileURLWithPath: Bundle.main.path(forResource: "Trucklimit", ofType: "txt")!))
        
        if(mData != nil) {
            let jsonObj = try? JSONSerialization.jsonObject(with: mData!, options: JSONSerialization.ReadingOptions.allowFragments) as! [[String:Any]]
            var arr:Array<Any> = Array.init()
            for dict in jsonObj! {
                let area:String = dict["area"] as! String
                let line:String = dict["line"] as! String
                if (area.count != 0) {
                    let tmp = area.components(separatedBy: ";")
                    if tmp.count > 0{
                        let count = tmp.count
                        let coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: count)
                        for i in 0..<count {
                            let single = tmp[i]
                            let coord = single.components(separatedBy: ",")
                            if coord.count == 2{
                                let lat = coord.last! as NSString
                                let lon = coord.first! as NSString
                                coordinates[i].latitude = lat.doubleValue
                                coordinates[i].longitude = lon.doubleValue
                            }
                        }
                        let polygon = MAPolygon.init(coordinates: coordinates, count: UInt(count))
                        arr.append(polygon!)
                        coordinates.deallocate()
                    }
                }else if(line.count != 0){
                    let tmp0 = line.components(separatedBy: "|")
                    for res in tmp0{
                        let tmp = res.components(separatedBy: ";")
                        if tmp.count > 0{
                            let count = tmp.count
                            let coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: count)
                            for i in 0..<count{
                                let single = tmp[i]
                                let coord = single.components(separatedBy: ",")
                                if coord.count == 2{
                                    let lat = coord.last! as NSString
                                    let lon = coord.first! as NSString
                                    coordinates[i].latitude = lat.doubleValue
                                    coordinates[i].longitude = lon.doubleValue
                                }
                            }
                            let polyline = MAPolyline.init(coordinates: coordinates, count: UInt(count))
                            arr.append(polyline!)
                            coordinates.deallocate()
                        }
                    }
                }
            }
            limits = arr
        }
    }
    
    func searchGasPOI() {
        let request = AMapPOIAroundSearchRequest.init()
        request.city = "北京"
        request.keywords = "加油站"
        request.location = AMapGeoPoint.location(withLatitude: 39.909071, longitude: 116.39756)
        request.radius = 60*1000;
        request.types = "010100";
        request.offset = 100;
        self.search.aMapPOIAroundSearch(request)
    }
    
    func getViolationPOI() -> Void {
        let file = Bundle.main.path(forResource: "weizhang", ofType: "txt")
        guard let locationString = try? String(contentsOfFile: file!) else {
            return
        }
        let locations = locationString.components(separatedBy: "\n")
        var items:Array<MAPointAnnotation> = Array.init()
        for oneLocation in locations {
            let coordinate = oneLocation.components(separatedBy: ",")
            if coordinate.count == 2{
                let annotation = MAPointAnnotation.init()
                let lat = coordinate.last! as NSString
                let lon = coordinate.first! as NSString
                annotation.coordinate = CLLocationCoordinate2D.init(latitude: lat.doubleValue, longitude: lon.doubleValue)
                annotation.subtitle = kPointViolation
                items.append(annotation)
            }
        }
        mapView.addAnnotations(items)
    }
    
    //MARK: - MAMapViewDelegate
    func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
        if(overlay.isKind(of: MAPolyline.self)){
            let polylineRenderer = MAPolylineRenderer.init(overlay: overlay)
            polylineRenderer!.strokeColor = UIColor.red
            polylineRenderer!.lineWidth   = 2
            polylineRenderer!.lineDashType = MALineDashType.none
            return polylineRenderer
        }
        if(overlay.isKind(of: MAPolygon.self)){
            let polygonRenderer = MAPolygonRenderer.init(overlay: overlay)
            polygonRenderer!.lineWidth   = 1.0
            polygonRenderer!.strokeColor = UIColor.red.withAlphaComponent(0.3)
            polygonRenderer!.fillColor   = UIColor.red.withAlphaComponent(0.3)
            return polygonRenderer
        }
        return nil
    }
    
    func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
        
        if annotation.isKind(of: MAPointAnnotation.self) {
            let pointReuseIndetifier = "pointReuseIndetifier"
            var annotationView: MAAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: pointReuseIndetifier)
            
            if annotationView == nil {
                annotationView = MAAnnotationView(annotation: annotation, reuseIdentifier: pointReuseIndetifier)
                annotationView!.canShowCallout = true
                annotationView!.isDraggable = false
            }
            
            annotationView!.image = nil
            
            if annotation.title == kLocationName{
                return nil;
            }else if (annotation.subtitle  == kPointGas){
                annotationView!.image = UIImage(named: "gaspoint")
            }else if (annotation.subtitle  == kPointViolation){
                annotationView!.image = UIImage(named: "Violation")
            }
            
            return annotationView!
        }
        
        return nil
    }
    //pragma mark - MAMapViewDelegate
    func mapViewRequireLocationAuth(_ locationManager: CLLocationManager!) {
        locationManager.requestAlwaysAuthorization()
    }
    
    //MARK: - AMapSearchDelegate
    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        let nsErr:NSError? = error as NSError

    }
    
    /*poi查询回调函数*/
    func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
        if (response.pois.count > 0){
            presentAnnomation(pois: response.pois)
        }
    }
}

