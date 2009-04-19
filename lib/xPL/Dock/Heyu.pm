package xPL::Dock::Heyu;

=head1 NAME

xPL::Dock::Heyu - xPL::Dock plugin for X10 using heyu

=head1 SYNOPSIS

  use xPL::Dock qw/Heyu/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds X10 support using heyu.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use FileHandle;
use IO::Pipe;
use IPC::Open3;
use POSIX ":sys_wait_h";
use xPL::IOHandler;
use xPL::Dock::Plug;

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
  return (
          'heyu-verbose+' => \$self->{_verbose},
         );
}

=head2 C<sig( )>

Simple signal handler to wait on child processes.

=cut

sub sig {
  waitpid(-1,WNOHANG);
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  $self->{_buffer} = q{};
  $self->{_helper_seq} = 0;
  $self->{_unit} = {};

  # Add a callback to receive all incoming xPL messages
  $xpl->add_xpl_callback(id => 'x10', callback => sub { $self->xpl_in(@_) },
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    class => 'x10',
                                    class_type => 'basic',
                                   });

  my $fh = $self->{_monitor_fh} =
    IO::Pipe->reader(qw/heyu monitor/) or
        $self->argh("'heyu monitor|' failed: $! $@\n");
  $xpl->add_input(handle => $fh, callback => sub { $self->heyu_monitor(@_) });

  my ($rh, $wh);
  my $pid = open3($wh, $rh, undef, 'xpl-heyu-helper', @ARGV);
  $SIG{CHLD} = \&sig;
  $SIG{PIPE} = \&sig;
  $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        input_handle => $rh, output_handle => $wh,
                        reader_callback => sub { $self->read_helper(@_) },
                        input_record_type => 'xPL::IORecord::ZeroSplitLine',
                        output_record_type => 'xPL::IORecord::ZeroSplitLine',
                        @_);
  $self->{_monitor_ready} = 0;
  return $self;
}

sub seq {
  sprintf "%08x", $_[0]->{_helper_seq}++
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
a limited subset of the full x10.basic schema but could easily be
extended.

=cut

sub xpl_in {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};

  my $heyu_command = command_xpl_to_heyu($msg->command);
  return 1 unless ($heyu_command);

  my @devices;
  my $data1;
  my $data2;
  if ($msg->device) {
    device_xpl_to_heyu($msg->device, \@devices);
  }
  if ($msg->house) {
    house_xpl_to_heyu($msg->house, \@devices);
  }
  my @args = ();
  if ($heyu_command =~ /^bright|dim$/ && $msg->level) {
    push @args, level_xpl_to_heyu($msg->level);
  }
  if ($heyu_command eq 'xfunc') {
    $data1 = $msg->data1;
    $data2 = $msg->data2;
    return 1 unless (defined $data1 && defined $data2);
    $data1 = sprintf '%02x', $data1;
    $data2 = sprintf '%02x', $data2;
    foreach my $device (@devices) {
      $self->{_io}->write(fields =>
                          [$self->seq, $heyu_command, $data1, $device, $data2]);
      my %args = (
                  message_type => 'xpl-trig',
                  class => 'x10.confirm',
                  body => { command => $msg->command,
                            device => device_heyu_to_xpl($device),
                            data1 => $msg->data1, data2 => $msg->data2 },
                 );
      $self->xpl->send(%args);
    }
    return 1;
  }

  foreach my $device (@devices) {
    $self->{_io}->write(fields => [$self->seq, $heyu_command, $device, @args]);
  }
  return 1;
}

=head2 C<heyu_monitor()>

This is the callback that processes output from the "heyu monitor"
command.  It is responsible for sending out x10.basic xpl-trig
messages.

=cut

sub heyu_monitor {
  my $self = shift;
  my $bytes = $self->{_monitor_fh}->sysread($self->{_buffer}, 512,
                                            length($self->{_buffer}));
  while ($self->{_buffer} =~ s/^(.*?)\n//) {
    $_ = $LAST_PAREN_MATCH;
    my $class = 'x10.basic';
    $class = 'x10.confirm' if (/sndc/);
    # TOFIX: process timestamps
    if (m!Monitor started!) {
      $self->{_monitor_ready} = 1;
    } elsif (m!function\s+(On|Off|Bright|Dim)\s+:\s+housecode\s+(\w+)(.*\s+by\s+%(\d+))?! ||
             m!func\s+(On|Off|Bright|Dim)\s+:\s+hc\s+(\w+)(.*\s+%(\d+))?!) {
      my $f = lc($1);
      my $h = lc($2);
      my $level = $4;
      my $u = join ',', sort { $a <=> $b } @{$self->{_unit}->{$h}|| ['0']};
      $self->send_xpl($class, $h.$u, $f, $level);
      delete $self->{_unit}->{$h};
    } elsif (m!function\s+xPreset\s+:\s+housecode\s+(\w)\s+unit\s+(\d+)\s+level\s+(\d+)! ||
             m!func\s+xPreset\s+:\s+hu\s+(\w)(\d+)\s+level\s+(\d+)!) {
      my $f = 'xfunc';
      my $h = lc($1);
      my $u = $2;
      my $level = [ 49, $3 ];
      $self->send_xpl($class, $h.$u, $f, $level);
      delete $self->{_unit}->{$h}; # TODO: should we do this? need to check spec
    } elsif (m!address\s+unit\s+(\S+)\s+:\s+housecode\s+(\w+)!) {
      push @{$self->{_unit}->{lc($2)}}, $1;
    } elsif (m!addr\s+unit\s+\S+\s+:\s+hu\s+([a-pA-P])(\d+)!) {
      push @{$self->{_unit}->{lc($1)}}, $2;
    } else {
      print STDERR "monitor reported unsupported line:\n  $_\n";
    }
  }
  return 1;
}

