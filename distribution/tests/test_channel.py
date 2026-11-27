"""distribution/channel.py: what promote, undo and prune decide, on made-up
releases and package versions, without registries or GitHub."""

import json

import pytest

import channel
from common import REPOSITORY

# A candidate's trust files, as the draft keeps them.
TRUST = {
    "policy": json.dumps({"default": [{"type": "insecureAcceptAnything"}], "transports": {"docker": {
        "ghcr.io/shapebit-software/os": [{"type": "sigstoreSigned", "keyPath": "/usr/share/pki/containers/shapebit-os.pub",
                                          "signedIdentity": {"type": "matchRepository"}}]}}}),
    "key": "-----BEGIN PUBLIC KEY-----\nkey\n-----END PUBLIC KEY-----\n",
    "registries": "docker:\n  ghcr.io/shapebit-software/os:\n    use-sigstore-attachments: true\n",
}

RELEASES = [
    {"tagName": "202611190300", "name": "202611190300", "isDraft": True, "isLatest": False},
    {"tagName": "202611180300", "name": "202611180300", "isDraft": True, "isLatest": False},
    {"tagName": "202611120300", "name": "202611120300", "isDraft": False, "isLatest": True},
    {"tagName": "202611100300", "name": "202611100300 (withdrawn)", "isDraft": False, "isLatest": False},
    {"tagName": "202611090300", "name": "202611090300", "isDraft": False, "isLatest": False},
]


def test_the_newest_draft_is_the_candidate_to_release():
    assert channel.draft_version(RELEASES) == "202611190300"
    assert channel.draft_version([r for r in RELEASES if not r["isDraft"]]) is None


def test_undo_goes_back_past_withdrawn_releases():
    assert channel.latest_release(RELEASES) == "202611120300"
    assert channel.previous_release(RELEASES, "202611120300") == "202611090300"
    assert channel.previous_release(RELEASES, "202611090300") is None


def test_a_signature_is_beside_the_image_it_signs():
    assert channel.signature_tag("sha256:abc") == "sha256-abc.sig"


VERSIONS = [
    {"id": 1, "name": "sha256:new", "tags": ["stable", "202611120300"]},
    {"id": 2, "name": "sha256:new-src", "tags": ["202611120300-sources"]},
    {"id": 3, "name": "sha256:prev", "tags": ["202611051112", "candidate"]},
    {"id": 4, "name": "sha256:prev-src", "tags": ["202611051112-sources"]},
    {"id": 5, "name": "sha256:old", "tags": ["202611031907", "stable-previous"]},
    {"id": 6, "name": "sha256:loose", "tags": []},
    {"id": 7, "name": "sha256:child", "tags": []},
    {"id": 8, "name": "sha256:sig", "tags": ["sha256-new.sig"]},
]
KEEP = ["stable", "202611120300", "202611120300-sources", "202611051112", "202611051112-sources", "sha256-new.sig"]


def test_prune_keeps_the_tagged_versions_and_deletes_the_rest_untagged_too():
    deleted = channel.to_delete(VERSIONS, KEEP, lambda digest: [])
    assert [v["id"] for v in deleted] == [5, 6, 7]


def test_prune_keeps_what_a_kept_index_refers_to():
    deleted = channel.to_delete(VERSIONS, KEEP, lambda digest: ["sha256:child"] if digest == "sha256:new" else [])
    assert [v["id"] for v in deleted] == [5, 6]


def test_prune_refuses_when_a_tag_to_keep_is_missing():
    with pytest.raises(ValueError, match="202611120300-sources"):
        channel.to_delete([v for v in VERSIONS if v["id"] != 2], KEEP, lambda digest: [])


def test_releases_are_verified_with_the_candidates_own_policy_key_and_registries(tmp_path):
    with channel.trusted(TRUST, tmp_path) as (policy, registries_d):
        rules = json.loads(policy.read_text())["transports"]["docker"][REPOSITORY]
        assert rules == [{"type": "sigstoreSigned", "keyPath": str(tmp_path / "release-image.pub"),
                          "signedIdentity": {"type": "matchRepository"}}]
        assert (tmp_path / "release-image.pub").read_text() == TRUST["key"]
        assert (registries_d / "shapebit-os.yaml").read_text() == TRUST["registries"]


def test_a_policy_without_the_installed_key_is_refused():
    with pytest.raises(ValueError):
        channel.verification_policy({"default": [{"type": "reject"}]}, "/repo/release-image.pub")
