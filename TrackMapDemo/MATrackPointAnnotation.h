//
//  MATrackPointAnnotation.h
//  TrackMapDemo
//
//  Created by zuola on 2019/5/13.
//  Copyright © 2019 zuola. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MATrackPointAnnotation : MAPointAnnotation
@property (nonatomic, assign) NSInteger type;//0-gas,1-service,2-Violation,3-cesu

@end

NS_ASSUME_NONNULL_END
