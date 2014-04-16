//
//  PRXPlayerPlugin.m
//  NYPRNative
//
//  Created by Bradford Kammin on 4/2/14.
//
//

#import "CDVSound.h"
#import "PRXPlayerPlugin.h"

@implementation PRXPlayerPlugin
@synthesize mAudioHandler;
@synthesize mNetworkStatus;

#pragma mark Initialization

- (void) _createAudioHandler {
    if(self->mAudioHandler==nil){
        NSLog (@"PRXPlayer Plugin creating handler.");
        
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        
        if(self->mNetworkStatus==nil){
            //CDVReachability * reach = [[CDVReachability reachabilityForInternetConnection] retain];
            CDVReachability * reach = [CDVReachability reachabilityForInternetConnection];
            //NSLog(@"Reachability Retain Count=%i", [reach retainCount]);
            [reach startNotifier];
            [self setNetworkStatus:reach];
        }
        
        self->mAudioHandler=[[AudioStreamHandler alloc]initWithCDVReachability:mNetworkStatus];
        
        // Begin watching for notifications
        [[NSNotificationCenter defaultCenter]   addObserver:self
                                                   selector:@selector(_onAudioStreamUpdate:)
                                                       name:@"AudioStreamUpdateNotification"
                                                     object:nil];
        
        [[NSNotificationCenter defaultCenter]   addObserver:self
                                                   selector:@selector(_onAudioProgressUpdate:)
                                                       name:@"AudioProgressNotification"
                                                     object:nil];
        
        [[NSNotificationCenter defaultCenter]   addObserver:self
                                                   selector:@selector(_onAudioSkipPrevious:)
                                                       name:@"AudioSkipPreviousNotification"
                                                     object:nil];
        
        [[NSNotificationCenter defaultCenter]   addObserver:self
                                                   selector:@selector(_onAudioSkipNext:)
                                                       name:@"AudioSkipNextNotification"
                                                     object:nil];
    }
}

#pragma mark Cleanup

-(void) _teardown
{
    if (self->mAudioHandler) {
        [self->mAudioHandler stopPlaying];
        //[self->mAudioHandler release];
        self->mAudioHandler = nil;
    }

    if(self->mNetworkStatus){
        
        //NSLog(@"Releasing mNetworkStatus. retainCount prior to release: %i", [self->mNetworkStatus retainCount]);
        
        [self->mNetworkStatus stopNotifier];
        //[self->mNetworkStatus release];
        
        //NSLog(@"Releasing mNetworkStatus. retainCount after release: %i", [self->mNetworkStatus retainCount]);
        
        self->mNetworkStatus=nil;
    }
}

- (void)dispose {
    NSLog(@"PRXPlayer Plugin disposing");
    
    [self _teardown];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AudioStreamUpdateNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AudioProgressNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AudioSkipPreviousNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AudioSkipNextNotification" object:nil];
    
    [super dispose];
}

#pragma Audio playback commands

- (void)playstream:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSDictionary  * params = [command.arguments  objectAtIndex:0];
    NSString* stationUrl = [params objectForKey:@"ios"];
    NSDictionary  * info = [command.arguments  objectAtIndex:1];
    
    if ( stationUrl && stationUrl != (id)[NSNull null] ) {
        NSLog (@"PRXPlayer Plugin starting stream (%@)", stationUrl);
        [self _createAudioHandler];
        [self->mAudioHandler startPlayingStream:stationUrl];
        [self setaudioinfoInternal:info];
    } else {
       NSLog (@"PRXPlayer Plugin invalid stream (%@)", stationUrl);
        // todo -- handle invalid stream url
    }
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)playfile:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* fullFilename = [command.arguments objectAtIndex:0];
    NSDictionary  * info = [command.arguments  objectAtIndex:1];
    NSInteger position = 0;
    if ( command.arguments.count > 2 && [command.arguments objectAtIndex:2] != (id)[NSNull null] ) {
        position = [[command.arguments objectAtIndex:2] integerValue];
    }
    
    if ( fullFilename && fullFilename != (id)[NSNull null] ) {
        
        // get the filename at the end of the file
        NSString *file = [[[NSURL URLWithString:fullFilename]  lastPathComponent] lowercaseString];
        NSString* path = [self _getAudioDirectory];
        NSString* fullPathAndFile=[NSString stringWithFormat:@"%@%@",path, file];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:fullPathAndFile]){
            NSLog (@"PRXPlayer Plugin playing local file (%@)", fullPathAndFile);
            [self _createAudioHandler];
            [self->mAudioHandler startPlayingLocalFile:fullPathAndFile position:position];
            [self setaudioinfoInternal:info];
        } else {
            [self playremotefile:command];
        }
        
    }else {
        NSLog (@"PRXPlayer Plugin invalid file (%@)", fullFilename);
        // todo -- handle invalid stream url
    }
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)pause:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    NSLog (@"PRXPlayer Plugin pausing playback");
    [self _createAudioHandler];
    [self->mAudioHandler pausePlaying];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)playremotefile:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    NSString* url = [command.arguments objectAtIndex:0];
    NSDictionary  * info = [command.arguments  objectAtIndex:1];
    NSInteger position = 0;
    if (command.arguments.count>2 && [command.arguments objectAtIndex:2] != (id)[NSNull null]) {
        position = [[command.arguments objectAtIndex:2] integerValue];
    }
    
    if ( url && url != (id)[NSNull null] ) {
        NSLog (@"PRXPlayer Plugin playing remote file (%@)", url);
        [self _createAudioHandler];
        [self->mAudioHandler startPlayingRemoteFile:url position:position];
        [self setaudioinfoInternal:info];
        
    } else {
        NSLog (@"PRXPlayer Plugin invalid remote file (%@)", url);
        // todo -- handle invalid stream url
    }
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)seek:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSInteger interval = [[command.arguments objectAtIndex:0] integerValue];
    
    NSLog (@"PRXPlayer Plugin seeking to interval (%d)", interval );
    [self _createAudioHandler];
    [self->mAudioHandler seekInterval:interval];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)seekto:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSInteger position = [[command.arguments objectAtIndex:0] integerValue];
    
    NSLog (@"PRXPLayer seeking to position (%d)", position );
    [self _createAudioHandler];
    [self->mAudioHandler seekTo:position];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)stop:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    NSLog (@"PRXPlayer Plugin stopping playback.");
    [self _createAudioHandler];
    [self->mAudioHandler stopPlaying];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setaudioinfo:(CDVInvokedUrlCommand*)command{
    NSDictionary  * info = [command.arguments  objectAtIndex:0];
    [self setaudioinfoInternal:info];
}

