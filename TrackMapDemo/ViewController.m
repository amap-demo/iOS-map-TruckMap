//
//  ViewController.m
//  TrackMapDemo
//
//  Created by zuola on 2019/5/10.
//  Copyright © 2019 zuola. All rights reserved.
//

#import "ViewController.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import "MATrackPointAnnotation.h"

#define kLocationName @"您的位置"
#define kPointGas @"gas"
#define kPointService @"service"
#define kPointViolation @"违章点"


@interface ViewController ()<MAMapViewDelegate, AMapSearchDelegate>
@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) AMapSearchAPI *search;
@property (nonatomic, strong) NSMutableArray *gasAnnotations;
@property (nonatomic, strong) NSMutableArray *serviceAnnotations;
@property (nonatomic, strong) NSMutableArray *violationAnnotations;

@property (nonatomic, strong) NSArray *limits;

@property (nonatomic, assign) BOOL isLocated;

@end
@implementation ViewController

#pragma mark - Life Cycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    _gasAnnotations = [NSMutableArray new];
    _serviceAnnotations = [NSMutableArray new];
    _violationAnnotations = [NSMutableArray new];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(returnAction)];
    
    self.mapView = [[MAMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    
    [self.view addSubview:self.mapView];
    self.mapView.showTraffic = YES;
    
    // 开启定位
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = MAUserTrackingModeFollow;
    self.mapView.userLocation.title = kLocationName;
    
    self.search = [[AMapSearchAPI alloc] init];
    self.search.delegate = self;
    
    UIView *switchsPannelView = [self makeSwitchsPannelView];
    switchsPannelView.center = CGPointMake( CGRectGetMidX(switchsPannelView.bounds) + 10,
                                           self.view.bounds.size.height -  CGRectGetMidY(switchsPannelView.bounds) - 80);
    
    switchsPannelView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:switchsPannelView];
    
    [self initTrucklimitAreaOverlay];
}

- (void)initTrucklimitAreaOverlay{
    NSString *fileFullPath = [[NSBundle mainBundle] pathForResource:@"Trucklimit" ofType:@"txt"];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:fileFullPath]) {
        return;
    }
    
    NSData *mData = [NSData dataWithContentsOfFile:fileFullPath];
    
    NSError *err = nil;
    NSArray *dataArr = [NSJSONSerialization JSONObjectWithData:mData options:0 error:&err];
    if(!dataArr) {
        NSLog(@"[AMap]: %@", err);
        return;
    }
    NSMutableArray *arr = [NSMutableArray array];
    
    for(NSDictionary *dict in dataArr) {
        if ([[dict objectForKey:@"area"] isKindOfClass:[NSString class]] && [[dict objectForKey:@"area"] length] > 0) {
            NSString *area = [dict objectForKey:@"area"];
            NSArray *tmp = [area componentsSeparatedByString:@";"];
            if (tmp.count > 0) {
                CLLocationCoordinate2D coordinates[tmp.count];
                for (NSInteger i = 0; i < tmp.count; i ++) {
                    NSString *single = tmp[i];
                    NSArray *coord = [single componentsSeparatedByString:@","];
                    if (coord.count == 2) {
                        coordinates[i].latitude = [[coord lastObject] doubleValue];
                        coordinates[i].longitude = [[coord firstObject] doubleValue];
                    }
                }
                MAPolygon *polygon = [MAPolygon polygonWithCoordinates:coordinates count:tmp.count];
                [arr addObject:polygon];
            }
        }else if ([dict objectForKey:@"line"] && [[dict objectForKey:@"line"] length] > 0){
            NSString *line = [dict objectForKey:@"line"];
            NSArray *tmp0 = [line componentsSeparatedByString:@"|"];
            for (NSString *res in tmp0) {
                NSArray *tmp = [res componentsSeparatedByString:@";"];
                if (tmp.count > 0) {
                    CLLocationCoordinate2D line2Points[tmp.count];
                    for (NSInteger i = 0; i < tmp.count; i ++) {
                        NSString *single = tmp[i];
                        NSArray *coord = [single componentsSeparatedByString:@","];
                        if (coord.count == 2) {
                            line2Points[i].latitude = [[coord lastObject] doubleValue];
                            line2Points[i].longitude = [[coord firstObject] doubleValue];
                        }
                    }
                    
                    MAPolyline *line2 = [MAPolyline polylineWithCoordinates:line2Points count:tmp.count];
                    [arr addObject:line2];
                }
            }
            
        }
    }
    self.limits = [NSArray arrayWithArray:arr];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.barStyle    = UIBarStyleBlack;
    self.navigationController.navigationBar.translucent = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.mapView addOverlays:self.limits];
}

- (void)searchGasPOI
{
    AMapPOIAroundSearchRequest *request = [[AMapPOIAroundSearchRequest alloc] init];
    request.keywords = @"加油站";
    request.location = [AMapGeoPoint locationWithLatitude:self.mapView.userLocation.coordinate.latitude longitude:self.mapView.userLocation.coordinate.longitude];
    request.radius = 60*1000;
    request.types = @"010100";
    request.offset = 100;
    [self.search AMapPOIAroundSearch:request];//POI 周边查询接口
}

