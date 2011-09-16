#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Test::More tests => 22;
use t::Helpers qw/test_warn test_error test_output/;
use lib 't/lib';
$|=1;

BEGIN{
  *CORE::GLOBAL::exit = sub { die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}

use_ok('xPL::Dock', qw/Test/);

my $xpl;
{
  local @ARGV = ();
  check_output("The -s parameter is required\n".
               "or the value can be given as a command line argument",
               'scalar using argv');

  @ARGV = (-s => 'scalar');
  check_output("The -a parameter is required\n".
               "or the values can be given as command line arguments",
               'array using argv');

  @ARGV = (-s => 'scalar', -a => '1', -a => '2');
  check_output('The -sna parameter is required',
               'scalar not using argv');

  @ARGV = (-s => 'scalar', -a => '1', -a => '2', -sna => 'scalar2');
  check_output('The -ana parameter is required',
               'array not using argv');

  @ARGV = (-s => 'scalar', -a => '1', -a => '2',
           -sna => 'scalar2', -ana => 'A', -ana => 'B');
  my $output =
    test_output(sub {
                  eval { $xpl = xPL::Dock->new(name => 'test', port => 0); }
                }, \*STDOUT);
  isnt($@, "EXIT\n", 'all found - did not die');
  is($output, '', 'all found - output');
  is($xpl->vendor_id, 'acme', 'vendor_id overriden');
  my $plugin = ($xpl->plugins)[0];
  is($plugin->scalar, 'scalar', 'all found - scalar value');
  is_deeply($plugin->array, ['1','2'], 'all found - array value');
  is($plugin->scalar_not_argv, 'scalar2', 'all found - scalar no argv value');
  is_deeply($plugin->array_not_argv, ['A','B'],
            'all found - array no argv value');

  @ARGV = (-s => 'scalar',
           -sna => 'scalar2', -ana => 'A', -ana => 'B', '1', '2');
  $output =
    test_output(sub {
                  eval { $xpl = xPL::Dock->new(name => 'test', port => 0); }
                }, \*STDOUT);
  isnt($@, "EXIT\n", 'all found - did not die');
  is($output, '', 'all found - output');
  $plugin = ($xpl->plugins)[0];
  is($plugin->scalar, 'scalar', 'all found - scalar value');
  is_deeply($plugin->array, ['1','2'], 'all found - array value');
  is($plugin->scalar_not_argv, 'scalar2', 'all found - scalar no argv value');
  is_deeply($plugin->array_not_argv, ['A','B'],
            'all found - array no argv value');
}

sub check_output {
  my ($prefix,$desc) = @_;
  my @expected = split /\n/, $prefix.q{
Usage:
      dock/xpl-test [flags] [options]
      where valid flags are:
        -h - show this help text
        -v - verbose mode
      and valid options are (default shown in brackets):
        -i if0 - the interface for xPL messages (first non-loopback or loopback)
};
  my $output =
    test_output(sub {
                  eval { $xpl = xPL::Dock->new(name => 'test', port => 0); }
                }, \*STDOUT);
  is($@, "EXIT\n", $desc.' - died');
  is_deeply([split /\n/, $output], \@expected, $desc);
}

# sample POD

=head1 NAME

dock/xpl-test - xPL Dock Test

=head1 SYNOPSIS

  dock/xpl-test [flags] [options]
  where valid flags are:
    -h - show this help text
    -v - verbose mode
  and valid options are (default shown in brackets):
    -i if0 - the interface for xPL messages (first non-loopback or loopback)

=head1 DESCRIPTION

Test POD.

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
