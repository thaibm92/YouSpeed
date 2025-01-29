#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/MLHAMPlayerItemSegment.h>
#import <YouTubeHeader/MLHAMQueuePlayer.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTVarispeedSwitchController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>

#define TweakKey @"YouSpeed"
#define MoreSpeedKey @"YSMS"

@interface YTMainAppControlsOverlayView (YouSpeed)
- (void)didPressYouSpeed:(id)arg;
- (void)updateYouSpeedButton:(id)arg;
@end

@interface YTInlinePlayerBarContainerView (YouSpeed)
- (void)didPressYouSpeed:(id)arg;
- (void)updateYouSpeedButton:(id)arg;
@end

NSString *YouSpeedUpdateNotification = @"YouSpeedUpdateNotification";
NSString *currentSpeedLabel = @"1x";

static BOOL MoreSpeed() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MoreSpeedKey];
}

%group Video

%hook YTPlayerOverlayManager

- (void)varispeedSwitchController:(id)arg1 didSelectRate:(float)rate {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 2;
    NSString *rateString = [formatter stringFromNumber:[NSNumber numberWithFloat:rate]];
    currentSpeedLabel = [NSString stringWithFormat:@"%@x", rateString];
    [[NSNotificationCenter defaultCenter] postNotificationName:YouSpeedUpdateNotification object:nil];
    %orig;
}

%end

%end

%group Top

%hook YTMainAppControlsOverlayView

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    [self updateYouSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouSpeedButton:) name:YouSpeedUpdateNotification object:nil];
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    [self updateYouSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouSpeedButton:) name:YouSpeedUpdateNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouSpeedUpdateNotification object:nil];
    %orig;
}

%new(v@:@)
- (void)updateYouSpeedButton:(id)arg {
    [self.overlayButtons[TweakKey] setTitle:currentSpeedLabel forState:0];
}

%new(v@:@)
- (void)didPressYouSpeed:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *c = [self valueForKey:@"_eventsDelegate"];
    [c didPressVarispeed:arg];
    [self updateYouSpeedButton:nil];
}

%end

%end

%group Bottom

%hook YTInlinePlayerBarContainerView

- (id)init {
    self = %orig;
    [self updateYouSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouSpeedButton:) name:YouSpeedUpdateNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouSpeedUpdateNotification object:nil];
    %orig;
}

%new(v@:@)
- (void)updateYouSpeedButton:(id)arg {
    [self.overlayButtons[TweakKey] setTitle:currentSpeedLabel forState:0];
}

%new(v@:@)
- (void)didPressYouSpeed:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *c = [self.delegate valueForKey:@"_delegate"];
    [c didPressVarispeed:arg];
    [self updateYouSpeedButton:nil];
}

%end

%end

%group Speed

%hook YTVarispeedSwitchController

- (id)init {
    self = %orig;
    #define itemCount 16
    float speeds[] = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.5, 4.0, 4.5, 5.0};
    id options[itemCount];
    Class YTVarispeedSwitchControllerOptionClass = %c(YTVarispeedSwitchControllerOption);
    for (int i = 0; i < itemCount; ++i) {
        NSString *title = [NSString stringWithFormat:@"%.2fx", speeds[i]];
        options[i] = [[YTVarispeedSwitchControllerOptionClass alloc] initWithTitle:title rate:speeds[i]];
    }
    [self setValue:[NSArray arrayWithObjects:options count:itemCount] forKey:@"_options"];
    return self;
}

%end

%hook MLHAMQueuePlayer

- (void)setRate:(float)newRate {
    float rate = [[self valueForKey:@"_rate"] floatValue];
    if (rate == newRate) return;
    MLHAMPlayerItemSegment *segment = [self valueForKey:@"_currentSegment"];
    MLInnerTubePlayerConfig *config = [segment playerItem].config;
    if ([config varispeedAllowed]) {
        [self setValue:@(newRate) forKey:@"_rate"];
        [self internalSetRate];
    }
}

%end

%end

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Speed",
        SelectorKey: @"didPressYouSpeed:",
        AsTextKey: @YES,
        ExtraBooleanKeys: @[MoreSpeedKey]
    });
    %init(Video);
    %init(Top);
    %init(Bottom);
    if (MoreSpeed()) {
        %init(Speed);
    }
}
