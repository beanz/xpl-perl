package xPL::Dock::MPD;

=head1 NAME

xPL::Dock::MPD - xPL::Dock plugin for MPD monitoring

=head1 SYNOPSIS

  use xPL::Dock qw/MPD/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds xPL Music Player Daemon support.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use IO::Socket::INET;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/interval server/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_host} = '127.0.0.1';
  $self->{_port} = '6600';
  return
    (
     'mpd-verbose+' => \$self->{_verbose},
     'mpd-host=s' => \$self->{_host},
     'mpd-port=s' => \$self->{_port},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  $self->{mpd} =
    AnyEvent::MPD->new(host => $self->{_host},
                       port => $self->{_port},
                       on_error => sub { die @_ });

  # Add a callback to receive all incoming xPL messages
  $xpl->add_xpl_callback(id => 'mpd', callback => sub { $self->xpl_in(@_) },
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    schema => 'audio.basic',
                                   });

  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
a limited subset of the full audio.basic schema but could easily be
extended.

=cut

sub xpl_in {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};

  my $mpd = $self->{mpd};
  my $command = $msg->field('command');
  if ($command =~ /^volume\s?([-+]?\d+)/) {
    $mpd->volume($1);
  } elsif ($command eq 'play') {
    my $track = $msg->field('track');
    if (defined $track) {
      $mpd->stop;
      $mpd->playlistclear;
      $mpd->playlistadd($track);
    }
    my $status = $mpd->status;
    my $state = $status->state;
    if ($state eq "play") {
      $mpd->next();
    } else {
      $mpd->play();
    }
    setup_timer_to_check_song_details();
  } elsif ($command eq "skip") {
    $mpd->next();
    setup_timer_to_check_song_details();
  } elsif ($command eq "pause") {
    $mpd->pause();
  } elsif ($command eq "back") {
    $mpd->prev();
    setup_timer_to_check_song_details();
  } elsif ($command =~ /^stop$/) {
    $mpd->stop();
  }
  return 1;
}

sub setup_timer_to_check_song_details {
  my $self = shift;
  my $xpl = $self->xpl;
  $xpl->exists_timer('get_current') or
    $xpl->add_timer(id => 'get_current',
                    timeout => 1,
                    callback => sub {
                      my $current = $mpd->current() or return;
                      $xpl->send(message_type => 'xpl-cmnd',
                                 schema => 'osd.basic',
                                 body =>
                                 [
                                  command => 'clear',
                                  row => 1,
                                  text => $current->title,
                                 ]);
                      $xpl->send(message_type => 'xpl-cmnd',
                                 schema => 'osd.basic',
                                 body =>
                                 [
                                  command => 'write',
                                  row => 2,
                                  text => $current->artist,
                                 ]);
                      return;
                    });
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), AnyEvent::MPD(3)

Project website: http://www.xpl-perl.org.uk/

Music Player Daemon website: http://www.musicpd.org/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
