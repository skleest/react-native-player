//
//  MyObjcClass.m
//  use_nativeModules
//
//  Created by Q on 2016. 8. 25..
//  Copyright © 2016년 Facebook. All rights reserved.
//

#import "ReactAudio.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import "RCTEventEmitter.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface ReactAudio() {
    float duration;
    NSString *rapName;
    NSString *songTitle;
    NSURL *artWorkUrl;
    id<NSObject> playbackTimeObserver;
}

@end

@implementation ReactAudio

@synthesize bridge = _bridge;


RCT_EXPORT_MODULE();

- (ReactAudio *)init {
    self = [super init];
    if (self) {
        [self registerRemoteControlEvents];
        [self registerAudioInterruptionNotifications];
        NSLog(@"AudioPlayer initialized!");
    }
    
    return self;
}


- (void)dealloc {
    NSLog(@"dealloc!!");
    [self unregisterRemoteControlEvents];
    [self unregisterAudioInterruptionNotifications];
}

#pragma mark - Pubic API


RCT_EXPORT_METHOD(prepare:(NSString *)url:(BOOL) bAutoPlay) {
    if(!([url length]>0)) return;
    
    [self.bridge.eventDispatcher sendDeviceEventWithName: @"onPlayerStateChanged"
                                                    body: @{@"playbackState": @4 }];
    
    NSURL *soundUrl = [[NSURL alloc] initWithString:url];
    self.playerItem = [AVPlayerItem playerItemWithURL:soundUrl];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    
    CMTime duration = self.player.currentItem.asset.duration;
    float seconds = CMTimeGetSeconds(duration);

    if (seconds == 0) {
        [self.bridge.eventDispatcher
         sendDeviceEventWithName: @"onPlayerError"
         body: @{@"action": @"ERROR" }];
    } else {
        if(bAutoPlay) {
            [self playAudio];
        }
    }
    
    soundUrl = nil;

}

RCT_EXPORT_METHOD(songInfo:(NSString *)name title:(NSString *)title url:(NSURL *)url) {
    rapName = name;
    songTitle = title;
    artWorkUrl = url;
    [self setNowPlayingInfo:true];
}


RCT_EXPORT_METHOD(getDuration:(RCTResponseSenderBlock)callback) {
    //this is kind of crude but it will prevent the app from crashing due to a "NAN" return(this allows the getDuration method to be executed in the componentDidMount function of the React class without the app crashing
    while(self.playerItem.status != AVPlayerItemStatusReadyToPlay){
    }
    
    float durationInMilliSeconds = duration * 1000;
    callback(@[[[NSNumber alloc] initWithFloat:durationInMilliSeconds]]);
}


RCT_EXPORT_METHOD(play) {
    [self playAudio];
}

RCT_EXPORT_METHOD(pause) {
    [self pauseOrStop:@"PAUSE"];
}

RCT_EXPORT_METHOD(resume) {
    [self playAudio];
}

RCT_EXPORT_METHOD(stop) {
    [self pauseOrStop:@"STOP"];
}

RCT_EXPORT_METHOD(seekTo:(int) nSecond) {
    CMTime newTime = CMTimeMakeWithSeconds(nSecond/1000, 1);
    [self.player seekToTime:newTime];
}


#pragma mark - Audio

-(void) playAudio {
    [self.player play];
    
    // we need a weak self here for in-block access
    __weak typeof(self) weakSelf = self;
    
    playbackTimeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        
        [weakSelf.bridge.eventDispatcher sendDeviceEventWithName: @"onUpdatePosition"
                                                            body: @{@"currentPosition": @(CMTimeGetSeconds(time)*1000) }];
    }];
    
    [self activate];
}

-(void) pauseOrStop:(NSString *)value {
    [self.player pause];
    
    if ([value isEqualToString:@"STOP"]) {
        CMTime newTime = CMTimeMakeWithSeconds(0, 1);
        [self.player seekToTime:newTime];
    } else {
        [self deactivate];
    }
    
    if (playbackTimeObserver) {
        [self.player removeTimeObserver:playbackTimeObserver];
        playbackTimeObserver = nil;
    }
}


#pragma mark - Audio Session

-(void)playFinished:(NSNotification *)notification {
    [self.playerItem seekToTime:kCMTimeZero];
    
    [self.bridge.eventDispatcher
     sendDeviceEventWithName: @"onPlayerStateChanged"
     body: @{@"playbackState": @5 }];
}

-(void)activate {
    NSError *categoryError = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&categoryError];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(playFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    
    if (categoryError) {
        NSLog(@"Error setting category in activate %@", [categoryError description]);
    }
}

- (void)deactivate {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionRouteChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    
    NSError *categoryError = nil;
    [[AVAudioSession sharedInstance] setActive:NO error:&categoryError];
    
    if (categoryError) {
        NSLog(@"Error setting category in deactivate %@", [categoryError description]);
    }
}

