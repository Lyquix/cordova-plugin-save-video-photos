#import <Cordova/CDV.h>
#import <Photos/Photos.h>

@interface SaveVideo : CDVPlugin
- (void)save:(CDVInvokedUrlCommand*)command;
@end

@implementation SaveVideo

- (void)save:(CDVInvokedUrlCommand*)command {
    NSString *path = (command.arguments.count > 0) ? command.arguments[0] : nil;
    id albumArg = (command.arguments.count > 1) ? command.arguments[1] : nil;
    NSString *albumName = ([albumArg isKindOfClass:[NSNull class]] ? nil : albumArg);

    if (path.length == 0) {
        [self sendError:@"Missing path" cb:command.callbackId];
        return;
    }

    // Normalize to file URL
    NSURL *fileURL = [NSURL URLWithString:path];
    if (!fileURL || !fileURL.isFileURL) {
        fileURL = [NSURL fileURLWithPath:path];
    }

    void (^doSave)(void) = ^{
        __block NSString *createdLocalId = nil;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *req = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            PHObjectPlaceholder *ph = [req placeholderForCreatedAsset];
            createdLocalId = ph.localIdentifier;
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (!success || error) {
                [self sendError:(error.localizedDescription ?: @"Save failed") cb:command.callbackId];
                return;
            }
            if (albumName.length == 0) {
                [self sendOK:(createdLocalId ?: @"OK") cb:command.callbackId];
                return;
            }
            // Add to (or create) album
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetCollection *collection = [self fetchOrCreateAlbum:albumName];
                if (collection) {
                    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[createdLocalId] options:nil];
                    PHAsset *asset = assets.firstObject;
                    if (asset) {
                        PHAssetCollectionChangeRequest *colReq = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:collection];
                        [colReq addAssets:@[asset]];
                    }
                }
            } completionHandler:^(BOOL success2, NSError * _Nullable error2) {
                if (!success2 || error2) {
                    [self sendError:(error2.localizedDescription ?: @"Album add failed") cb:command.callbackId];
                } else {
                    [self sendOK:(createdLocalId ?: @"OK") cb:command.callbackId];
                }
            }];
        }];
    };

    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                doSave();
            } else {
                [self sendError:@"Photos permission denied" cb:command.callbackId];
            }
        }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                doSave();
            } else {
                [self sendError:@"Photos permission denied" cb:command.callbackId];
            }
        }];
    }
}

- (PHAssetCollection *)fetchOrCreateAlbum:(NSString *)title {
    PHFetchOptions *opts = [[PHFetchOptions alloc] init];
    opts.predicate = [NSPredicate predicateWithFormat:@"localizedTitle = %@", title];
    PHFetchResult<PHAssetCollection *> *result =
        [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                 subtype:PHAssetCollectionSubtypeAny
                                                 options:opts];
    if (result.firstObject) return result.firstObject;

    __block NSString *localId = nil;
    NSError *error = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetCollectionChangeRequest *req = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:title];
        localId = req.placeholderForCreatedAssetCollection.localIdentifier;
    } error:&error];
    if (!localId) return nil;

    PHFetchResult<PHAssetCollection *> *fetch =
        [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[localId] options:nil];
    return fetch.firstObject;
}

- (void)sendOK:(NSString *)msg cb:(NSString *)cbId {
    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:msg ?: @"OK"];
    [self.commandDelegate sendPluginResult:res callbackId:cbId];
}

- (void)sendError:(NSString *)msg cb:(NSString *)cbId {
    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:msg ?: @"Error"];
    [self.commandDelegate sendPluginResult:res callbackId:cbId];
}

@end
