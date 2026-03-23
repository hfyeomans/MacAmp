#import "AUAudioUnitWorkgroupShim.h"
#import <stdlib.h>

os_workgroup_t _Nullable AUAudioUnitGetWorkgroup(AUAudioUnit * _Nonnull unit) {
    return unit.osWorkgroup;
}

void * _Nullable AudioWorkgroupJoin(os_workgroup_t _Nonnull workgroup) {
    os_workgroup_join_token_s *token = calloc(1, sizeof(os_workgroup_join_token_s));
    if (!token) return NULL;

    int result = os_workgroup_join(workgroup, token);
    if (result != 0) {
        free(token);
        return NULL;
    }
    return token;
}

void AudioWorkgroupLeave(os_workgroup_t _Nonnull workgroup, void * _Nonnull token) {
    os_workgroup_leave(workgroup, (os_workgroup_join_token_s *)token);
    free(token);
}
