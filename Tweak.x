#import <YTVideoOverlay/Header.h>
#import <YTVideoOverlay/Init.x>
#import <YouTubeHeader/ASNodeController.h>
#import <YouTubeHeader/ELMTouchCommandPropertiesHandler.h>
// #import <YouTubeHeader/MLAVPlayer.h>
#import <YouTubeHeader/MLHAMPlayerItemSegment.h>
#import <YouTubeHeader/MLHAMQueuePlayer.h>
#import <YouTubeHeader/YTActionSheetAction.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTVarispeedSwitchController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>
#import <YouTubeHeader/YTWatchViewController.h>
#import <YouTubeHeader/MDCSlider.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTColor.h>

#define TweakKey @"YouSpeed"
#define MoreSpeedKey @"YSMS"
#define FixNativeSpeedKey @"YSFNS"
#define SpeedSliderKey @"YSSS"
#define MIN_SPEED 0.25
#define MAX_SPEED 5.0

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
float currentPlaybackRate = 1.0;

static NSBundle *YouSpeedBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouSpeed" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:tweakBundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/YouSpeed.bundle")];
    });
    return bundle;
}

static BOOL MoreSpeed() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MoreSpeedKey];
}

static BOOL FixNativeSpeed() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:FixNativeSpeedKey];
}

static BOOL SpeedSlider() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SpeedSliderKey];
}

static NSString *speedLabel(float rate) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 2;
    NSString *rateString = [formatter stringFromNumber:[NSNumber numberWithFloat:rate]];
    return [NSString stringWithFormat:@"%@x", rateString];
}

static void didSelectRate(float rate) {
    currentPlaybackRate = rate;
    currentSpeedLabel = speedLabel(rate);
    [[NSNotificationCenter defaultCenter] postNotificationName:YouSpeedUpdateNotification object:nil];
}

%group Video

%hook YTPlayerOverlayManager

- (void)varispeedSwitchController:(id)arg1 didSelectRate:(float)rate {
    didSelectRate(rate);
    %orig;
}

%end

%hook YTPlayerViewController

- (void)varispeedSwitchController:(id)arg1 didSelectRate:(float)rate {
    didSelectRate(rate);
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
    [self.overlayButtons[TweakKey] setTitle:currentSpeedLabel forState:UIControlStateNormal];
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
    [self.overlayButtons[TweakKey] setTitle:currentSpeedLabel forState:UIControlStateNormal];
}

%new(v@:@)
- (void)didPressYouSpeed:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *c = [self.delegate valueForKey:@"_delegate"];
    [c didPressVarispeed:arg];
    [self updateYouSpeedButton:nil];
}

%end

%end

%group OverrideNative

static BOOL isQualitySelectionNode(ASDisplayNode *node) {
    NSArray *yogaChildren = node.yogaChildren;
    if (yogaChildren.count == 2 && [[yogaChildren lastObject] isKindOfClass:%c(ASTextNode)]) {
        ASDisplayNode *parent = node.yogaParent, *previousParent;
        do {
            previousParent = parent;
            parent = parent.yogaParent;
        } while (parent && parent.yogaChildren.count != 5);
        return parent && parent.yogaChildren.count == 5 && parent.yogaChildren[2] == previousParent;
    }
    return NO;
}

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
    ASDisplayNode *node = [(ASNodeController *)[self valueForKey:@"_controller"] node];
    if (isQualitySelectionNode(node)) {
        UIViewController *vc = [node closestViewController];
        if ([vc isKindOfClass:(%c(YTAppCollectionViewController))]) {
            do {
                vc = vc.parentViewController;
            } while (vc && ![vc isKindOfClass:%c(YTModuleEngagementPanelViewController)]);
            if ([vc isKindOfClass:%c(YTModuleEngagementPanelViewController)]) {
                do {
                    vc = vc.parentViewController;
                } while (vc && ![vc isKindOfClass:%c(YTWatchViewController)]);
                if ([vc isKindOfClass:%c(YTWatchViewController)]) {
                    YTPlayerViewController *pvc = ((YTWatchViewController *)vc).playerViewController;
                    id c = [pvc activeVideoPlayerOverlay];
                    if ([c isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
                        [c dismissViewControllerAnimated:YES completion:^{
                            [c didPressVarispeed:nil];
                        }];
                        return;
                    }
                }
            }
        }
    }
    %orig;
}

%end

%hook YTMenuController

- (NSMutableArray <YTActionSheetAction *> *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)fromView entry:(id)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    NSUInteger index = [renderers indexOfObjectPassingTest:^BOOL(YTIMenuItemSupportedRenderers *renderer, NSUInteger idx, BOOL *stop) {
        YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *extension = (YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *)[renderer.elementRenderer.compatibilityOptions messageForFieldNumber:396644439];
        BOOL isVideoSpeed = [extension.menuItemIdentifier isEqualToString:@"menu_item_playback_speed"];
        if (isVideoSpeed) *stop = YES;
        return isVideoSpeed;
    }];
    NSMutableArray <YTActionSheetAction *> *actions = %orig;
    if (index != NSNotFound) {
        YTActionSheetAction *action = actions[index];
        action.handler = ^{
            [firstResponder didPressVarispeed:fromView];
        };
        UIView *elementView = [action.button valueForKey:@"_elementView"];
        elementView.userInteractionEnabled = NO;
    }
    return actions;
}

