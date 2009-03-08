package xPL::BinaryMessage;

=head1 NAME

xPL::BinaryMessage - Perl extension for an Binary Message

=head1 SYNOPSIS

  use xPL::BinaryMessage;

  # these are the same
  my $msg = xPL::BinaryMessage->new(raw => '123', desc => 'one, two, three');
  $msg = xPL::BinaryMessage->new(hex => '313233', desc => 'one, two, three');

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
use Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<new(%params)>

The constructor creates a new xPL::BinaryMessage object.  It takes a
parameter hash as arguments.  Valid parameters in the hash are:

=over 4

=item raw

  The binary of the message.  (One of C<raw> or C<hex> must be provided.)

=item hex

  The hex for the message.  (One of C<raw> or C<hex> must be provided.)

=item desc

  A human-readable description of the message.

=item data

  Free form user data.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  bless \%p, $pkg;
  unless (exists $p{hex} || exists $p{raw}) {
    return;
  }
  return \%p;
}

=head2 C<hex()>

Return the contents of the message as hex.

=cut

sub hex {
  $_[0]->{hex} or $_[0]->{hex} = unpack 'H*', $_[0]->{raw};
}

=head2 C<raw()>

Return the contents of the message as a binary string.

=cut

sub raw {
  $_[0]->{raw} or $_[0]->{raw} = pack 'H*', $_[0]->{hex};
}

=head2 C<str()>

Return a string summary of the message (including the description if
it was supplied).

=cut

sub str {
  $_[0]->hex.($_[0]->{desc} ? ': '.$_[0]->{desc} : '');
}

=head2 C<data()>

Return any user data that was supplied or undef otherwise.

=cut

sub data {
  $_[0]->{data};
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
