package xPL::IORecord::ZeroSplitLine;

=head1 NAME

xPL::IORecord::ZeroSplitLine - xPL module for xPL::IOHandle records

=head1 SYNOPSIS

  use xPL::IORecord::ZeroSplitLine;


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
use xPL::IORecord::LFLine;
our @ISA = qw(xPL::IORecord::LFLine);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<new(%params)>

The constructor creates a new xPL::BinaryMessage object.  It takes a
parameter hash as arguments.  Valid parameters in the hash are:

=over 4

=item text

  The message.

=item desc

  A human-readable description of the message.

=item data

  Free form user data.

=back

It returns a blessed reference when successful or undef otherwise.

=head2 C<read($buffer)>

Creates a new message from a given buffer and removes it from the
buffer.

=head2 C<raw()>

Return the contents of the message as a string.

=cut

sub raw {
  $_[0]->{raw} or $_[0]->{raw} = join chr(0), @{$_[0]->{fields}}
}

=head2 C<fields()>

Return the contents of the message as an array reference of the fields.

=cut

sub fields {
  $_[0]->{fields} or $_[0]->{fields} = [split /\000/, $_[0]->{raw}]
}

=head2 C<str()>

Return a string summary of the message (including the description if
it was supplied).

=cut

sub str {
  my $desc = $_[0]->desc;
  (join ' ', @{$_[0]->fields}).($desc ? ': '.$desc : '');
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