=head2 C<read_helper()>

This is the callback that processes output from the "heyu helper"
command.  It is responsible for reading the results of heyu commands.

=cut

sub read_helper {
  my ($self, $handler, $msg, $waiting) = @_;
  my ($recvseq, $rc, $err) = @{$msg->fields};
  unless ($recvseq =~ /^[0-9a-f]{8}$/) {
    print STDERR "Helper wrote: $_\n";
    return 1;
  }
  if ($waiting && $recvseq eq $waiting->fields->[0] && $rc == 0) {
    print STDERR "Acknowledged ".$waiting."\n";
  } else {
    print STDERR "Received $recvseq: $rc ", $err||"", "\n";
  }
  return 1;
}

=head2 C<send_xpl( $class, $device, $command, [ $level ] )>

This functions is used to send out x10.basic xpl-trig messages as a
result of messages from "heyu monitor".

=cut

sub send_xpl {
  my $self = shift;
  my $class = shift;
  my $device = shift;
  my $command = shift;
  my $level = shift;
  my $xpl_command = command_heyu_to_xpl($command);
  return unless ($xpl_command);
  my %args =
    (
     message_type => 'xpl-trig',
     class => $class,
     body => {
              command => $xpl_command,
              device => device_heyu_to_xpl($device),
             },
    );
  if (ref $level) {
    $args{body}->{data1} = $level->[0];
    $args{body}->{data2} = $level->[1];
    $level = sprintf "data1=%d data2=%d", @$level;
  } elsif ($level) {
    $args{body}->{level} = level_heyu_to_xpl($level);
  }
  $self->debug("Sending $class $device $command",
               ($level ? " ".$level : ""), "\n");
  $self->xpl->send(%args);
}

=head2 C<level_xpl_to_heyu( $level )>

Function to convert level from 0-100 range for xPL to 0-22 range for
heyu.

=cut

sub level_xpl_to_heyu {
  int $_[0]*22/100
}

=head2 C<level_heyu_to_xpl( $level )>

Function to convert level from 0-22 range for heyu to 0-100 range for
xPL.

=cut

sub level_heyu_to_xpl {
  int $_[0]*100/22
}

=head2 C<house_xpl_to_heyu( $house )>

Function to convert a house code list from xPL format to heyu format.

=cut

sub house_xpl_to_heyu {
  my $house = shift;
  my $result = shift;
  foreach (split//,$house) {
    push @{$result},$_.'1';
  }
  return $result;
}

=head2 C<device_xpl_to_heyu( $device )>

Function to convert a device list from xPL format to heyu format.

=cut

sub device_xpl_to_heyu {
  my $device = shift;
  my $result = shift;
  my %h = ();
  foreach (split/,/, $device) {
    my ($h,$u) = split//,$_, 2;
    push@{$h{$h}},$u;
  }
  foreach (keys %h) {
    push @$result, $_.(join",",sort { $a <=> $b } @{$h{$_}})
  }
  return $result;
}

=head2 C<device_heyu_to_xpl( $device )>

Function to convert a device list from heyu format to xPL format.

=cut

sub device_heyu_to_xpl {
  my $dev = shift;
  my $house = substr($dev,0,1,q{});
  return $house.(join ",".$house, split/,/,$dev);
}

=head2 C<command_xpl_to_heyu( $device )>

Function to convert a command from xPL format to heyu format.

=cut

sub command_xpl_to_heyu {
  my $command = shift;
  return {
          all_units_off => "alloff", all_units_on => "allon",
          all_lights_off => "lightsoff",  all_lights_on => "lightson",
          on => "on", off => "off",
          dim => "dim", bright => "bright",
          extended => "xfunc",
         }->{$command};
}

=head2 C<command_heyu_to_xpl( $device )>

Function to convert a command from heyu format to xPL format.

=cut

sub command_heyu_to_xpl {
  my $command = shift;
  return {
          alloff => "all_units_off", allon => "all_units_on",
          lightsoff=> "all_lights_off",  lightson => "all_lights_on",
          on => "on", off => "off",
          dim => "dim", bright => "bright",
          xfunc => 'extended',
         }->{$command};
}

# xPreset info:
# data1=0x31 data2=0x00-0x3f - dim on/off to specific level
# data2 & 0x40 = at 30 second rate
#       & 0x80 = at 1 minute rate
#       & 0xc0 = at 5 minute rate

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), heyu(1)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
