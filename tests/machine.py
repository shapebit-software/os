#!/usr/bin/env python3
"""The machines that the OS is tested on (README.md): QEMU with Secure Boot
firmware and a software TPM, as a PC has, reached over SSH with the
development key, which QEMU passes as the systemd credential
ssh.authorized_keys.root; nothing is baked into a disk. The checks' fixtures
(conftest.py), openQA's (openqa/lib/sut.py) and `make disk`, `make vm` and
`make ssh` all use this.

The test settings are here, in SETTINGS, each overridable from the
environment; the build's, such as BUILD and MEDIUM, come from the Makefile.

Usage: machine.py install [--window]   install to a new DISK from MEDIUM, as a person
                                       does: check the medium, then install through
                                       installerctl; or open it in a window instead
       machine.py boot                 boot DISK on this terminal (Ctrl-A X quits)
       machine.py ssh [COMMAND...]     a root shell, or COMMAND, in the running machine
"""

import datetime
import importlib.util
import json
import os
import pathlib
import secrets
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]

# The test settings, and their defaults; "{BUILD}" is the Makefile's BUILD.
# The installer's settings differ from the image's defaults, so the checks
# show that the installer applied them.
SETTINGS = {
    "DISK": "{BUILD}/disk.raw",
    "DISK_SIZE": "20G",
    "RESULTS": "{BUILD}/results",
    "SSH_KEY": "{BUILD}/ssh/id_ed25519",
    # The installed machine's port, for `make vm`; each disposable clone has
    # its own, so that both can run.
    "SSH_PORT": "2222",
    "TEST_SSH_PORT": "2223",
    "BOOT_TIMEOUT": "300",
    "OWNER_NAME": "dev",
    "OWNER_PASSWORD": "{BUILD}/owner-password",
    "RECOVERY_KEY": "{BUILD}/recovery-key",
    "LOCALE": "en_GB.UTF-8",
    "KEYBOARD_LAYOUT": "pl",
    "TIME_ZONE": "Europe/Warsaw",
}

# edk2-ovmf's 4 MB build, which openQA's machine boots too (openqa/run.py):
# with the 2 MB one, the installer's check that the TPM unlocks the new volume
# fails. The variables hold Microsoft's keys with Secure Boot on, as a factory
# PC has, so shim starts and the image's certificate must be enrolled once.
FIRMWARE_CODE = "/usr/share/edk2/ovmf/OVMF_CODE_4M.secboot.qcow2"
FIRMWARE_VARS = "/usr/share/edk2/ovmf/OVMF_VARS_4M.secboot.qcow2"


def setting(name):
    """A test setting from the environment, or its default; a build setting from
    the environment, which make sets."""
    value = os.environ.get(name) or SETTINGS.get(name)
    if value is None:
        raise KeyError(f"{name} is not set; run this through make")
    return value.replace("{BUILD}", setting("BUILD")) if "{BUILD}" in value else value


def path(name):
    return ROOT / setting(name)


def ssh_key():
    """The development key, made on first use; the machines get its public half."""
    key = path("SSH_KEY")
    if not key.exists():
        key.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "shapebit-dev", "-f", key], check=True)
    return key


def owner_password():
    """The first owner's password on development machines, made on first use."""
    password = path("OWNER_PASSWORD")
    if not password.exists():
        password.parent.mkdir(parents=True, exist_ok=True)
        with os.fdopen(os.open(password, os.O_WRONLY | os.O_CREAT, 0o600), "w") as file:
            file.write(secrets.token_urlsafe(18))
    return password.read_text()


def new_run(name):
    """The results directory of one test run: RESULTS/<time>-NAME."""
    run = path("RESULTS") / f"{datetime.datetime.now(datetime.UTC):%Y%m%dT%H%M%SZ}-{name}"
    run.mkdir(parents=True)
    return run


def wait_until(predicate, timeout=30, interval=1):
    """Poll for a state that arrives on its own, such as a session starting;
    the last value, which is false if it never came."""
    deadline = time.monotonic() + timeout
    while True:
        value = predicate()
        if value or time.monotonic() >= deadline:
            return value
        time.sleep(interval)


def recorded(file, key):
    """A value of the record beside a medium or a disk (images/installer/provenance.py)."""
    file = pathlib.Path(file)
    return json.loads(file.with_name(file.name + ".json").read_text())[key]


