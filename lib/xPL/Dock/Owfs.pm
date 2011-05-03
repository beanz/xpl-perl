package xPL::Dock::Owfs;

=head1 NAME

xPL::Dock::Owfs - xPL::Dock plugin for 1-wire support using owfs

=head1 SYNOPSIS

  use xPL::Dock qw/Owfs/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds 1-wire support using owfs.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use Time::HiRes qw/sleep/;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/mount/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_mount} = undef;
  return (
          'owfs-verbose+' => \$self->{_verbose},
          'owfs-mount=s' => \$self->{_mount},
         );
}

=head2 C<init(%params)>

This method initializes the plugin.  It configures the xPL callback to
handle incoming C<control.basic> messages for 1-wire relays and the timers
for reading 1-wire temperature, humidity and counter devices.

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->required_field($xpl, 'mount',
                        'The --owfs-mount parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  $self->{_state} = {};

  # Add a callback to receive all incoming xPL messages
  $xpl->add_xpl_callback(id => 'owfs', callback => sub { $self->xpl_in(@_) },
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    schema => 'control.basic',
                                    type => 'output',
                                   });

  # sanity check the inputs immediately and periodically so we keep
  # the current state sane even when owfs is unplugged, etc.
  $xpl->add_timer(id => 'owfs-read', timeout => -120,
                  callback => sub { $self->owfs_reader(@_); 1; });

  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming control.basic schema messages.

=cut

sub xpl_in {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};

  my $device = uc $msg->field('device');
  my $current = lc $msg->field('current');
  unless ($device =~ /^[0-9A-F]{2}\.[0-9A-F]+$/) {
    return 1;
  }
  if ($current eq 'high') {
    $self->owfs_write($device.'/PIO', 1);
  } elsif ($current eq 'low') {
    $self->owfs_write($device.'/PIO', 0);
  } elsif ($current eq 'pulse') {
    $self->owfs_write($device.'/PIO', 1);
    sleep(0.15); # TOFIX
    $self->owfs_write($device.'/PIO', 0);
  } else {
    warn "Unsupported setting: $current\n";
  }
  return 1;
}

=head2 C<owfs_write( $file, $value )>

This function writes the given value to the named file in the 1-wire
file system.

=cut

sub owfs_write {
  my ($self, $file, $value) = @_;
  open my $fh, '>', $self->{_mount}.'/'.$file or do {
    warn "Failed to write ow file, $file: $!\n";
    return;
  };
  $self->debug("Writing $value to $file\n");
  $fh->print($value);
  $fh->flush();
  close $fh;
  return;
}

=head2 C<owfs_reader()>

This is the callback that processes output from the OWFS.  It is
responsible for sending out the sensor.basic xpl-trig messages.

=cut

sub owfs_reader {
  my $self = shift;
  my $ow_dir = $self->{_mount};
  my $devices = find_ow_devices($ow_dir);
  my $found;
  foreach my $dev (@$devices) {
    foreach my $rec ([ "temperature", "temp" ],
                     [ 'humidity', 'humidity' ],
                     [ 'HIH4000/humidity', 'humidity', 1 ],
                     [ 'HTM1735/humidity', 'humidity', 2 ],
                     [ 'counters.A', 'count', 0 ],
                     [ 'counters.B', 'count', 1 ],
                     [ 'current', 'current' ]) {
      my ($filebase, $type, $index) = @$rec;
      my $file = $dev.'/'.$filebase;
      next unless (-f $file);
      my $value = read_ow_file($file);
      next unless (defined $value);
      $found++;
      my $id = $dev;
      $id =~ s!.*/!!;
      $self->xpl->send_sensor_basic((defined $index ? $id.'.'.$index : $id),
                                    $type, $value);
    }
  }

  unless ($found) {
    warn "No devices found?\n";
    return 1;
  }

  foreach (8, 16) {
    my $errors = read_ow_file($ow_dir.'/statistics/errors/CRC'.$_.'_errors');
    my $tries = read_ow_file($ow_dir.'/statistics/errors/CRC'.$_.'_tries');
    printf "CRC%d error rate %6.2f\n", $_, $tries ? $errors*100/$tries : 0;
  }
  foreach my $type (qw/read write/) {
    my $dir = $ow_dir.'/statistics/'.$type;
    my $calls = read_ow_file($dir.'/calls');
    if ($calls == 0) {
      printf "1st try %s success %6.2f\n", $type, 100;
      printf "2nd try %s success %6.2f\n", $type, 0;
      printf "3rd try %s success %6.2f\n", $type, 0;
      printf "        %s failure %6.2f\n", $type, 0;
    } else {
      my $success = read_ow_file($dir.'/success');
      my $cache = $type eq 'read' ? read_ow_file($dir.'/cachesuccess') : 0;
      my $failure = $calls-($success+$cache);
      my @tries = map { read_ow_file($dir.'/tries.'.$_) } (0 .. 2);
      printf "1st try %s success %6.2f\n",
        $type, 100*($tries[0]-$tries[1])/$calls;
      printf "2nd try %s success %6.2f\n",
        $type, 100*($tries[1]-$tries[2])/$calls;
      printf "3rd try %s success %6.2f\n",
        $type, 100*($tries[2]-$failure)/$calls; # broken for read
      printf "        %s failure %6.2f\n",
        $type, 100*$failure/$calls;
    }
  }
  return 1;
}

=head2 C<find_ow_devices( $ow_dir )>

This functions is used to find all devices present in the one-wire
file system.  It returns a list reference of paths to device
directories.

=cut

sub find_ow_devices {
  my $ow_dir = shift;
  my $res = shift || [];
  opendir my $dh, $ow_dir or do {
    warn "Failed to open ow dir, $ow_dir: $!\n";
    return $res;
  };
  foreach my $dev (readdir $dh) {
    if ($dev =~ /^[0-9a-f]{2}\.[0-9a-f]{12}$/i) {
      push @$res, $ow_dir.'/'.$dev;
      foreach my $sub (qw/main aux/) {
        my $new_dir = $ow_dir.'/'.$dev.'/'.$sub;
        find_ow_devices($new_dir, $res) if (-d $new_dir);
      }
    }
  }
  closedir $dh;
  return $res;
}

=head2 C<read_ow_file( $file )>

This function returns the contents of a owfs file or undef on failure.

=cut

sub read_ow_file {
  my $file = shift;
  open my $fh, '<', $file or do {
    warn "Failed to read ow file, $file: $!\n";
    return;
  };
  my $value = <$fh>;
  close $fh;
  chomp($value);
  $value =~ s/\s+$//;
  $value =~ s/^\s+//;
  return $value;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Client(3), xPL::Listener(3)

Project website: http://www.xpl-perl.org.uk/

OWFS website: http://owfs.sourceforge.net/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
