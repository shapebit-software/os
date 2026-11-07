# The test modules, in the order that a person meets them. openQA needs this one
# file in Perl; the modules are Python, through Inline::Python. FLOW chooses the
# order: install tests the medium and then the desktop of the system it
# installed; update installs, then updates that system to the candidate, the
# path that existing systems take, and tests the candidate's desktop.
use Mojo::Base -strict;
use autotest;
use testapi;

set_var(ENABLE_MODERN_PERL_FEATURES => 1);

my @install = qw(enroll_key install boot_installed);
my @desktop = qw(login settings window_layouts dictation lock_unlock reboot);
my %flows = (
  install => [@install, @desktop],
  update  => [@install, 'update', @desktop],
);
my $flow = get_var('FLOW', 'install');
die "unknown FLOW $flow" unless $flows{$flow};

autotest::loadtest("tests/$_.py") for @{$flows{$flow}};

1;
