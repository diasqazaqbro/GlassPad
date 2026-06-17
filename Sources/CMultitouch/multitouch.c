#include "CMultitouch.h"

#include <dlfcn.h>
#include <stddef.h>
#include <CoreFoundation/CoreFoundation.h>

// --- Private MultitouchSupport types (classic, long-stable layout) ----------
// We only read `numContacts` and each contact's normalized position, so the
// fields after `normalized` are present purely to keep the struct's size and
// offsets matching the framework's expectation.

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTReadout;

typedef struct {
    int       frame;
    double    timestamp;
    int       identifier, state, fingerID, handID;
    MTReadout normalized;     // position in [0, 1]
    float     size;
    int       pressure;
    float     angle, majorAxis, minorAxis;
    MTReadout absolute;       // position in mm
    int       reserved[2];
    float     density;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int device, MTTouch *contacts,
                                         int numContacts, double timestamp, int frame);

typedef CFMutableArrayRef (*MTDeviceCreateListFn)(void);
typedef void (*MTRegisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallbackFunction);
typedef void (*MTUnregisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallbackFunction);
typedef void (*MTDeviceStartFn)(MTDeviceRef, int);
typedef void (*MTDeviceStopFn)(MTDeviceRef);

static void                            *g_handle     = NULL;
static MTDeviceCreateListFn             g_createList  = NULL;
static MTRegisterContactFrameCallbackFn g_register    = NULL;
static MTUnregisterContactFrameCallbackFn g_unregister = NULL;
static MTDeviceStartFn                  g_start       = NULL;
static MTDeviceStopFn                   g_stop        = NULL;
static CFMutableArrayRef                g_devices     = NULL;
static GPContactHandler                 g_handler     = NULL;

static int gp_contact_callback(int device, MTTouch *contacts, int numContacts,
                               double timestamp, int frame) {
    (void)device; (void)timestamp; (void)frame;
    GPContactHandler handler = g_handler;
    if (handler && contacts && numContacts > 0) {
        float xs[32], ys[32];
        int n = numContacts > 32 ? 32 : numContacts;
        for (int i = 0; i < n; i++) {
            xs[i] = contacts[i].normalized.position.x;
            ys[i] = contacts[i].normalized.position.y;
        }
        handler(n, xs, ys);
    }
    return 0;
}

int gp_multitouch_start(GPContactHandler handler) {
    if (g_handle) return 1; // already running

    const char *paths[] = {
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/Current/MultitouchSupport",
    };
    for (size_t i = 0; i < sizeof(paths) / sizeof(paths[0]) && !g_handle; i++) {
        g_handle = dlopen(paths[i], RTLD_LAZY);
    }
    if (!g_handle) return 0;

    g_createList = (MTDeviceCreateListFn) dlsym(g_handle, "MTDeviceCreateList");
    g_register   = (MTRegisterContactFrameCallbackFn) dlsym(g_handle, "MTRegisterContactFrameCallback");
    g_unregister = (MTUnregisterContactFrameCallbackFn) dlsym(g_handle, "MTUnregisterContactFrameCallback");
    g_start      = (MTDeviceStartFn) dlsym(g_handle, "MTDeviceStart");
    g_stop       = (MTDeviceStopFn) dlsym(g_handle, "MTDeviceStop");
    if (!g_createList || !g_register || !g_start) return 0;

    g_handler = handler;
    g_devices = g_createList();
    if (!g_devices) return 0;

    CFIndex count = CFArrayGetCount(g_devices);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef device = (MTDeviceRef) CFArrayGetValueAtIndex(g_devices, i);
        g_register(device, gp_contact_callback);
        g_start(device, 0);
    }
    return 1;
}

void gp_multitouch_stop(void) {
    if (!g_handle || !g_devices) return;
    CFIndex count = CFArrayGetCount(g_devices);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef device = (MTDeviceRef) CFArrayGetValueAtIndex(g_devices, i);
        if (g_stop)       g_stop(device);
        if (g_unregister) g_unregister(device, gp_contact_callback);
    }
    g_handler = NULL;
}