- (void)searchServicePOI
{
    AMapPOIAroundSearchRequest *request = [[AMapPOIAroundSearchRequest alloc] init];
    request.location = [AMapGeoPoint locationWithLatitude:self.mapView.userLocation.coordinate.latitude longitude:self.mapView.userLocation.coordinate.longitude];
    request.radius = 60*1000;
    request.types = @"030000";
    request.offset = 100;
    [self.search AMapPOIAroundSearch:request];//POI 周边查询接口
}

- (void)getViolationPOI{
    NSString *file = [[NSBundle mainBundle] pathForResource:@"weizhang" ofType:@"txt"];
    NSString *locationString = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    NSArray *locations = [locationString componentsSeparatedByString:@"\n"];
    
    for (int i = 0; i < locations.count; ++i)
    {
        @autoreleasepool {
            NSArray *coordinate = [locations[i] componentsSeparatedByString:@","];
            if (coordinate.count == 2)
            {
                MATrackPointAnnotation *annotation = [[MATrackPointAnnotation alloc] init];
                annotation.coordinate = CLLocationCoordinate2DMake([coordinate[1] floatValue], [coordinate[0] floatValue]);
                annotation.title   = kPointViolation;
                annotation.type = 2;
                [_violationAnnotations addObject:annotation];
            }
        }
    }
    [self.mapView addAnnotations:_violationAnnotations];
}

- (UIView *)makeSwitchsPannelView
{
    UIView *ret = [[UIView alloc] initWithFrame:CGRectZero];
    ret.backgroundColor = [UIColor whiteColor];
    
    UISwitch *swt1 = [[UISwitch alloc] init];
    UISwitch *swt2 = [[UISwitch alloc] init];
    UISwitch *swt3 = [[UISwitch alloc] init];
    UISwitch *swt4 = [[UISwitch alloc] init];
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 70, CGRectGetHeight(swt1.bounds))];
    label1.text = @"路况";
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(label1.frame) + 5, 70, CGRectGetHeight(swt1.bounds))];
    label2.text = @"违章:";
    UILabel *label3 = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(label2.frame) + 5, 70, CGRectGetHeight(swt1.bounds))];
    label3.text = @"加气站:";
    UILabel *label4 = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(label3.frame) + 5, 70, CGRectGetHeight(swt1.bounds))];
    label4.text = @"维修站:";
    
    [ret addSubview:label1];
    [ret addSubview:swt1];
    [ret addSubview:label2];
    [ret addSubview:swt2];
    [ret addSubview:label3];
    [ret addSubview:swt3];
    [ret addSubview:label4];
    [ret addSubview:swt4];
    
    // layout
    CGRect tempFrame = swt1.frame;
    tempFrame.origin.x = CGRectGetMaxX(label1.frame) + 5;
    swt1.frame = tempFrame;
    
    tempFrame = swt2.frame;
    tempFrame.origin.x = CGRectGetMaxX(label2.frame) + 5;
    tempFrame.origin.y = CGRectGetMinY(label2.frame);
    swt2.frame = tempFrame;
    
    tempFrame = swt3.frame;
    tempFrame.origin.x = CGRectGetMaxX(label3.frame) + 5;
    tempFrame.origin.y = CGRectGetMinY(label3.frame);
    swt3.frame = tempFrame;
    
    tempFrame = swt4.frame;
    tempFrame.origin.x = CGRectGetMaxX(label4.frame) + 5;
    tempFrame.origin.y = CGRectGetMinY(label4.frame);
    swt4.frame = tempFrame;
    
    [swt1 addTarget:self action:@selector(enableDrag:) forControlEvents:UIControlEventValueChanged];
    [swt2 addTarget:self action:@selector(enableViolation:) forControlEvents:UIControlEventValueChanged];
    [swt3 addTarget:self action:@selector(enableGas:) forControlEvents:UIControlEventValueChanged];
    [swt4 addTarget:self action:@selector(enableService:) forControlEvents:UIControlEventValueChanged];

    [swt1 setOn:self.mapView.showTraffic];
    [swt2 setOn:YES];
    [swt3 setOn:YES];
    [swt4 setOn:YES];

    
    ret.bounds = CGRectMake(0, 0, CGRectGetMaxX(swt4.frame), CGRectGetMaxY(label4.frame));
    return ret;
}

- (void)enableDrag:(UISwitch *)sender
{
    self.mapView.showTraffic = sender.isOn;
}

- (void)enableViolation:(UISwitch *)sender
{
    if (sender.on) {
        [self.mapView addAnnotations:_violationAnnotations];
    }else{
        [self.mapView removeAnnotations:_violationAnnotations];
    }
}

