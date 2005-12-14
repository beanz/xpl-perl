package xPL::Message::cid::basic;

# $Id: basic.pm 46 2005-12-11 22:06:30Z beanz $

=head1 NAME

xPL::Message::cid::basic - Perl class for xPL 'cid.basic' messages

=head1 SYNOPSIS

  use xPL::Message::cid::basic;

  my $msg = xPL::Message::cid::basic

=head1 DESCRIPTION

This module creates an xPL message.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use xPL::Message;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Message);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision: 46 $/[1];

=head2 C<field_spec()>

This method returns the field specification for the body of this
message type.

=cut

sub field_spec {
  [
   {
    name => 'calltype',
    validation => xPL::Validation->new(type => 'Set',
                                       set => [qw/inbound outbound/]),
    required => 1,
    die => 1,
   },
   {
    name => 'phone',
    validation => xPL::Validation->new(type => 'Any'),
    required => 1,
   },
  ]
}

=head2 C<default_message_type()>

This method returns the default message type for this xPL message
schema.  It returns 'xpl-trig' since this is the only unique message
type defined by this message schema.

=cut

sub default_message_type {
  return "xpl-trig";
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_).' - '.$self->calltype.'/'.$self->phone;
}

=head2 C<calltype( [ $new_calltype ] )>

This method returns the cid calltype.  If the optional new value
argument is present, then this method updates the cid calltype with
the new value before it returns.  Valid calltypes are 'inbound' and
'outbound'.


=head2 C<phone( [ $new_phone ] )>

This method returns the cid phone value.  If the optional new value
argument is present, then this method updates the cid phone attribute
with the new value before it returns.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_CID.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
