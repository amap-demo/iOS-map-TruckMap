本工程为基于高德地图iOS SDK进行封装，多弹出框的效果。
## 前述 ##
- [高德官网申请Key](http://lbs.amap.com/dev/#/).
- 阅读[开发指南](http://lbs.amap.com/api/ios-sdk/summary/).
- 工程基于iOS 3D地图SDK实现

## 功能描述 ##
基于3D地图SDK，实现货车限行地图demo。

## 核心类/接口 ##
| 类    | 接口  | 说明   | 版本  |
| -----|:-----:|:-----:|:-----:|
| AMapSearchAPI	| - (void)AMapPOIAroundSearch:(AMapPOIAroundSearchRequest *)request;; | POI 周边查询接口 | v4.0.0 |
| MAAnnotationView	| --- | annotation显示 | --- |

## 核心难点 ##

`Objective-C`

```

/* POI 周边查询接口 */
- (void)searchGasPOI
{
    AMapPOIAroundSearchRequest *request = [[AMapPOIAroundSearchRequest alloc] init];
    request.city = @"北京";
    request.keywords = @"加油站";
    request.location = [AMapGeoPoint locationWithLatitude:39.909071 longitude:116.39756];
    request.radius = 60*1000;
    request.types = @"010100";
    request.offset = 100;
    [self.search AMapPOIAroundSearch:request];
}
/*限行区域polygon和polyline*/
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
```

`Swift`

```
/* POI 周边查询接口 */
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

```
