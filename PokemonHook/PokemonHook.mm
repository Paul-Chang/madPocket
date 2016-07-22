//
//  PokemonHook.mm
//  PokemonHook
//
//  Created by YoungShook on 16/7/11.
//  Copyright (c) 2016年 YoungShook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import "UIView+draggable.h"
#include <pthread.h>
#include <time.h>


inline void replaceImplementation(Class newClass, Class hookedClass, SEL sel, IMP& oldImp){
    Method old = class_getInstanceMethod(hookedClass, sel);
    IMP newImp = class_getMethodImplementation(newClass, sel);
    oldImp = method_setImplementation(old, newImp);
}

#pragma mark  NIAIosLocationManagerHook @ Hook

@interface NIAIosLocationManagerHook : NSObject
+ (void)locationUpdateHook;
- (void)start;
- (void)startUpdating;
@end

static NIAIosLocationManagerHook *hookLocationManager;

@implementation NIAIosLocationManagerHook
static IMP NIAIosLocationManager_start = NULL;
static IMP NIAIosLocationManager_startUpdating = NULL;

+ (void)locationUpdateHook {
    Class hookedClass = objc_getClass("NIAIosLocationManager");
    SEL startSel = @selector(start);
    replaceImplementation([self class], hookedClass, startSel, NIAIosLocationManager_start);
    SEL startUpdatingSel = @selector(startUpdating);
    replaceImplementation([self class], hookedClass, startUpdatingSel, NIAIosLocationManager_startUpdating);
}

- (void)start {
    NIAIosLocationManager_start(self, @selector(start));
    hookLocationManager = self;
}

- (void)startUpdating {
    NIAIosLocationManager_startUpdating(self, @selector(startUpdating));
    hookLocationManager = self;
}

@end


typedef NS_ENUM (NSUInteger, RockerControlDirection) {
    RockerControlDirectionUp,
    RockerControlDirectionDown,
    RockerControlDirectionLeft,
    RockerControlDirectionRight,
};
typedef void (^RockerValueCallback)(RockerControlDirection direction);

#pragma mark  RockerControlView @ interface
@interface RockerControlView : UIView
@property (nonatomic, copy) RockerValueCallback controlCallback;
@end

/* ==================================================*/

static RockerControlView *gameRockerView;
static UIButton *googleMapsButton;

#pragma mark  CLLocation @ Swizzle
//  Ref: https://github.com/rpplusplus/PokemonHook
@interface CLLocation (Swizzle)

@end

@implementation CLLocation (Swizzle)

id thisClass;

/* current x,y for GPS */
static float x = 37.7883923;
static float y = -122.4076413;

/* auto walk to x,y robot */
static float destX = 37.7883923;
static float destY = -122.4076413;

/* auto hatching egg */
static float offsetX = 0;
static float offsetY = 0;
static bool LRSwitch = false;
static bool UDSwitch = false;



static int botMode = 0;//0=normal, 1=hatch egg, 2=taxi

static float version = 167141100;


void *start(void *data){
    [thisClass autoHitchEggThreadFunc];
    return NULL;
}

+ (void) autoHitchEggThreadFunc {
    while (1)
    {
        while (botMode == 1)
        {
            float maxOffsetSum = 0.002000;
            float tmpX = [thisClass randSetpDistance:0.000200 to:0.000050];
            float tmpY = [thisClass randSetpDistance:0.000200 to:0.000050];
            
            if (LRSwitch) {
                offsetX -= tmpX;
                x -= tmpX;
                if (offsetX < -maxOffsetSum) LRSwitch = false;
            }
            else {
                offsetX += tmpX;
                x += tmpX;
                if (offsetX > maxOffsetSum) LRSwitch = true;
            }
            
            if (UDSwitch){
                offsetY -= tmpY;
                y -= tmpY;
                if (offsetY < -maxOffsetSum) UDSwitch = false;
            }
            else {
                offsetY += tmpY;
                y += tmpY;
                if (offsetY > maxOffsetSum) UDSwitch = true;
            }
            [self refreshMyXYToGPS];
            [NSThread sleepForTimeInterval:1.5];
        }
        
        while (botMode == 2)
        {
            float tmpX = [thisClass randSetpDistance:0.000400 to:0.000150];
            float tmpY = [thisClass randSetpDistance:0.000400 to:0.000150];
            
            if (destX > x)
                x += tmpX;
            else
                x -= tmpX;
            if (destY > y)
                y += tmpY;
            else
                y -= tmpY;
            [self refreshMyXYToGPS];
            
            [NSThread sleepForTimeInterval:1.0];
        }
        
        
        [NSThread sleepForTimeInterval: 1];
    }
}


