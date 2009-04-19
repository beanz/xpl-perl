package xPL::IORecord::CRLFLine;

=head1 NAME

xPL::IORecord::CRLFLine - xPL module for xPL::IOHandle records

=head1 SYNOPSIS

  use xPL::IORecord::CRLFLine;


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
our @ISA = qw(xPL::IORecord::Simple);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<new(%params)>

The constructor creates a new xPL::IORecord::Simple object.  It takes
a parameter hash as arguments.  Valid parameters in the hash are:

=over 4

=item raw

  The message.

=item desc

  A human-readable description of the message.

=item data

  Free form user data.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  unshift @_, 'raw' if (scalar @_ == 1);
  return $pkg->SUPER::new(@_);
}

=head2 C<read($buffer)>

Creates a new message from a given buffer and removes it from the
buffer.

=cut

sub read {
  $_[1] =~ s/^(.*?)\r?\n// ? $_[0]->new(raw => $1) : undef;
}

=head2 C<out()>

Return the contents of the message as a binary string with
output record separators appended.

=cut

sub out {
  $_[0]->raw."\r\n"
}

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
