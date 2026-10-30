# The test modules, in the order that a person meets them. openQA needs this one
# file in Perl; the modules are Python, through Inline::Python.
use Mojo::Base -strict;
use autotest;
use testapi;

set_var(ENABLE_MODERN_PERL_FEATURES => 1);

autotest::loadtest("tests/$_.py") for qw(
  enroll_key
  install
  boot_installed
  login
  settings
  window_layouts
  lock_unlock
  reboot
);

1;
