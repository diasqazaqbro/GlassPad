#ifndef CMULTITOUCH_H
#define CMULTITOUCH_H

/// Callback invoked for every multitouch contact frame, on the multitouch
/// device's callback thread. `xs`/`ys` are normalized finger positions in [0, 1]
/// (origin bottom-left), with `numContacts` entries.
typedef void (*GPContactHandler)(int numContacts, const float *xs, const float *ys);

/// Starts listening to all multitouch devices via the private MultitouchSupport
/// framework (loaded with dlopen so there is no build-time link dependency).
/// Returns 1 on success, 0 if the framework or its symbols could not be resolved.
int gp_multitouch_start(GPContactHandler handler);

/// Stops the registered callbacks. Safe to call if never started.
void gp_multitouch_stop(void);

#endif /* CMULTITOUCH_H */