- (void)enableGas:(UISwitch *)sender
{
    if (sender.on) {
        [self.mapView addAnnotations:_gasAnnotations];
    }else{
        [self.mapView removeAnnotations:_gasAnnotations];
    }
}

- (void)enableService:(UISwitch *)sender
{
    if (sender.on) {
        [self.mapView addAnnotations:_serviceAnnotations];
    }else{
        [self.mapView removeAnnotations:_serviceAnnotations];
    }
}

#pragma mark - action handle
- (void)returnAction
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)presentGasAnnomation:(NSArray *)pois{
    if (_gasAnnotations.count) {
        [self.mapView removeAnnotations:_gasAnnotations];
        [_gasAnnotations removeAllObjects];
    }
    for (AMapPOI *poi in pois) {
        MATrackPointAnnotation *annotation = [[MATrackPointAnnotation alloc] init];
        annotation.coordinate = CLLocationCoordinate2DMake(poi.location.latitude, poi.location.longitude);
        annotation.title      = poi.name;
        annotation.subtitle   = poi.address;
        annotation.type = 0;
        [self.mapView addAnnotation:annotation];
        [_gasAnnotations addObject:annotation];
    }
}

- (void)presentServiceAnnomation:(NSArray *)pois{
    if (_serviceAnnotations.count) {
        [self.mapView removeAnnotations:_serviceAnnotations];
        [_serviceAnnotations removeAllObjects];
    }
    for (AMapPOI *poi in pois) {
        MATrackPointAnnotation *annotation = [[MATrackPointAnnotation alloc] init];
        annotation.coordinate = CLLocationCoordinate2DMake(poi.location.latitude, poi.location.longitude);
        annotation.title      = poi.name;
        annotation.subtitle   = poi.address;
        annotation.type = 1;
        [self.mapView addAnnotation:annotation];
        [_serviceAnnotations addObject:annotation];
    }
}


#pragma mark - MAMapViewDelegate

- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay
{
    if ([overlay isKindOfClass:[MAPolyline class]])
    {
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        polylineRenderer.strokeColor = [UIColor redColor];
        polylineRenderer.lineWidth   = 2.f;
        polylineRenderer.lineDashType = kMALineDashTypeNone;
        return polylineRenderer;
    }
    if ([overlay isKindOfClass:[MAPolygon class]]) {
        MAPolygonRenderer *polygonRenderer = [[MAPolygonRenderer alloc] initWithPolygon:overlay];
        polygonRenderer.lineWidth   = 1.f;
        polygonRenderer.strokeColor = [[UIColor redColor] colorWithAlphaComponent:0.3];
        polygonRenderer.fillColor   = [[UIColor redColor] colorWithAlphaComponent:0.3];
        return polygonRenderer;
    }
    
    return nil;
}

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MATrackPointAnnotation class]])
    {
        MATrackPointAnnotation *kannotation = (MATrackPointAnnotation *)annotation;
        static NSString *routePlanningCellIdentifier = @"RoutePlanningCellIdentifier";
        
        MAAnnotationView *poiAnnotationView = (MAAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:routePlanningCellIdentifier];
        if (poiAnnotationView == nil)
        {
            poiAnnotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation
                                                             reuseIdentifier:routePlanningCellIdentifier];
        }
        poiAnnotationView.canShowCallout = YES;
        poiAnnotationView.image = nil;
        
        
        if([[annotation title] isEqualToString:kLocationName]){
            return nil;
        }else if (kannotation.type == 0){
            poiAnnotationView.image = [UIImage imageNamed:@"gaspoint"];
        }else if (kannotation.type == 1){
            poiAnnotationView.image = [UIImage imageNamed:@"servicepoint"];
        }else if (kannotation.type == 2){
            poiAnnotationView.image = [UIImage imageNamed:@"Violation"];
        }
        return poiAnnotationView;
    }
    return nil;
}

#pragma mark - AMapSearchDelegate
- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error
{

}

/*POI查询回调函数*/
- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response
{
    if (response.pois.count) {
        if ([request.types isEqualToString:@"010100"]) {
            [self presentGasAnnomation:response.pois];
        }else if ([request.types isEqualToString:@"030000"]){
            [self presentServiceAnnomation:response.pois];
        }
    }
}

#pragma mark - MAMapViewDelegate
- (void)mapViewRequireLocationAuth:(CLLocationManager *)locationManager
{
    [locationManager requestAlwaysAuthorization];
}

- (void)mapView:(MAMapView *)mapView didChangeUserTrackingMode:(MAUserTrackingMode)mode animated:(BOOL)animated
{
    
}

- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
{
    if(!updatingLocation)
    return ;
    
    if (userLocation.location.horizontalAccuracy < 0)
    {
        return ;
    }
    // only the first locate used.
    if (!self.isLocated)
    {
        self.isLocated = YES;
        self.mapView.userTrackingMode = MAUserTrackingModeFollow;
        [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude)];
        [self searchGasPOI];
        [self searchServicePOI];
        [self getViolationPOI];
    }
}


@end
