# Checklist: persistent-state component

Every new component must answer these questions before entering the image:

- [ ] Which files does it place in `/usr`?
- [ ] Does it need files in `/etc`?
- [ ] Who owns each file in `/etc`?
- [ ] Where does it store state in `/var`?
- [ ] Does it use `StateDirectory=`, `CacheDirectory=`, and `RuntimeDirectory=`?
- [ ] What is its data-schema version?
- [ ] Is the data compatible with the previous deployment?
- [ ] How does migration work?
- [ ] How is data backed up before migration?
- [ ] How is data restored?
- [ ] What happens when space runs out?
- [ ] Can the cache be safely deleted?
- [ ] Do logs contain personal data or secrets?
- [ ] How does the component behave after a factory reset?
- [ ] Does it work with a read-only `/usr`?
- [ ] Does it behave correctly when the user's home is inactive?
- [ ] Does it avoid requiring home access before PAM completes login?
- [ ] Can any of its memory contents reach disk-backed swap?
- [ ] Does its test environment reject plaintext disk-backed swap?
- [ ] Does it have an update → rollback test?
