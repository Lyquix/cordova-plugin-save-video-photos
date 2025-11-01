#import <Cordova/CDV.h>
#import <Photos/Photos.h>

@interface SaveVideo : CDVPlugin
- (void)save:(CDVInvokedUrlCommand*)command;
@end

@implementation SaveVideo

- (void)save:(CDVInvokedUrlCommand*)command {
    NSString *path = [command.arguments objectAtIndex:0];
    id albumArg = command.arguments.count > 1 ? [command.arguments objectAtIndex:1] : nil;
    NSString *albumName = ([albumArg isKindOfClass:[NSNull class]] ? nil : albumArg);

    if (path.length == 0) {
        CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Missing path"];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Normalize cdvfile:// to file:// if needed
    if ([path hasPrefix:@"cdvfile://"]) {
        // Let Cordova resolve it if necessary; simplest path is to ask the webview to convert,
        // but for most capture results it's already file://
        // Assume file:// for typical capture URIs.
    }
    NSURL *fileURL = [NSURL URLWithString:path];
    if (!fileURL || !fileURL.isFileURL) {
        fileURL = [NSURL fileURLWithPath:path];
    }

    // Request Photos permission (add-only is fine on iOS 14+, fallback to full)
    void (^saveBlock)(void) = ^{
        __block NSString *localId = nil;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *createReq = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            PHObjectPlaceholder *ph = [createReq placeholderForCreatedAsset];
            localId = ph.localIdentifier;
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (!success || error) {
                CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription ?: @"Save failed"];
                [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
                return;
            }

            if (albumName.length == 0) {
                CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:localId ?: @"OK"];
                [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
                return;
            }

            // Ensure album exists, then add asset to it
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetCollection *collection = [self fetchOrCreateAlbum:albumName];
                if (collection) {
                    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
                    PHAsset *asset = assets.firstObject;
                    if (asset) {
                        PHAssetCollectionChangeRequest *colReq = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:collection];
                        [colReq addAssets:@[asset]];
                    }
                }
            } completionHandler:^(BOOL success2, NSError * _Nullable error2) {
                if (!success2 || error2) {
                    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error2.localizedDescription ?: @"Album add failed"];
                    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
                } else {
                    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:localId ?: @"OK"];
                    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
                }
            }];
        }];
    };

    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                saveBlock();
            } else {
                CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Photos permission denied"];
                [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            }
        }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                saveBlock();
            } else {
                CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Photos permission denied"];
                [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            }
        }];
    }
}

- (PHAssetCollection *)fetchOrCreateAlbum:(NSString *)title {
    PHFetchOptions *opts = [[PHFetchOptions alloc] init];
    opts.predicate = [NSPredicate predicateWithFormat:@"localizedTitle = %@", title];
    PHFetchResult<PHAssetCollection *> *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:opts];
    if (result.firstObject) return result.firstObject;

    __block NSString *localId = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetCollectionChangeRequest *req = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:title];
        localId = req.placeholderForCreatedAssetCollection.localIdentifier;
    } error:nil];
    if (!localId) return nil;
    PHFetchResult<PHAssetCollection *> *fetch = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[localId] options:nil];
    return fetch.firstObject;
}

@end
