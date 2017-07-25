//
//  DJIFlightHelpers.m
//  BPDelivery
//
//  Created by Jonathan Jungck on 7/13/17.
//  Copyright © 2017 Jonathan Jungck. All rights reserved.
//

#import "DJIFlightHelpers.h"
#import <DJISDK/DJISDK.h>

@implementation DJIFlightHelpers

+(DJIBaseProduct*) fetchProduct {
    return [DJISDKManager product];
}

+(DJIAircraft*) fetchAircraft {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]);
    }
    
    return nil;
}

+(DJIHandheld *)fetchHandheld {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]);
    }
    
    return nil;
}

+(DJICamera*) fetchCamera {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).camera;
    }
    else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).camera;
    }
    return nil;
}

+(DJIGimbal*) fetchGimbal {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).gimbal;
    }
    else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).gimbal;
    }
    
    return nil;
}

+(DJIFlightController*) fetchFlightController {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).flightController;
    }
    
    return nil;
}

+(DJIRemoteController*) fetchRemoteController {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).remoteController;
    }
    
    return nil;
}

+(DJIBattery*) fetchBattery {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).battery;
    }
    else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).battery;
    }
    
    return nil;
}
+(DJIAirLink*) fetchAirLink {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).airLink;
    }
    else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).airLink;
    }
    
    return nil;
}

+(DJIHandheldController*) fetchHandheldController
{
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).handheldController;
    }
    
    return nil;
}

+(DJIMobileRemoteController *)fetchMobileRemoteController {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).mobileRemoteController;
    }
    
    return nil;
}

+(DJIKeyedValue *)startListeningAndGetValueForChangesOnKey:(DJIKey *)key
                                              withListener:(id)listener
                                            andUpdateBlock:(DJIKeyedListenerUpdateBlock)updateBlock {
    [[DJISDKManager keyManager] startListeningForChangesOnKey:key withListener:listener andUpdateBlock:updateBlock];
    return [[DJISDKManager keyManager] getValueForKey:key];
}


@end
