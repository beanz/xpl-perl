package xPL::Utils;

# $Id: Utils.pm 191 2007-03-03 17:48:47Z beanz $

=head1 NAME

xPL::Utils - Perl extension for xPL timer base class

=head1 SYNOPSIS

  # import all utility functions
  use xPL::Utils qw/:all/;

  print lo_nibble(0x16); # prints 6
  print hi_nibble(0x16); # prints 1

=head1 DESCRIPTION

This module provides some simple utility functions for use by other
modules.

=head1 FUNCTIONS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
                                   lo_nibble
                                   hi_nibble
                                   nibble_sum
                                  ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision: 191 $/[1];

=head2 C<lo_nibble($byte)>

This function returns the low nibble of a byte.  So, for example, given
0x16 it returns 6.

=cut

sub lo_nibble {
  $_[0]&0xf;
}

=head2 C<hi_nibble($byte)>

This function returns the hi nibble of a byte.  So, for example, given
0x16 it returns 1.

=cut

sub hi_nibble {
  ($_[0]&0xf0)>>4;
}

=head2 C<nibble_sum($count, \@bytes)>

This function returns the sum of the nibbles of count bytes.  If count
is not an integer then the high nibble of the count+1 th byte is added
to the sum as well.  So given the bytes [0x10, 0x20, 0x40, 0x81], the
sum when count is 3 would be 0x07, the sum when count is 3.5 would be
0xF, and the sum when count is 4 would be 0x10.

=cut

sub nibble_sum {
  my $c = $_[0];
  my $s = 0;
  foreach (0..$_[0]-1) {
    $s += hi_nibble($_[1]->[$_]);
    $s += lo_nibble($_[1]->[$_]);
  }
  $s += hi_nibble($_[1]->[$_[0]]) if (int($_[0]) != $_[0]);
  return $s;
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