- (void)setaudioinfoInternal:(NSDictionary*) info{
    
    NSString * title = nil;
    NSString * artist = nil;
    NSString * url = nil;
    
    title = [info objectForKey:@"title"];
    artist = [info objectForKey:@"artist"];
    
    NSDictionary * artwork = [info objectForKey:@"image"];
    
    if (artwork && artwork != (id)[NSNull null]){
        url = [artwork objectForKey:@"url"];
    }
    
    [self->mAudioHandler setAudioInfo:title artist:artist artwork:url];
}

#pragma mark Audio playback helper functions

- (void)setNetworkStatus:(CDVReachability*)reachability
{
    mNetworkStatus=reachability;
}

- (void)getaudiostate:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    NSLog (@"PRXPlayer Plugin getting audio state");
    
    [self _createAudioHandler];
    [self->mAudioHandler getAudioState];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString*)_getAudioDirectory{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [NSString stringWithFormat:@"%@/Audio/",documentsDirectory];
    return path;
}

#pragma mark Audio playback event handlers

- (void) _onAudioStreamUpdate:(NSNotification *) notification
{
    if ([[notification name] isEqualToString:@"AudioStreamUpdateNotification"]){
        
        NSDictionary *dict = [notification userInfo];
        
        NSString * status = [dict objectForKey:(@"status")];
        NSString * description = [dict objectForKey:(@"description")];
        
        NSString * jsToRun=[NSString stringWithFormat:@"NYPRNativeFeatures.prototype.AudioStatusChanged(%@,\"%@\")", status,description];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeJavascript:jsToRun];
        });
        
        if([status intValue]==MEDIA_STOPPED){
            
            NSDictionary *dict2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                   0, @"progress",
                                   0, @"duration"
                                   , nil];
            
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"AudioProgressNotification"
             object:self
             userInfo:dict2];
            
        } else if ([status intValue]==MEDIA_RUNNING){
            // todo - update lock screen...
        }
    }
}

- (void) _onAudioProgressUpdate:(NSNotification *) notification
{
    if ([[notification name] isEqualToString:@"AudioProgressNotification"]){
        
        NSDictionary *dict = [notification userInfo];
        
        long progress = [[dict  objectForKey:(@"progress")] longValue];
        long duration = [[dict  objectForKey:(@"duration")] longValue];
        long available = [[dict  objectForKey:(@"available")] longValue];
        
        NSString * jsToRun=[NSString stringWithFormat:@"NYPRNativeFeatures.prototype.AudioProgress(%ld,\"%ld\", %ld)", progress,duration, available];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeJavascript:jsToRun];
        });
    }
}

- (void) _onAudioSkipNext:(NSNotification *) notification
{
    NSString * jsToRun=[NSString stringWithFormat:@"NYPRNativeFeatures.prototype.AudioSkipNext()"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self writeJavascript:jsToRun];
    });
}

- (void) _onAudioSkipPrevious:(NSNotification *) notification
{
    NSString * jsToRun=[NSString stringWithFormat:@"NYPRNativeFeatures.prototype.AudioSkipPrevious()"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self writeJavascript:jsToRun];
    });
}


@end
