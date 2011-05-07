package xPL::Dock::Mythtv;

=head1 NAME

xPL::Dock::Mythtv - xPL::Dock plugin for Mythtv monitoring

=head1 SYNOPSIS

  use xPL::Dock qw/Mythtv/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds Mythtv monitoring.

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
  $self->{_interval} = 120;
  $self->{_server} = '127.0.0.1:6544';
  return
    (
     'mythtv-verbose+' => \$self->{_verbose},
     'mythtv-poll-interval=i' => \$self->{_interval},
     'mythtv-server=s' => \$self->{_server},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  $xpl->add_timer(id => 'mythtv',
                  timeout => -$self->interval,
                  callback => sub { $self->poll(); 1 });

  $self->{_buf} = '';
  $self->{_state} = {};

  return $self;
}

=head2 C<poll( )>

This method is the timer callback that polls the mythtv daemon.

=cut

sub poll {
  my $self = shift;
  my $sock = IO::Socket::INET->new($self->server);
  unless ($sock) {
    warn "Failed to contact mythtv daemon at ", $self->server, ": $!\n";
    return 1;
  }
  print $sock "GET / HTTP/1.0\r\n\r\n";
  $self->xpl->add_input(handle => $sock,
                        callback => sub { $self->read(@_); 1; });
  return 1;
}

=head2 C<read( )>

This is the input callback that reads the data from the mythtv daemon
and sends appropriate C<sensor.basic> messages and C<ups.basic>
messages.

=cut

sub read {
  my ($self, $sock) = @_;
  my $bytes = $sock->sysread($self->{_buf}, 1024, length($self->{_buf}));
  unless ($bytes) {
    $self->{_buf} = '';
    $self->xpl->remove_input($sock);
    $sock->close;
  }
  if ($self->{_buf} =~ m!<div \s+ class="content"> \s*
                         <h2>Encoder \s+ Status</h2> \s*
                         (Encoder.*?)</div>!imxs) {
    my $c = $1;
    my $count = 0;
    my $used = 0;
    foreach my $s ($c =~
                   /(Encoder \d+ (?:\[.*?\] )?is \w+ on \S+ and is \w+)/img) {
      my ($state) =
        ($s =~ /Encoder \d+ (?:\[.*?\] )?is \w+ on \S+ and is (\w+)/i);
      #print STDERR $count, " ", $state, "\n";
      $count++;
      $used++ if ($state ne "not");
    }
    my $usage = $count ? int(10000*$used/$count)/100 : 0;

    $self->{_buf} = '';
    $self->xpl->remove_input($sock);
    $sock->close;

    $self->xpl->send_sensor_basic($self->xpl->instance_id.'-myth',
                                  'generic',
                                  $usage,
                                  'percent');
  }
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3)

Project website: http://www.xpl-perl.org.uk/

MythTV website: http://www.mythtv.org/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
