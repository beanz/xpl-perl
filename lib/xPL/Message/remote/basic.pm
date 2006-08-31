package xPL::Message::remote::basic;

# $Id: basic.pm 152 2006-05-27 10:56:32Z beanz $

=head1 NAME

xPL::Message::remote::basic - Perl extension for remote.basic class xPL messages

=head1 SYNOPSIS

  use xPL::Message;

  my $cmnd = xPL::Message->new(message_type => "xpl-cmnd",
                               class => 'remote', class_type => 'basic',
                               command => 'play');

=head1 DESCRIPTION

This module creates an xPL message with a schema class and type of
'remote.basic'.

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
our $VERSION = qw/$Revision: 152 $/[1];

=head2 C<field_spec()>

This method returns the field specification for the body of this
message type.

=cut

sub field_spec {
  [
   {
    name => 'keys',
    validation =>
      xPL::Validation->new(type => 'Any'),
    required => 1,
   },
   {
    name => 'device',
    validation =>
      xPL::Validation->new(type => 'Any'),
   },
   {
    name => 'zone',
    validation =>
      xPL::Validation->new(type => 'Any'),
   },
  ];
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_).' - '. $self->keys.
    ($self->device ? ' d='.$self->device : '').
    ($self->zone ? ' z='.$self->zone : '');
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_REMOTE.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