def provenance():
    spec = importlib.util.spec_from_file_location("provenance", ROOT / "images/installer/provenance.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def archive_digest(archive):
    """The digest of an image archive's own manifest, which `bootc status` reports."""
    return provenance().image_digest(archive)


def archive_label(archive, key):
    return provenance().label(archive, key)


class Machine:
    """A machine reached at ADDRESS:PORT. With DIRECTORY, also one that this
    starts: its DISK, and in DIRECTORY what belongs to the machine and not the
    disk, its EFI variables and TPM, as well as its console and monitor. The
    installed disk unlocks only with the TPM it was sealed to, so the three go
    together. With MEDIUM, it boots the installer medium, with DISK attached."""

    def __init__(self, address="127.0.0.1", port=None, directory=None, disk=None, disk_format="raw",
                 medium=None, multiplex=True):
        self.address = address
        self.port = int(port or setting("SSH_PORT"))
        self.directory = pathlib.Path(directory) if directory else None
        self.disk, self.disk_format, self.medium = disk, disk_format, medium
        # One SSH connection for every command, except where the machine
        # restarts behind the tests' back, as in openQA's modules. The socket's
        # path must be short.
        self.control = tempfile.mkdtemp(prefix="ssh-") if multiplex else None

    # SSH

    def ssh_options(self):
        options = ["-i", str(ssh_key()), "-p", str(self.port),
                   # Each disk has new host keys, so they are never recorded.
                   "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
                   "-o", "LogLevel=ERROR", "-o", "ConnectTimeout=5",
                   "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=3"]
        if self.control:
            options += ["-o", "ControlMaster=auto", "-o", f"ControlPath={self.control}/%C",
                        "-o", "ControlPersist=60"]
        return options

    def ssh(self, command, input=None):
        return subprocess.run(["ssh", *self.ssh_options(), f"root@{self.address}", command],
                              input=input, capture_output=True, text=True, encoding="utf-8")

    def run(self, command, input=None):
        """COMMAND's output; fails unless it succeeds."""
        done = self.ssh(command, input)
        if done.returncode != 0:
            raise AssertionError(f"{command}: {done.returncode}\n{done.stdout}\n{done.stderr}")
        return done.stdout

    def close(self):
        """Ends the shared connection, which outlives a restart of the machine."""
        if self.control:
            subprocess.run(["ssh", *self.ssh_options(), "-O", "exit", f"root@{self.address}"],
                           capture_output=True)

    def wait_for_ssh(self, timeout=None):
        timeout = int(timeout or setting("BOOT_TIMEOUT"))
        deadline = time.monotonic() + timeout
        while self.ssh("true").returncode != 0:
            if time.monotonic() >= deadline:
                console = self.console()[-3000:] if self.directory else ""
                raise AssertionError(f"no SSH after {timeout}s{'; last console lines:' if console else ''}\n{console}")
            time.sleep(3)

    def boot_id(self):
        return self.run("cat /proc/sys/kernel/random/boot_id").strip()

    def reboot(self):
        """Restarts the machine, and waits until it is back, as a new boot."""
        before = self.boot_id()
        self.ssh("systemctl reboot")
        self.close()
        deadline = time.monotonic() + int(setting("BOOT_TIMEOUT"))
        while True:
            time.sleep(5)
            done = self.ssh("cat /proc/sys/kernel/random/boot_id")
            if done.returncode == 0 and done.stdout.strip() != before:
                return
            if time.monotonic() >= deadline:
                raise AssertionError("the machine did not come back after restarting")

    def save_diagnostics(self, directory):
        """What a failure needs explained: the journal, the failed units, and
        what bootc booted."""
        for name, command in (("journal.txt", "journalctl --no-pager"),
                              ("failed-units.txt", "systemctl --failed --no-pager"),
                              ("bootc-status.json", "bootc status --format=json")):
            done = self.ssh(command)
            (pathlib.Path(directory) / name).write_text(done.stdout + done.stderr)

    # QEMU

    def file(self, name):
        return self.directory / name

    def console(self):
        try:
            return self.file("serial.log").read_text(errors="replace")
        except FileNotFoundError:
            return ""

    def qemu_args(self):
        credential = subprocess.run(["base64", "-w0", f"{ssh_key()}.pub"], check=True, capture_output=True,
                                    text=True).stdout
        tpm = self.file("tpm")
        args = [
            "-machine", "q35,smm=on,accel=kvm", "-cpu", "host", "-m", "4096", "-smp", "4",
            "-global", "driver=cfi.pflash01,property=secure,value=on",
            "-drive", f"if=pflash,format=qcow2,unit=0,readonly=on,file={FIRMWARE_CODE}",
            "-drive", f"if=pflash,format=qcow2,unit=1,file={self.file('efivars.qcow2')}",
            # The serial numbers give the disks the stable identity that the
            # installer selects by.
            "-drive", f"if=none,id=target,format={self.disk_format},discard=unmap,file={self.disk}",
            "-device", "virtio-blk-pci,drive=target,serial=target,bootindex=2",
            "-chardev", f"socket,id=tpm,path={tpm}/swtpm.sock",
            "-tpmdev", "emulator,id=tpm,chardev=tpm", "-device", "tpm-crb,tpmdev=tpm",
            "-vga", "none", "-device", "virtio-vga",
            "-nic", f"user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:{self.port}-:22",
            "-smbios", f"type=11,value=io.systemd.credential.binary:ssh.authorized_keys.root={credential}",
        ]
        if self.medium:
            # Booting writes to the root; the snapshot keeps the medium as it was
            # built, so that what was tested and released has the recorded checksum.
            args += ["-drive", f"if=none,id=medium,format=raw,snapshot=on,file={self.medium}",
                     "-device", "virtio-blk-pci,drive=medium,serial=medium,bootindex=1"]
        return args

    def start(self, mode="background"):
        """Boots the machine: on this terminal (console), its screen in a window
        with the console on this terminal (window), or detached until SSH is up
        (background)."""
        if not pathlib.Path(self.disk).exists():
            sys.exit(f"error: {self.disk} not found; run 'make disk'")
        if not pathlib.Path(FIRMWARE_CODE).exists():
            sys.exit(f"error: {FIRMWARE_CODE} not found; run this in the development image")
        if self.medium and not pathlib.Path(self.medium).exists():
            sys.exit(f"error: {self.medium} not found; run 'make installer'")
        self.directory.mkdir(parents=True, exist_ok=True)
        new_machine = not self.file("efivars.qcow2").exists()
        if new_machine:
            shutil.copyfile(FIRMWARE_VARS, self.file("efivars.qcow2"))
        tpm = self.file("tpm")
        tpm.mkdir(exist_ok=True)
        (tpm / "swtpm.sock").unlink(missing_ok=True)
        subprocess.run(["swtpm", "socket", "--tpm2", "--tpmstate", f"dir={tpm}",
                        "--ctrl", f"type=unixio,path={tpm}/swtpm.sock", "--terminate", "--daemon"], check=True)
        qemu = ["qemu-system-x86_64", *self.qemu_args()]
        if mode == "console":
            os.execvp(qemu[0], [*qemu, "-nographic"])
        if mode == "window":
            os.execvp(qemu[0], [*qemu, "-serial", "mon:stdio"])
        for name in ("monitor.in", "monitor.out", "serial.log"):
            self.file(name).unlink(missing_ok=True)
        os.mkfifo(self.file("monitor.in"))
        os.mkfifo(self.file("monitor.out"))
        subprocess.run([*qemu, "-display", "none", "-monitor", f"pipe:{self.file('monitor')}",
                        "-serial", f"file:{self.file('serial.log')}",
                        "-daemonize", "-pidfile", self.file("vm.pid")], check=True)
        # On a new machine, the first boot of the medium stops at shim's MOK manager.
        if self.medium and new_machine:
            self.enroll_mok()
        print(f"Waiting up to {setting('BOOT_TIMEOUT')}s for SSH (console: {self.file('serial.log')})", flush=True)
        self.wait_for_ssh()

    def enroll_mok(self):
        """Enrolls the image's certificate, as a person does at a new PC's first
        boot of the medium: shim refuses systemd-boot and opens its MOK manager;
        there, Enroll key from disk, enroll-this-key.cer, Continue, Yes, Reboot.
        Keys go to QEMU's monitor; the screens are read from the serial console."""
        offset = 0

        def step(text, *keys):
            nonlocal offset
            timeout = int(setting("BOOT_TIMEOUT"))
            deadline = time.monotonic() + timeout
            while text not in self.console()[offset:]:
                if time.monotonic() >= deadline:
                    raise AssertionError(f"no '{text}' on the console after {timeout}s")
                time.sleep(1)
            # The console shows a screen before the screen takes keys.
            time.sleep(1)
            offset = len(self.console())
            for key in keys:
                with open(self.file("monitor.in"), "w") as monitor:
                    monitor.write(f"sendkey {key}\n")
                time.sleep(1)

        step("Verification failed", "ret")
        step("Press any key", "ret")
        step("Perform MOK management", "down", "ret")
        # The partition, then the certificate: the last entry, after EFI/ and loader/.
        step("Select Key", "ret")
        step("enroll-this-key.cer", "down", "down", "ret")
        step("View key 0", "down", "ret")
        step("Enroll the key", "down", "ret")
        step("Reboot", "ret")

    def stop(self):
        """Powers the detached machine off, so that its writes reach the disk."""
        self.close()
        try:
            pid = int(self.file("vm.pid").read_text())
            # A stale PID file must not stop an unrelated process.
            if b"qemu" not in pathlib.Path(f"/proc/{pid}/cmdline").read_bytes():
                return
        except (FileNotFoundError, ValueError):
            return
        self.ssh("systemctl poweroff")
        for _ in range(60):
            if not pathlib.Path(f"/proc/{pid}").exists():
                return
            time.sleep(1)
        print("warning: the machine did not power off; killing it", file=sys.stderr)
        subprocess.run(["kill", str(pid)])

    def clone(self, directory, port):
        """A disposable copy of this machine in DIRECTORY: a disk overlay, which
        leaves this disk unwritten, with copies of its EFI variables and TPM."""
        directory = pathlib.Path(directory)
        directory.mkdir(parents=True)
        disk = directory / "disk.qcow2"
        subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", "-F", self.disk_format,
                        "-b", pathlib.Path(self.disk).resolve(), disk], check=True)
        shutil.copyfile(self.file("efivars.qcow2"), directory / "efivars.qcow2")
        subprocess.run(["cp", "-a", self.file("tpm"), directory / "tpm"], check=True)
        return Machine(port=port, directory=directory, disk=disk, disk_format="qcow2")


