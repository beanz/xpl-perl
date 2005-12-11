package xPL::Message::hbeat::app;

# $Id$

=head1 NAME

xPL::Message::hbeat::app - Perl extension for xPL message base class

=head1 SYNOPSIS

  use xPL::Message::hbeat::app;

  my $msg = xPL::Message::hbeat::app

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
    name => 'interval',
    validation => xPL::Validation->new(type => 'IntegerRange',
                                       min => 5, max => 30),
    default => 5,
   },
   {
    name => 'port',
    validation => xPL::Validation->new(type => 'IntegerRange',
                                       min => 1024, max => 65535),
    die => 1,
    required => 1,
   },
   {
    name => 'remote_ip',
    validation => xPL::Validation->new(type => 'IP'),
    die => 1,
    required => 1,
   },
  ]
}

=head2 C<default_message_type()>

This method returns the default message type for this xPL message
schema.  It returns 'xpl-stat' since this is the only unique message
type defined by this message schema.

=cut

sub default_message_type {
  my $self = shift;
  return "xpl-stat";
}

=head2 C<interval( [ $new_interval ] )>

This method returns the hbeat interval.  If the optional new value
argument is present, then this method updates the hbeat interval
with the new value before it returns.


=head2 C<port( [ $new_port ] )>

This method returns the hbeat port.  If the optional new value
argument is present, then this method updates the hbeat port
with the new value before it returns.


=head2 C<remote_ip( [ $new_remote_ip ] )>

This method returns the hbeat remote_ip.  If the optional new value
argument is present, then this method updates the hbeat remote_ip
with the new value before it returns.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/XPL_Specification_Document

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
