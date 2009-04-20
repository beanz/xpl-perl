package xPL::IORecord::VariableLength;

=head1 NAME

xPL::IORecord::VariableLength - xPL module for xPL::IOHandle records

=head1 SYNOPSIS

  use xPL::IORecord::VariableLength;


=head1 DESCRIPTION

This module is used to encapsulate message for sending to serial devices.
The message is defined when it is created by specifying either the hex
of the message or the raw message.  A description can be provided to
make debug output clearer.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use xPL::IORecord::Simple;
use xPL::IORecord::Hex;
our @ISA = qw(xPL::IORecord::Simple);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<new(%params)>

The constructor creates a new xPL::BinaryMessage object.  It takes a
parameter hash as arguments.  Valid parameters in the hash are:

=over 4

=item raw

  The message.  (One of C<raw> or C<hex> must be provided.)

=item hex

  The hex for the message.  (One of C<raw> or C<hex> and C<bits> must
  be provided.)

=item bits

  The message length in bits.  (One of C<raw> or C<hex> and C<bits> must
  be provided.)

=item desc

  A human-readable description of the message.

=item data

  Free form user data.

=back

It returns a blessed reference when successful or undef otherwise.

=head2 C<read($buffer)>

Creates a new message from a given buffer and removes it from the
buffer.

=cut

sub read {
  my $bits = unpack "C", $_[1];
  $bits &= 0x7f; # TODO: master/slave?
  my $len = $bits / 8;
  # not a whole number of bytes so we must round it up
  $len = 1 + int $len unless ($len == int $len);

  # need header byte + $len bytes otherwise wait for more
  return 1 unless (length $_[1] >= $len + 1);

  $_[0]->new(raw => substr $_[1], 0, $len+1, '')
}

=head2 C<hex()>

Return the contents of the message as hex.

=cut

sub hex {
  return  $_[0]->{hex} if (defined $_[0]->{hex});
  ($_[0]->{bits}, $_[0]->{hex}) = unpack 'CH*', $_[0]->{raw};
  return $_[0]->{hex}
}

=head2 C<bits()>

Return the length of the message in bits.

=cut

sub bits {
  return  $_[0]->{bits} if (defined $_[0]->{bits});
  ($_[0]->{bits}, $_[0]->{hex}) = unpack 'CH*', $_[0]->{raw};
  return $_[0]->{bits}
}

=head2 C<raw()>

Return the contents of the message as a binary string.

=cut

sub raw {
  $_[0]->{raw} or $_[0]->{raw} = pack 'CH*', $_[0]->{bits}, $_[0]->{hex};
}

=head2 C<str()>

Return a string summary of the message (including the description if
it was supplied).

=cut

sub str {
  my $desc = $_[0]->desc;
  (pack 'H*', $_[0]->bits).$_[0]->hex.($desc ? ': '.$desc : '');
}

use overload ( '""'  => \&str);

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
