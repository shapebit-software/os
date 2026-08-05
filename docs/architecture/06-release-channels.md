# 06. Release Channels

**Status:** Draft

## Channels

### Developer

Local or experimental images with debugging tools.

### Nightly

An automated image from the main branch after basic tests pass.

### Testing

A candidate intended for integration and hardware testing.

### Stable

A signed image approved for distribution to users.

## Promotion

```text
developer → nightly → testing → stable
```

Promotion should move an existing digest rather than rebuild the image.

## Stable criteria

- successful boot on supported configurations;
- successful update from the supported previous version;
- successful rollback;
- no critical desktop regressions;
- correct SELinux policies;
- signature and SBOM;
- approved release notes.

## Rollout

Stable should be published in stages:

1. internal testers;
2. a small group of devices;
3. a larger group;
4. general availability.

The rollout suspension mechanism must take effect immediately.
