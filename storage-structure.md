# Storage Structure

## Partition Layout

```text
GPT
├── EFI
│   ├── Microsoft-signed ShapeBit shim
│   ├── normal signed boot artifacts
│   └── minimal signed recovery UKI
└── LUKS2
```

## Subvolume Layout

```text
LUKS2
└── Btrfs
    ├── @base
    ├── @machine
    ├── @people
    └── @recovery
```

`@base` holds the immutable system code and data (/usr, /boot etc.)
`@machine` holds device and service state (/etc + /var)
`@people` holds inactive encrypted home-container files (/home)
`@recovery` holds only the minimal persistent recovery inventory and state.

Inactive `systemd-homed` container files are stored in `@people`. Keeping them outside `@machine` allows system reset to preserve homes
without preserving ordinary host state.