- (void)registerAudioInterruptionNotifications
{
    // Register for audio interrupt notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAudioInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    // Register for route change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onRouteChangeInterruption:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
}

- (void)unregisterAudioInterruptionNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionRouteChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
}

- (void)onAudioInterruption:(NSNotification *)notification
{
    // Get the user info dictionary
    NSDictionary *interruptionDict = notification.userInfo;
    
    // Get the AVAudioSessionInterruptionTypeKey enum from the dictionary
    NSInteger interuptionType = [[interruptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    // Decide what to do based on interruption type
    switch (interuptionType)
    {
        case AVAudioSessionInterruptionTypeBegan:
            [self.bridge.eventDispatcher
             sendDeviceEventWithName: @"onRemoteControl"
             body: @{@"action": @"PAUSE" }];
            break;
            
        case AVAudioSessionInterruptionTypeEnded:
            [self playAudio];
            [self.bridge.eventDispatcher
             sendDeviceEventWithName: @"onRemoteControl"
             body: @{@"action": @"PLAY" }];
            break;
            
        default:
            NSLog(@"Audio Session Interruption Notification case default.");
            break;
    }
}


#pragma mark - Remote Control Events

- (void)audioRouteChangeListenerCallback:(NSNotification*)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    // when headphone was pulled (AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
    if (routeChangeReason == 2) {
        [self.bridge.eventDispatcher
         sendDeviceEventWithName: @"onRemoteControl"
         body: @{@"action": @"PAUSE" }];
    }
}

- (void)registerRemoteControlEvents {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [commandCenter.playCommand addTarget:self action:@selector(didReceivePlayCommand:)];
    [commandCenter.pauseCommand addTarget:self action:@selector(didReceivePauseCommand:)];
    [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(didReceiveToggleCommand:)];
    [commandCenter.nextTrackCommand addTarget:self action:@selector(didReceiveNextTrackCommand:)];
    [commandCenter.previousTrackCommand addTarget:self action:@selector(didReceivePreviousTrackCommand:)];
    commandCenter.playCommand.enabled = YES;
    commandCenter.pauseCommand.enabled = YES;
    commandCenter.nextTrackCommand.enabled = YES;
    commandCenter.previousTrackCommand.enabled = YES;
    commandCenter.stopCommand.enabled = NO;
}

- (void)didReceivePlayCommand:(MPRemoteCommand *)event {
    [self playAudio];
    [self.bridge.eventDispatcher
     sendDeviceEventWithName: @"onRemoteControl"
     body: @{@"action": @"PLAY" }];
}

- (void)didReceivePauseCommand:(MPRemoteCommand *)event {
    [self pauseOrStop:@"PAUSE"];
    [self.bridge.eventDispatcher
     sendDeviceEventWithName: @"onRemoteControl"
     body: @{@"action": @"PAUSE" }];
}

- (void)didReceiveToggleCommand:(MPRemoteCommand *)event {
    // if music is playing
    if (self.player.rate == 1.0f) {
        [self pauseOrStop:@"PAUSE"];
        [self.bridge.eventDispatcher
         sendDeviceEventWithName: @"onRemoteControl"
         body: @{@"action": @"PAUSE" }];
    } else {
        [self playAudio];
        [self.bridge.eventDispatcher
         sendDeviceEventWithName: @"onRemoteControl"
         body: @{@"action": @"PLAY" }];
    }
}

- (void)didReceiveNextTrackCommand:(MPRemoteCommand *)event {
    [self.bridge.eventDispatcher
     sendDeviceEventWithName: @"onRemoteControl"
     body: @{@"action": @"NEXT" }];
}

- (void)didReceivePreviousTrackCommand:(MPRemoteCommand *)event {
    [self.bridge.eventDispatcher
     sendDeviceEventWithName: @"onRemoteControl"
     body: @{@"action": @"PREV" }];
}

- (void)unregisterRemoteControlEvents {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [commandCenter.playCommand removeTarget:self];
    [commandCenter.pauseCommand removeTarget:self];
    [commandCenter.togglePlayPauseCommand removeTarget:self];
    [commandCenter.nextTrackCommand removeTarget:self];
    [commandCenter.previousTrackCommand removeTarget:self];
}

- (void)setNowPlayingInfo:(bool)isPlaying {
    UIImage *artWork = [UIImage imageWithData:[NSData dataWithContentsOfURL:artWorkUrl]];
    MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage: artWork];
    
    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
    NSDictionary *songInfo = @{
                               MPMediaItemPropertyTitle: rapName,
                               MPMediaItemPropertyArtist: songTitle,
                               MPNowPlayingInfoPropertyPlaybackRate: [NSNumber numberWithFloat:isPlaying ? 1.0f : 0.0],
                               MPMediaItemPropertyPlaybackDuration: [NSNumber numberWithFloat:duration],
                               MPMediaItemPropertyArtwork: albumArt
                               };
    center.nowPlayingInfo = songInfo;
    albumArt = nil;
}


@end