def installed():
    """The machine that `make disk` installed, with BUILD as its directory."""
    disk = path("DISK")
    if not disk.with_name(disk.name + ".json").exists():
        sys.exit(f"error: {disk}.json not found; run 'make disk'")
    return Machine(directory=path("BUILD"), disk=disk)


def install(window=False):
    """Installs to a new disk from the medium, as a person does, and saves the
    recovery key. A new disk is a new machine: new EFI variables and TPM."""
    build, disk, medium = path("BUILD"), path("DISK"), path("MEDIUM")
    record = medium.with_name(medium.name + ".json")
    for stale in (disk, disk.with_name(disk.name + ".json"), path("RECOVERY_KEY"),
                  build / "efivars.qcow2", build / "serial.log"):
        stale.unlink(missing_ok=True)
    shutil.rmtree(build / "tpm", ignore_errors=True)
    subprocess.run(["truncate", "-s", setting("DISK_SIZE"), disk], check=True)
    machine = Machine(directory=build, disk=disk, medium=medium)
    if window:
        machine.start("window")
    try:
        machine.start()
        checks = subprocess.run([sys.executable, "-m", "pytest", "-c", ROOT / "tests/pytest.ini", "-p",
                                 "no:cacheprovider", ROOT / "tests/medium", f"--machine=ssh://127.0.0.1:{machine.port}",
                                 "--run=medium"],
                                env=os.environ | {"IMAGE_DIGEST": recorded(medium, "image_digest")})
        if checks.returncode != 0:
            sys.exit("error: the medium's checks failed")
        # The password and the recovery key stay in the machine's memory (/run).
        # The small home leaves the disk to the system.
        machine.run("umask 077 && cat >/run/owner-password", input=owner_password())
        machine.run(f"installerctl install --disk serial-target --user {setting('OWNER_NAME')} "
                    f"--home-size {1024 ** 3} --locale {setting('LOCALE')} "
                    f"--keyboard-layout {setting('KEYBOARD_LAYOUT')} --time-zone {setting('TIME_ZONE')} "
                    "--password-file /run/owner-password --recovery-key-file /run/recovery-key")
        key = machine.run("cat /run/recovery-key")
        with os.fdopen(os.open(path("RECOVERY_KEY"), os.O_WRONLY | os.O_CREAT, 0o600), "w") as file:
            file.write(key)
    finally:
        machine.stop()
    # A later build replaces the medium's record, so the disk keeps its own.
    shutil.copyfile(record, disk.with_name(disk.name + ".json"))


def main(command=None, *args):
    if command == "install" and args in ((), ("--window",)):
        install(window=bool(args))
    elif command == "boot" and not args:
        installed().start("console")
    elif command == "ssh":
        machine = Machine()
        os.execvp("ssh", ["ssh", "-t", *machine.ssh_options(), f"root@{machine.address}", *args])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
