#import "SSCloudKitBridge.h"

CKContainer * _Nullable SSMakeCloudKitContainer(NSString *identifier) {
    @try {
        return [CKContainer containerWithIdentifier:identifier];
    } @catch (NSException *exception) {
        NSLog(@"[Skip Slop] CloudKit unavailable (%@): %@. Running local-only.",
              exception.name, exception.reason);
        return nil;
    }
}
