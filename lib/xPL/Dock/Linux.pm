package xPL::Dock::Linux;

=head1 NAME

xPL::Dock::Linux - xPL::Dock plugin for linux system health monitoring

=head1 SYNOPSIS

  use xPL::Dock qw/Linux/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds linux system health monitoring.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];
our $FILE_PREFIX = '';

__PACKAGE__->make_readonly_accessor($_) foreach (qw/interval/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_interval} = 60;
  return
    (
     'linux-verbose+' => \$self->{_verbose},
     'linux-poll-interval=i' => \$self->{_interval},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  # Add a timer to the xPL Client event loop to generate the
  # "sensor.basic" messages.  The negative interval causes the timer to
  # trigger immediately rather than waiting for the first interval.
  $xpl->add_timer(id => 'linux!'.$self,
                  timeout => -$self->interval,
                  callback => sub { $self->poll(); 1 });

  $self->{_buf} = '';
  $self->{_state} = {};

  return $self;
}

=head2 C<poll( )>

This method is the timer callback that polls the linux system.

=cut

sub poll {
  my $self = shift;
  my $xpl = $self->xpl;
  my $p = '/sys/class/thermal';
  foreach my $zone (@{dir_entries($p)}) {
    my $f = $p.'/'.$zone.'/temp';
    next unless (-f $f);
    my $temp = read_line($f);
    next unless (defined $temp && $temp !~ /\D/);
    $temp /= 1000;
    $zone =~ s/thermal_//;
    my $device = $self->xpl->instance_id."-".$zone;
    $self->xpl->send_sensor_basic($device, 'temp', $temp);
  }

  $p = '/sys/class/power_supply';
  foreach my $dev (@{dir_entries($p)}) {
    my $f;
    if (is_file($f = $p.'/'.$dev.'/charge_full') ||
        is_file($f = $p.'/'.$dev.'/energy_full')) {
      my $full = read_line($f);
      next unless (defined $full && $full !~ /\D/);
      $f =~ s/_full$/_now/;
      my $now = read_line($f);
      next unless (defined $now && $now !~ /\D/);
      my $bat = sprintf "%.2f", $now*100/$full;
      my $device = $xpl->instance_id."-".(lc $dev);
      $self->xpl->send_sensor_basic($device, 'battery', $bat, '%');
    } elsif (is_file($f = $p.'/'.$dev.'/online')) {
      my $online = read_line($f);
      next unless (defined $online);
      my $state = $online ? 'mains' : 'battery';
      my $device = $xpl->instance_id."-".(lc $dev);
      my $old = $self->{_state}->{$device.'-power'};
      $self->{_state}->{$device.'-power'} = $state;
      if (!defined $old || $state ne $old) {
        $self->info("$device $state ($online)\n");
        if (defined $old) {
          $xpl->send(message_type => 'xpl-trig',
                     schema => 'ups.basic',
                     body => [
                              status => $state,
                              event => 'on'.$state,
                             ]
                    );
        }
      }
    }
  }
  return 1;
}

=head2 C<dir_entries( $path )>

Returns a list reference of directory entries or an empty list reference.

=cut

sub dir_entries {
  opendir my $dh, $FILE_PREFIX.$_[0] or return [];
  my @e = sort readdir $dh;
  closedir $dh;
  return \@e;
}

=head2 C<read_line( $file )>

Reads a value from a file.

=cut

sub read_line {
  my ($file) = @_;
  open my $fh, '<', $FILE_PREFIX.$file or return;
  my $v = <$fh>;
  close $fh;
  chomp $v;
  return $v;
}

=head2 C<is_file( $file )>

Returns true if the named path represents a file.

=cut

sub is_file {
  my ($file) = @_;
  return -f $FILE_PREFIX.$file;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
