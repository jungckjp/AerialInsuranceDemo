//
//  ViewController.h
//  BPDelivery
//
//  Created by Jonathan Jungck on 7/12/17.
//  Copyright © 2017 Jonathan Jungck. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DJISDK/DJISDK.h>

@interface ViewController : UIViewController {
    DJIFlightController* flightController;
    DJIGimbal* gimbal;
}


@end