+ (void)load {
    thisClass = self;
    
    Method m1 = class_getInstanceMethod(self, @selector(coordinate));
    Method m2 = class_getInstanceMethod(self, @selector(coordinate_));
    method_exchangeImplementations(m1, m2);
    
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_version"]) {
        float _verison = [[[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_version"] floatValue];
        if (_verison < version) {
            [[NSUserDefaults standardUserDefaults] setValue:@(x) forKey:@"_fake_X"];
            [[NSUserDefaults standardUserDefaults] setValue:@(y) forKey:@"_fake_Y"];
            [[NSUserDefaults standardUserDefaults] setValue:@(version) forKey:@"_fake_version"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_X"]) {
        x = [[[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_X"] floatValue];
    }
    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_Y"]) {
        y = [[[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_Y"] floatValue];
    }
    
    [NIAIosLocationManagerHook locationUpdateHook];
    
    pthread_t thread;
    pthread_create(&thread, NULL, start, NULL);
    
    [self addRockerView];
    

}




- (CLLocationCoordinate2D)coordinate_ {

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_X"]) {
        x = [[[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_X"] floatValue];
    }
    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_Y"]) {
        y = [[[NSUserDefaults standardUserDefaults] valueForKey:@"_fake_Y"] floatValue];
    }
    
    return CLLocationCoordinate2DMake(x, y);
}

+ (void) refreshMyXYToGPS {
    [[NSUserDefaults standardUserDefaults] setValue:@(x) forKey:@"_fake_X"];
    [[NSUserDefaults standardUserDefaults] setValue:@(y) forKey:@"_fake_Y"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (hookLocationManager) {
        [hookLocationManager start];
        [hookLocationManager startUpdating];
        [googleMapsButton setAttributedTitle:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"lat:%@  lon:%@ open GoogleMaps", @(x), @(y)] attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]}] forState:UIControlStateNormal];
    }
}

+ (void)addRockerView {

    if (gameRockerView) {
        return;
    }

    gameRockerView = [RockerControlView new];

    gameRockerView.controlCallback = ^(RockerControlDirection direction){
        switch (direction) {
        case RockerControlDirectionUp:
            x += [self randSetpDistance:0.000400 to:0.000150];
            y += [self randSetpDistance:0.000050 to:-0.000050];
            break;
        case RockerControlDirectionDown:
            x -= [self randSetpDistance:0.000400 to:0.000150];
            y += [self randSetpDistance:0.000050 to:-0.000050];
            break;
        case RockerControlDirectionLeft:
            y -= [self randSetpDistance:0.000400 to:0.000150];
            x += [self randSetpDistance:0.000050 to:-0.000050];
            break;
        case RockerControlDirectionRight:
            y += [self randSetpDistance:0.000400 to:0.000150];
            x += [self randSetpDistance:0.000050 to:-0.000050];
            break;
        default:
            break;
        }
        [self refreshMyXYToGPS];

    };

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [gameRockerView enableDragging];
        gameRockerView.cagingArea = UIScreen.mainScreen.bounds;
        
        /* init googlemap button */
        googleMapsButton = [[UIButton alloc] initWithFrame:CGRectMake(10, UIScreen.mainScreen.bounds.size.height - 20, UIScreen.mainScreen.bounds.size.width, 20)];
        [googleMapsButton enableDragging];
        [googleMapsButton addTarget:gameRockerView action:@selector(openGoogleMap) forControlEvents:UIControlEventTouchUpInside];
        googleMapsButton.cagingArea = UIScreen.mainScreen.bounds;
        
        [[[UIApplication sharedApplication] keyWindow] addSubview:gameRockerView];
        [[[UIApplication sharedApplication] keyWindow] addSubview:googleMapsButton];
        
        [[NSNotificationCenter defaultCenter] addObserver:gameRockerView selector:@selector(dismissRocker) name:@"UIWindowDidShake" object:nil];
    });
}

+ (float)randSetpDistance:(float)max to:(float)min {
    return (((float)rand() / RAND_MAX) * (max - min)) + min;
}

@end


#pragma mark  RockerControlView @ implementation

@implementation RockerControlView

- (instancetype)init {
    if (self = [super init]) {
        [self initUI];
    }
    return self;
}

/* declare direction buttons as global variables */
UIButton *up ;
UIButton *down ;
UIButton *left ;
UIButton *right ;
UIButton *hitchEgg;
UIButton *Taxi ;

- (void)initUI {

    self.frame = CGRectMake(60, 20, 150, 150);
    self.backgroundColor = [UIColor clearColor];

    up = [[UIButton alloc] initWithFrame:CGRectMake(50, 0, 50, 50)];
    up.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    up.layer.borderColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0.425].CGColor;
    up.layer.borderWidth = 0;
    [up setTitle:@"🔼" forState:UIControlStateNormal];
    up.titleLabel.font = [UIFont systemFontOfSize:50];
    up.tag = 101;
    [up addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchDown];
    [self addSubview:up];

    
    hitchEgg = [[UIButton alloc] initWithFrame:CGRectMake(100, 0, 50, 50)];
    hitchEgg.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    hitchEgg.layer.borderColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0.425].CGColor;
    hitchEgg.layer.borderWidth = 0;
    [hitchEgg setTitle:@"🐣" forState:UIControlStateNormal];
    hitchEgg.titleLabel.font = [UIFont systemFontOfSize:45];
    hitchEgg.tag = 1;
    [hitchEgg addTarget:self action:@selector(hitchEggFunc:) forControlEvents:UIControlEventTouchDown];
    [self addSubview:hitchEgg];
    

    UIButton *setting = [[UIButton alloc] initWithFrame:CGRectMake(50, 50, 50, 50)];
    setting.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    setting.layer.borderColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0.425].CGColor;
    setting.layer.borderWidth = 0;
    [setting setTitle:@"⏺" forState:UIControlStateNormal];
    setting.titleLabel.font = [UIFont systemFontOfSize:50];
    setting.tag = 201;
    [setting addTarget:self action:@selector(dismissRocker) forControlEvents:UIControlEventTouchDown];
    [self addSubview:setting];

    down = [[UIButton alloc] initWithFrame:CGRectMake(50, 100, 50, 50)];
    [down setTitle:@"🔽" forState:UIControlStateNormal];
    down.backgroundColor =  [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    down.layer.borderColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0.425].CGColor;
    down.layer.borderWidth = 0;
    down.titleLabel.font = [UIFont systemFontOfSize:50];
    down.tag = 102;
    [down addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchDown];
    [self addSubview:down];


    left = [[UIButton alloc] initWithFrame:CGRectMake(0, 50, 50, 50)];
    [left setTitle:@"◀️" forState:UIControlStateNormal];
    left.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    left.layer.borderColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0.425].CGColor;
    left.layer.borderWidth = 0;
    left.titleLabel.font = [UIFont systemFontOfSize:50];
    left.tag = 103;
    [left addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchDown];
    [self addSubview:left];


    right = [[UIButton alloc] initWithFrame:CGRectMake(100, 50, 50, 50)];
    [right setTitle:@"▶️" forState:UIControlStateNormal];
    right.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    right.layer.borderColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0.425].CGColor;
    right.layer.borderWidth = 0;
    right.titleLabel.font = [UIFont systemFontOfSize:50];
    right.tag = 104;
    [right addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchDown];
    [self addSubview:right];
    
    Taxi = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    Taxi.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    Taxi.layer.borderColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0.425].CGColor;
    Taxi.layer.borderWidth = 0;
    [Taxi setTitle:@"🚀" forState:UIControlStateNormal];
    Taxi.titleLabel.font = [UIFont systemFontOfSize:45];
    Taxi.tag = 2;
    [Taxi addTarget:self action:@selector(hitchEggFunc:) forControlEvents:UIControlEventTouchDown];
    [self addSubview:Taxi];
}

