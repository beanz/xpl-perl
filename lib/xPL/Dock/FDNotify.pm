package xPL::Dock::FDNotify;

=head1 NAME

xPL::Dock::FDNotify - xPL::Dock plugin for a desktop notification application

=head1 SYNOPSIS

  use xPL::Dock qw/FDNotify/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds a desktop notification C<osd.basic> client.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use Net::DBus;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  return
    (
     'fdnotify-verbose+' => \$self->{_verbose},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  my $session = Net::DBus->session;
  my $serv = $session->get_service('org.freedesktop.Notifications');
  $self->{_dbus_object} = $serv->get_object('/org/freedesktop/Notifications',
                                            'org.freedesktop.Notifications');

  $xpl->add_xpl_callback(id => 'xpl_handler',
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          schema => 'osd.basic',
                         },
                         callback => sub { $self->xpl_handler(@_) });
  return $self;
}

=head2 C<xpl_handler( %params )>

This method handles and responds to incoming C<remote.basic> messages.

=cut

sub xpl_handler {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};

  unless ($msg->field('text')) {
    return;
  }

  my $delay = $msg->field('delay');
  $delay = defined $delay ? $delay * 1000 : -1;

  # appname, replaces_id, icon, summary, body, actions, hints, delay
  $self->{_dbus_object}->Notify($self->{_xpl}->device_id,
                                0, '', $msg->field('text'), '', [], {}, $delay);
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), xosd(1)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
