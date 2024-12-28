#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>

#define TweakKey @"YouSpeed"

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

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Speed",
        SelectorKey: @"didPressYouSpeed:",
        AsTextKey: @YES
    });
    %init(Video);
    %init(Top);
    %init(Bottom);
}
