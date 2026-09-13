Homes share a dynamically managed capacity pool rather than fixed partitions or permanently preallocated sizes.

Every home has a guaranteed minimum plus access to a shared burst pool.Burst capacity follows actual use by default.
The owner may set hard limit per user.
Creating a new user is allowed only when the system can guarantee that user's minimum without revoking space already used by another home or machine.
The system protects machine's pool from ordinary home growth.
The protected machine reserve is calculated dynamically.
An unlimited user setting means access to the available home pool.

The system calculates the reserve in GiB as:

```text
reserve = max(30 GiB, steady + surge)
```

steady — space needed at all times: 12 GiB fixed (emergency recovery + transactional/log state) plus 2% of outer-filesystem capacity for metadata, clamped to 4–16 GiB.

surge — space needed only while staging an update: the greater of 12 GiB and the release's declared staging requirement, plus any migration workspace the release declares (zero by default).


## Low-space states

- **low** when headroom is below the greater of 16 GiB and 10% of total home pool capacity
- **critical** when headroom is below 8 GiB
- **exhausted** when no admissible burst capacity remains
