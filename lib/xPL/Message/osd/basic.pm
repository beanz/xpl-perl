package xPL::Message::osd::basic;

# $Id$

=head1 NAME

xPL::Message::osd::basic - Perl extension for xPL message base class

=head1 SYNOPSIS

  use xPL::Message::osd::basic;

  my $msg = xPL::Message::osd::basic

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
our $VERSION = qw/$Revision$/[1];

=head2 C<field_spec()>

This method returns the field specification for the body of this
message type.

=cut

sub field_spec {
  [
   {
    name => 'command',
    validation => xPL::Validation->new(type => 'Set',
                                       set => [qw/clear write
                                                  exclusive release/]),
    required => 1,
   },
   {
    name => 'text',
    validation => xPL::Validation->new(type => 'Any'),
   },
   {
    name => 'row',
    validation => xPL::Validation->new(type => 'Any'),
   },
   {
    name => 'column',
    validation =>  xPL::Validation->new(type => 'Any'),
   },
   {
    name => 'delay',
    validation => xPL::Validation->new( type => 'Pattern', pattern => '[\d.]+'),
    die => 0,
    error => 'It should be a positive number.',
   },
  ]
}

=head2 C<default_message_type()>

This method returns the default message type for this xPL message
schema.  It returns 'xpl-cmnd' since this is the only unique message
type defined by this message schema.

=cut

sub default_message_type {
  return "xpl-cmnd";
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_).' - '.
    $self->command.($self->text ? ':'.$self->text : '');
}

=head2 C<command( [ $new_command ] )>

This method returns the osd command.  If the optional new value
argument is present, then this method updates the osd command
with the new value before it returns.


=head2 C<text( [ $new_text ] )>

This method returns the osd text.  If the optional new value
argument is present, then this method updates the osd text
with the new value before it returns.


=head2 C<row( [ $new_row ] )>

This method returns the osd row.  If the optional new value
argument is present, then this method updates the osd row
with the new value before it returns.

=head2 C<column( [ $new_column ] )>

This method returns the osd column.  If the optional new value
argument is present, then this method updates the osd column
with the new value before it returns.


=head2 C<delay( [ $new_delay ] )>

This method returns the osd delay.  If the optional new value
argument is present, then this method updates the osd delay
with the new value before it returns.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_OSD.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
