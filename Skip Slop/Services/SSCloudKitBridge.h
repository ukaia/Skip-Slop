#import <CloudKit/CloudKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Builds a `CKContainer` without letting a CloudKit `NSException` kill the process.
///
/// `+[CKContainer defaultContainer]` and `+[CKContainer containerWithIdentifier:]` raise
/// `CKException` — an Objective-C exception, which Swift cannot catch — when the running
/// binary carries no iCloud entitlement. A simulator build signed to run locally is the
/// common case; a provisioning profile missing the container is the dangerous one.
/// `CloudKitService.shared` is reached from `@main` on the first frame, so that exception
/// was an unrecoverable launch crash rather than a degraded feature.
///
/// Returns nil instead, so the caller runs local-only.
CKContainer * _Nullable SSMakeCloudKitContainer(NSString *identifier);

NS_ASSUME_NONNULL_END
