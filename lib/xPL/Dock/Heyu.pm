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
use POSIX ":sys_wait_h";
use xPL::Queue;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

sub getopts {
  my $self = shift;
  return (
          'heyu-verbose|heyuverbose+' => \$self->{_verbose},
         );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  $self->{_buffer} = q{};
  $self->{_helper_buffer} = q{};
  $self->{_helper_seq} = 0;
  $self->{_waiting} = undef;
  $self->{_q} = xPL::Queue->new();
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

  my $rh = $self->{_helper_rh} = IO::Pipe->new;
  my $wh = $self->{_helper_wh} = IO::Pipe->new;
  my $pid = fork;
  if ($pid) {

    sub sig {
      waitpid(-1,WNOHANG);
    }
    $SIG{CHLD} = \&sig;
    $SIG{PIPE} = \&sig;

    # parent
    $rh->reader();
    $wh->writer();
    $wh->autoflush(1);
    $xpl->add_input(handle => $rh,
                    callback => sub { $self->heyu_helper_read(@_) });
  } elsif (defined $pid) {
    # child
    $rh->writer();
    $rh->autoflush(1);
    $wh->reader();
    my $wfd = $rh->fileno;
    my $rfd = $wh->fileno;
    open(STDIN,"<&$rfd") or die "dup of stdin failed: $!";
    open(STDOUT,">&=$wfd") or die "dup of stdout failed: $!";
    open(STDERR,"+>&$wfd") or die "dup of stderr failed: $!";
    exec('xpl-heyu-helper', @ARGV) or
      $self->argh("Failed to exec xpl-heyu-helper: $!\n");
  } else {
    $self->argh("Fork for xpl-heyu-helper failed: $!\n");
  }
  $self->{_monitor_ready} = 0;
  return $self;
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
      $self->heyu_helper_queue($heyu_command, $data1, $device, $data2);
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
    $self->heyu_helper_queue($heyu_command, $device, @args);
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
    } elsif (m!function\s+(On|Off|Bright|Dim)\s+:\s+housecode\s+(\w+)(.*\s+by\s+%(\d+))?!) {
      my $f = lc($1);
      my $h = lc($2);
      my $level = $4;
      my $u = join ',', sort { $a <=> $b } @{$self->{_unit}->{$h}|| ['0']};
      $self->send_xpl($class, $h.$u, $f, $level);
      delete $self->{_unit}->{$h};
    } elsif (m!function\s+xPreset\s+:\s+housecode\s+(\w)\s+unit\s+(\d+)\s+level\s+(\d+)!) {
      my $f = 'xfunc';
      my $h = lc($1);
      my $u = $2;
      my $level = [ 49, $3 ];
      $self->send_xpl($class, $h.$u, $f, $level);
      delete $self->{_unit}->{$h}; # TODO: should we do this? need to check spec
    } elsif (m!address\s+unit\s+(\S+)\s+:\s+housecode\s+(\w+)!) {
      push @{$self->{_unit}->{lc($2)}}, $1;
    } else {
      print STDERR "monitor reported unsupported line:\n  $_\n";
    }
  }
  return 1;
}


=head2 C<heyu_helper_read()>

This is the callback that processes output from the "heyu helper"
command.  It is responsible for reading the results of heyu commands.

=cut

sub heyu_helper_read {
  my $self = shift;
  my $bytes = $self->{_helper_rh}->sysread($self->{_helper_buffer}, 512,
                                           length $self->{_helper_buffer});
  while ($self->{_helper_buffer} =~ s/^(.*?)\n//) {
    $_ = $LAST_PAREN_MATCH;
    my ($recvseq, $rc, $err) = split /\000/, $_, 3;
    unless ($recvseq =~ /^[0-9a-f]{8}$/) {
      print STDERR "Helper wrote: $_\n";
      next;
    }
    if ($recvseq eq $self->{_waiting} && $rc == 0) {
      print STDERR "Acknowledged ".$self->{_waiting}."\n";
    } else {
      print STDERR "Received $recvseq: $rc ", $err||"", "\n";
    }
    undef $self->{_waiting};
    $self->heyu_helper_write();
  }
  return 1;
}

=head2 C<heyu_helper_queue()>

This method is used to queue commands to the heyu helper.

=cut

sub heyu_helper_queue {
  my $self = shift;
  my $seq_str = sprintf "%08x", $self->{_helper_seq}++;
  my $msg = join chr(0), $seq_str, @_;
  $msg .= "\n";
  $self->{_q}->enqueue([$seq_str, $msg]);
  $msg =~ s/\0/ /g;
  print STDERR "queued: $msg" if ($self->verbose);
  return $self->heyu_helper_write() if (!defined $self->{_waiting});
  return $seq_str;
}

=head2 C<heyu_helper_write()>

This method is used to send commands to the heyu helper.

=cut

sub heyu_helper_write {
  my $self = shift;
  my $item = $self->{_q}->dequeue;
  return unless (defined $item);
  my ($seq_str, $msg) = @$item;
  $self->{_helper_wh}->syswrite($msg);
  $msg =~ s/\0/ /g;
  print STDERR "sent: $msg" if ($self->verbose);
  $self->{_waiting} = $seq_str;
  return $seq_str;
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
  if ($self->verbose) {
    print STDERR
      "Sending $class $device $command", ($level ? " ".$level : ""), "\n";
  }

  $self->xpl->send(%args);
}

# convert level from 0-100 range for xPL to 0-22 range for heyu
sub level_xpl_to_heyu {
  int $_[0]*22/100
}

# convert level from 0-22 range for heyu to 0-100 range for xPL
sub level_heyu_to_xpl {
  int $_[0]*100/22
}

sub house_xpl_to_heyu {
  my $house = shift;
  my $result = shift;
  foreach (split//,$house) {
    push @{$result},$_.'1';
  }
  return $result;
}

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

sub device_heyu_to_xpl {
  my $dev = shift;
  my $house = substr($dev,0,1,q{});
  return $house.(join ",".$house, split/,/,$dev);
}

# data1=0x31 data2=0x00-0x3f - dim on/off to specific level
# data2 & 0x40 = at 30 second rate
#       & 0x80 = at 1 minute rate
#       & 0xc0 = at 5 minute rate
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
