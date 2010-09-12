package xPL::IORecord::XML;

=head1 NAME

xPL::IORecord::XML - xPL module for xPL::IOHandle records

=head1 SYNOPSIS

  use xPL::IORecord::XML;


=head1 DESCRIPTION

This module is used to encapsulate message for sending to serial
devices.  The message is defined when it is created by specifying the
text of the message.  A description can be provided to make debug
output clearer.

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

The constructor creates a new xPL::IORecord::XML object.  It takes
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

=head2 C<read()>

Creates a new message from a given buffer (if a complete message is
available) and removes it from the buffer.  If a message isn't
available it returns undef without modifying the buffer.

=cut

sub read {
  my $re = $_[0]->tag;
  $_[1] =~ s!^.*?(<($re)>.*?</\2>)\s*!!s ? $_[0]->new(raw => $1) : undef;
}

=head2 C<tag()>

Regular expression for tags that form records.  Default is C<qr/[^>]+/>
which is almost certainly too general and should be overridden.  See
L<xPL::Dock::CurrentCost> for example usage.

=cut

sub tag {
  qr/[^>]+/
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
