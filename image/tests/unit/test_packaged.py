"""The image build fails on any file in /usr that no RPM owns, or that differs
from its RPM, beyond the base image's own, the generated caches and the
build's deliberate changes (packaged.py)."""

import importlib.machinery
import importlib.util
import pathlib

loader = importlib.machinery.SourceFileLoader("packaged", str(pathlib.Path(__file__).parents[2] / "packaged.py"))
packaged = importlib.util.module_from_spec(importlib.util.spec_from_loader("packaged", loader))
loader.exec_module(packaged)


def test_owned_files_are_left_out_and_the_kernel_version_too():
    found = packaged.unowned(["/usr/bin/bash"], [
        "/usr/bin/bash", "/usr/libexec/tool", "/usr/lib/modules/7.3.3-300.fc45.x86_64/kernel/a.ko.xz"])
    assert found == ["/usr/lib/modules/KERNEL/kernel/a.ko.xz", "/usr/libexec/tool"]


def test_the_base_images_own_unowned_files_and_caches_are_allowed():
    base = ["/usr/lib/modules/KERNEL/kernel/a.ko.xz", "/usr/lib/passwd"]
    found = ["/usr/lib/modules/KERNEL/kernel/a.ko.xz", "/usr/lib/passwd", "/usr/lib/fontconfig/cache/x.cache-9",
             "/usr/share/icons/Adwaita/icon-theme.cache", "/usr/share/mime/image/x-new.xml", "/usr/share/rpm/rpmdb.sqlite-wal"]
    assert packaged.unexpected(found, base) == []


def test_a_file_the_build_adds_outside_a_package_is_reported():
    found = ["/usr/libexec/os-update", "/usr/share/icons/Adwaita/scalable/new.svg", "/usr/share/mime/packages/x.xml"]
    assert packaged.unexpected(found, []) == found


def test_files_lists_files_and_links_but_not_directories(tmp_path):
    (tmp_path / "dir").mkdir()
    (tmp_path / "dir/file").write_text("x")
    (tmp_path / "link").symlink_to("dir")
    assert sorted(packaged.files(str(tmp_path))) == [str(tmp_path / "dir/file"), str(tmp_path / "link")]


VERIFIED = """\
S.5......    /usr/lib/kernel/install.conf
.M.......  g /usr/lib64/gio/modules/giomodule.cache
S.5......  c /etc/ssh/sshd_config
missing     /var/lib/sddm
..5......    /usr/share/plymouth/plymouthd.defaults
missing     /usr/lib/modules/7.3.3-300.fc45.x86_64/extra/a.ko.xz
missing     /run/sddm
""".splitlines()


def test_changed_files_are_those_under_usr_without_ghosts_or_the_kernel_version():
    assert packaged.changed(VERIFIED) == [
        "..5...... /usr/share/plymouth/plymouthd.defaults",
        "S.5...... /usr/lib/kernel/install.conf",
        "missing /usr/lib/modules/KERNEL/extra/a.ko.xz",
    ]


def test_a_change_to_a_packaged_file_is_reported_unless_the_base_or_the_build_means_it():
    found = packaged.changed(VERIFIED) + ["S.5...... /usr/share/applications/org.gnome.Nautilus.desktop"]
    base = ["S.5...... /usr/lib/kernel/install.conf", "missing /usr/lib/modules/KERNEL/extra/a.ko.xz"]
    assert packaged.unexpected(found, base) == ["S.5...... /usr/share/applications/org.gnome.Nautilus.desktop"]
