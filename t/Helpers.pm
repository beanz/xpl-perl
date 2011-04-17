package t::Helpers;

=head1 NAME

t::Helpers - Perl extension for Helper functions for tests.

=head1 SYNOPSIS

  use Test::More tests => 2;
  use t::Helpers qw/:all/;
  is(test_error(sub { die 'argh' }),
     'argh',
     'died horribly');

  is(test_warn(sub { warn 'danger will robinson' }),
     'danger will robinson',
     'warned nicely');

=head1 DESCRIPTION

Common functions to make test scripts a bit easier to read.  There are
CPAN modules to do this sort of thing, but most people wont have them
installed and they are pretty trivial functions so to encourage
testing they are included here.

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use File::Temp qw/tempfile/;
use Test::More;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use constant {
  DEBUG => $ENV{XPL_TEST_HELPERS_DEBUG}
};

use Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
                                   test_error
                                   test_warn
                                   test_output
                                   wait_for_callback
                                   wait_for_variable
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

# Preloaded methods go here.

=head2 C<test_error($code_ref)>

This method runs the code with eval and returns the error.  It strips
off some common strings from the end of the message including any "at
<file> line <number>" strings and any "(@INC contains: .*)".

=cut

sub test_error {
  my $sub = shift;
  eval { $sub->() };
  my $error = $EVAL_ERROR;
  if ($error) {
    $error =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $error =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $error =~ s/ \(\@INC contains:.*?\)$//;
  }
  return $error;
}

=head2 C<test_warn($code_ref)>

This method runs the code with eval and returns the warning.  It strips
off any "at <file> line <number>" specific part(s) from the end.

=cut

sub test_warn {
  my $sub = shift;
  my $warn;
  local $SIG{__WARN__} = sub { $warn .= $_[0]; };
  eval { $sub->(); };
  die $EVAL_ERROR if ($EVAL_ERROR);
  if ($warn) {
    $warn =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $warn =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $warn =~ s/ \(\@INC contains:.*?\)$//;
  }
  return $warn;
}

sub test_output {
  my ($sub, $fh) = @_;
  my ($tmpfh, $tmpfile) = tempfile();
  open my $oldfh, ">&", $fh     or die "Can't dup \$fh: $!";
  open $fh, ">&", $tmpfh or die "Can't dup \$tmpfh: $!";
  $sub->();
  open $fh, ">&", $oldfh or die "Can't dup \$oldfh: $!";
  $tmpfh->flush;
  open my $rfh, '<', $tmpfile;
  local $/;
  undef $/;
  my $c = <$rfh>;
  close $rfh;
  unlink $tmpfile;
  $tmpfh->close;
  return $c;
}

sub wait_for_callback {
  my ($xpl, $type, $id, $count) = @_;
  my $method = $type.'_callback_count';
  $count = $xpl->$method($id)+1 unless (defined $count);
  while ($xpl->$method($id) < $count) {
    #print STDERR "Waiting for $type => $id to reach $count\n";
    $xpl->main_loop(1);
  }
}

sub wait_for_variable {
  my ($xpl, $var_ref) = @_;
  my $count = ($$var_ref || 0)+1;
  while (($$var_ref || 0) < $count) {
    #print STDERR "Waiting for read_count to reach $count\n";
    $xpl->main_loop(1);
  }
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
