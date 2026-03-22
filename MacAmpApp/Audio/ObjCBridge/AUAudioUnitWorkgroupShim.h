#import <AudioToolbox/AudioToolbox.h>
#import <os/workgroup.h>

/// Retrieve the os_workgroup from an AUAudioUnit.
/// AUAudioUnit.osWorkgroup is __attribute__((swift_private)),
/// so this ObjC function bridges the property to Swift.
os_workgroup_t _Nullable AUAudioUnitGetWorkgroup(AUAudioUnit * _Nonnull unit);

/// Join a workgroup on the current thread.
/// Returns an opaque token (heap-allocated), or NULL on failure.
/// Caller must pass the token to AudioWorkgroupLeave when done.
void * _Nullable AudioWorkgroupJoin(os_workgroup_t _Nonnull workgroup);

/// Leave a workgroup on the current thread.
/// Token must be the value returned by AudioWorkgroupJoin.
/// Frees the token memory.
void AudioWorkgroupLeave(os_workgroup_t _Nonnull workgroup, void * _Nonnull token);
