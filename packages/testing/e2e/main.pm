# The test modules, in the order that a person meets them. openQA needs this one
# file in Perl; the modules are Python, through Inline::Python, in tests/FEATURE/,
# which run.py fills from each feature's packages/FEATURE/tests/e2e/. FLOW chooses the
# order: install tests the medium and then the desktop of the system it
# installed; update installs, then updates that system to the candidate, the
# path that existing systems take, and tests the candidate's desktop.
use Mojo::Base -strict;
use autotest;
use testapi;

set_var(ENABLE_MODERN_PERL_FEATURES => 1);

my @install = qw(installer/enroll_key installer/install boot/boot_installed);
my @desktop = qw(login/login shell/settings windows/window_layouts assistant/assistant
  dictation/dictation login/lock_unlock boot/reboot);
my %flows = (
  install => [@install, @desktop],
  update  => [@install, 'updates/update', @desktop],
);
my $flow = get_var('FLOW', 'install');
die "unknown FLOW $flow" unless $flows{$flow};

autotest::loadtest("tests/$_.py") for @{$flows{$flow}};

1;