- (void)dismissRocker {
    /* Change the setting button function to switch direction buttons hidden value */
    hitchEgg.hidden = !hitchEgg.hidden;
    up.hidden = !up.hidden;
    down.hidden = !down.hidden;
    left.hidden = !left.hidden;
    right.hidden = !right.hidden;
    Taxi.hidden = !Taxi.hidden;
}

- (void)openGoogleMap {
    if (([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"comgooglemaps://"]] ||
         [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"comgooglemaps-x-callback://"]])) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"comgooglemaps-x-callback://?center=%@,%@&q=%@,%@&zoom=17&x-success=b335b2fc-69dc-472c-9e88-e6c97f84091c-3://?resume=true&x-source=PokemonGO", @(x), @(y), @(x), @(y)]]];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        UITextField *lat = [alertView textFieldAtIndex:0];
        UITextField *lon = [alertView textFieldAtIndex:1];
        destX = [lat.text doubleValue];
        destY = [lon.text doubleValue];
        botMode = 2;
        Taxi.backgroundColor = [UIColor colorWithRed:256 green:0 blue:0 alpha:0.5];
    }else{
        botMode = 0;
        Taxi.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
    }
}

- (void)hitchEggFunc:(UIButton *)sender {
    if (sender.tag == 1)
        botMode = ( botMode == 1 ? 0: 1 );
    if (sender.tag == 2) {
        
        if (botMode == 2) {
            botMode = 0;
            Taxi.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];
        }else{
            UIAlertView * alert =[[UIAlertView alloc ] initWithTitle:@"TAXI: Destination Setting" message:@"Enter lat & lon" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles: nil];
            alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
            [alert addButtonWithTitle:@"GO!"];
            UITextField *lat = [alert textFieldAtIndex:0];
            UITextField *lon = [alert textFieldAtIndex:1];
            lon.secureTextEntry = false;
            [lat setText:@"37.7883923"];
            [lon setText:@"-122.4076413"];
            [alert show];
        }
        
    }
    
    if (botMode == 1)
        hitchEgg.backgroundColor = [UIColor colorWithRed:256 green:0 blue:0 alpha:0.5];
    else
        hitchEgg.backgroundColor = [UIColor colorWithRed:256 green:256 blue:256 alpha:0];

    
    
    /*
    if (botMode != 0) {
        [up setEnabled:false];
        [down setEnabled:false];
        [left setEnabled:false];
        [right setEnabled:false];
    }
    else{
        [up setEnabled:true];
        [down setEnabled:true];
        [left setEnabled:true];
        [right setEnabled:true];
    }*/
}

- (void)buttonAction:(UIButton *)sender {
    [sender.layer addAnimation:[self scaleAnimation] forKey:@"scale"];

    if (self.controlCallback) {
        RockerControlDirection direction;
        switch (sender.tag) {
        case 101:
            direction = RockerControlDirectionUp;
            printf("Up");
            break;
        case 102:
            direction = RockerControlDirectionDown;
            printf("Down");
            break;
        case 103:
            direction = RockerControlDirectionLeft;
            printf("Left");
            break;
        case 104:
            direction = RockerControlDirectionRight;
            printf("Right");
            break;

        default:
            break;
        }

        self.controlCallback(direction);
    }
}

- (CAAnimation *)scaleAnimation {
    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.toValue = @3;
    return scale;
}

@end

@interface UIWindow (Shake_Swizzle)

@end

@implementation UIWindow (Shake_Swizzle)
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UIWindowDidShake" object:nil];
    }
}

@end