%end

%end

%group Speed

%hook YTVarispeedSwitchController

- (id)init {
    self = %orig;
    #define itemCount 16
    float speeds[] = {MIN_SPEED, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.5, 4.0, 4.5, MAX_SPEED};
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
    if (![config varispeedAllowed]) return;
    [self setValue:@(newRate) forKey:@"_rate"];
    [self internalSetRate];
}

%end

// %hook MLAVPlayer

// - (void)setRate:(float)newRate {
//     MLInnerTubePlayerConfig *config = [self valueForKey:@"_config"];
//     if (![config varispeedAllowed]) return;
//     float rate = [[self valueForKey:@"_rate"] floatValue];
//     if (rate == newRate) return;
//     [self setValue:@(newRate) forKey:@"_rate"];
//     self.assetPlayer.rate = newRate;
//     MLPlayerStickySettings *stickySettings = [self valueForKey:@"_stickySettings"];
//     stickySettings.rate = newRate;
//     MLPlayerEventCenter *eventCenter = [self valueForKey:@"_playerEventCenter"];
//     [eventCenter broadcastRateChange:newRate];
//     [self.delegate playerRateDidChange:newRate];
// }

// %end

%end

%group Slider

%hook YTMainAppVideoPlayerOverlayViewController

- (void)didPressVarispeed:(id)arg1 {
    if (!SpeedSlider()) {
        %orig;
        return;
    }
    NSBundle *tweakBundle = YouSpeedBundle();
    NSString *label = LOC(@"PLAYBACK_SPEED");
    NSString *chooseFromOriginalLabel = LOC(@"CHOOSE_FROM_ORIGINAL");
    CGRect rect = CGRectMake(0, 0, 300, 30);
    UIColor *color = [%c(YTColor) youTubeRed];
    MDCSlider *slider = [%c(MDCSlider) new];
    slider.statefulAPIEnabled = YES;
    slider.minimumValue = MIN_SPEED;
    slider.maximumValue = MAX_SPEED;
    slider.value = currentPlaybackRate;
    slider.continuous = NO;
    slider.accessibilityLabel = label;
    [slider setThumbColor:color forState:UIControlStateNormal];
    [slider setTrackFillColor:color forState:UIControlStateNormal];
    [slider setTrackBackgroundColor:[%c(YTColor) grey3Alpha70] forState:UIControlStateNormal];

    UILabel *minLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 40, 50, 20)];
    minLabel.text = speedLabel(MIN_SPEED);
    minLabel.textAlignment = NSTextAlignmentLeft;
    minLabel.font = [UIFont systemFontOfSize:12];

    UILabel *maxLabel = [[UILabel alloc] initWithFrame:CGRectMake(250, 40, 50, 20)];
    maxLabel.text = speedLabel(MAX_SPEED);
    maxLabel.textAlignment = NSTextAlignmentRight;
    maxLabel.font = [UIFont systemFontOfSize:12];

    UILabel *currentValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(125, 40, 50, 20)];
    currentValueLabel.text = currentSpeedLabel;
    currentValueLabel.textAlignment = NSTextAlignmentCenter;
    currentValueLabel.font = [UIFont systemFontOfSize:12];
    currentValueLabel.tag = 'cvl0';

    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 60)];
    [contentView addSubview:slider];
    [contentView addSubview:minLabel];
    [contentView addSubview:maxLabel];
    [contentView addSubview:currentValueLabel];

    slider.frame = rect;
    slider.delegate = (id <MDCSliderDelegate>)contentView;
    [slider addTarget:self action:@selector(didChangePlaybackSpeed:) forControlEvents:UIControlEventValueChanged];

    YTAlertView *alert = [%c(YTAlertView) infoDialog];
    alert.customContentView = contentView;
    alert.title = label;
    alert.shouldDismissOnBackgroundTap = YES;
    [alert addTitle:chooseFromOriginalLabel withCancelAction:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            %orig;
        });
    }];
    [alert show];
}

%new(v@:@)
- (void)didChangePlaybackSpeed:(MDCSlider *)s {
    float rate = s.value;
    UILabel *currentValueLabel = [s.superview viewWithTag:'cvl0'];
    [(id <YTVarispeedSwitchControllerDelegate>)self.delegate varispeedSwitchController:nil didSelectRate:rate];
    currentValueLabel.text = currentSpeedLabel;
}

%end

%end

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Speed",
        SelectorKey: @"didPressYouSpeed:",
        AsTextKey: @YES,
        ExtraBooleanKeys: @[MoreSpeedKey, FixNativeSpeedKey, SpeedSliderKey],
    });
    %init(Video);
    %init(Top);
    %init(Bottom);
    if (MoreSpeed()) {
        %init(Speed);
    }
    if (FixNativeSpeed()) {
        %init(OverrideNative);
    }
    %init(Slider);
}
