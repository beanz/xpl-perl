package xPL::Dock::DMX;

=head1 NAME

xPL::Dock::DMX - xPL::Dock plugin for a DMX Transmitter application

=head1 SYNOPSIS

  use xPL::Dock qw/DMX/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL client for a serial port-based device.  There
are several usage examples provided by the xPL Perl distribution.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use FileHandle;
use List::Util qw/min max/;
use Time::HiRes;
use xPL::IOHandler;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_baud} = 9600;
  $self->{_rgb_txt} = '/etc/X11/rgb.txt';
  return (
          'dmx-verbose+' => \$self->{_verbose},
          'dmx-baud=i' => \$self->{_baud},
          'dmx-tty=s' => \$self->{_device},
          'rgb=s' => \$self->{_rgb_txt},
         );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->required_field($xpl,
                        'device', 'The --dmx-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  my $io = $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_device},
                        baud => $self->{_baud},
                        reader_callback => sub { $self->device_reader(@_) },
                        input_record_type => 'xPL::IORecord::Hex',
                        output_record_type => 'xPL::IORecord::Hex',
                        @_);

  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'dmx', callback => \&xpl_in,
                         arguments => $self,
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          class => 'dmx',
                          class_type => 'basic',
                          type => 'set',
                         });
  $self->read_rgb_txt();
  $self->{_values} = [];
  $self->{_fades} = {};
  $self->{_min_visible_diff} = 4;
  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming x10.basic schema messages.

=cut

sub xpl_in {
  my %p = @_;
  my $msg = $p{message};
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};
  my $self = $p{arguments};
  my $xpl = $self->xpl;

  if ($msg->field('base') =~ /hex/) { # hack to aid debug
    $self->{_io}->write(hex => $msg->field('value'), data => $msg,
                        desc => 'debug message');
    return 1;
  }
  return 1 unless ($msg->field('base') =~ /^(\d+)(x(\d+))?$/);
  my $base = $1;
  my $multi = $3 || 1;
  my $hex;
  if ($msg->field('value') =~ /^0x([0-9a-f]+)/i) {
    $hex = $1;
  } elsif (my @l = ($msg->field('value')=~/\G[ ,]?(\d+)/mg)) {
    $hex = sprintf "%02x" x scalar @l, @l;
  } elsif (exists $self->{_rgb}->{lc $msg->field('value')}) {
    $hex = $self->{_rgb}->{lc $msg->field('value')};
  } else {
    return 1;
  }
  my $fade = $msg->field('fade');
  if (defined $fade) {
    return $self->dmx_fade($msg, $base, $hex, $multi, $fade);
  }
  return $self->dmx_set($msg, $base, $hex, $multi);
}

=head2 C<dmx_set($base, $hex, $multiplier, $msg)>

This function sends a set command for the given base address with the
hex value repeated according to the multiplier.

=cut

sub dmx_set {
  my ($self, $msg, $base, $hex, $multi) = @_;
  my $xpl = $self->xpl;
  my $values = $self->{_values};
  $multi = 1 unless (defined $multi);
  my @v = unpack "C*", pack "H*", $hex;
  my $l = scalar @v;
  for (my $i = 0; $i<($l*$multi); $i++) {
    $values->[$base+$i] = $v[$i%$l];
  }
  my $comm = '01'.(sprintf "%04x", $base).($hex x $multi);
  $self->{_io}->write(hex => $comm, data => $msg,
                      desc => "set ${base}x$multi=$hex");
  return 1;
}

=head2 C<dmx_fade($msg, $base, $hex, $multiplier, $fade)>

This function sends a set command for the given base address with the
hex value repeated according to the multiplier over the period given
by the fade parameter.

=cut

sub dmx_fade {
  my ($self, $msg, $base, $hex, $multi, $fade) = @_;
  my $values = $self->{_values};
  my $fades = $self->{_fades};
  my $start_t = Time::HiRes::time();
  my $end_t = $start_t + $fade;
  my @v = unpack "C*", pack "H*", $hex;
#  print "base=$base\n";
  my $l = scalar @v;
  for (my $i = 0; $i<($l*$multi); $i++) {
    my $b = $base+$i;
    my $start = $values->[$b] || 0; # assume black?
    my $end = $v[$i%$l];
    next if ($start == $end); # nothing to do
    $fades->{$b} =
      {
       start_c => $start,
       end_c => $end,
       diff_c => $end - $start,
       start_t => $start_t,
       end_t => $end_t,
       diff_t => $end_t - $start_t,
      };
    $fades->{$b}->{int_t} =
      $fades->{$b}->{diff_t} / (abs($fades->{$b}->{diff_c}) /
                             $self->{_min_visible_diff});
    $fades->{$b}->{next_t} = _next_change($fades->{$b}, $start_t);
#    print "nc = ", $fade->{$b}->{next_t}, "\n";
  }
  $self->send_xpl_confirm($msg);
  return $self->update_fade_timer();
}

=head2 C<update_fade_timer()>

This method sets up the timer to trigger when the next fade change is
due.

=cut

sub update_fade_timer {
  my $self = shift;
  my $xpl = $self->xpl;
  $xpl->remove_timer('fade') if ($xpl->exists_timer('fade'));
  my $fades = $self->{_fades};
  return unless (scalar keys %$fades);
  my $min = min(map { $fades->{$_}->{next_t} } keys %$fades);
  $xpl->add_timer(id => 'fade',
                  timeout => $min - Time::HiRes::time(),
                  callback => sub { $self->do_fades(@_) });
  return 1;
}

=head2 C<do_fades()>

This method is the fade timer callback that is triggered when a change
is due.  It makes any changes and then resets the timer by calling
L<update_fade_timer()>.

=cut

sub do_fades {
  my $self = shift;
  my $time = Time::HiRes::time;
  my $fades = $self->{_fades};
  my %set = ();
  foreach my $base (sort { $a <=> $b } keys %$fades) {
    next unless ($fades->{$base}->{next_t} <= $time);
    my $diff_c = $fades->{$base}->{diff_c};
    my $diff_t = $fades->{$base}->{diff_t};
    my $off_t = $fades->{$base}->{next_t} - $fades->{$base}->{start_t};
    my $off_c = $diff_c * $off_t / $diff_t;
    my $col = int(.5 + $fades->{$base}->{start_c} + $off_c);
    $col = min($col, 255);
    $col = max($col, 0);
#    print "$diff_t $diff_c $off_t $off_c $col\n";
    if (exists $set{$base-1}) {
      $set{$base-1} .= sprintf "%02x", $col;
    } else {
      $set{$base} = sprintf "%02x", $col;
    }
    if ($col == $fades->{$base}->{end_c}) {
      delete $fades->{$base};
      next;
    }
    $fades->{$base}->{next_t} =
      _next_change($fades->{$base}, $fades->{$base}->{next_t}) or
        delete $fades->{$base};
  }
  # TODO: optimize set commands
  foreach my $base (keys %set) {
    $self->dmx_set(undef, $base, $set{$base});
#    print "S: $base = ", $set{$base}, "\n";
  }
  $self->update_fade_timer();
  return 1;
}

sub _next_change {
  my $f = shift;
  my $t = shift;
  return undef unless ($t >= $f->{start_t} && $t < $f->{end_t});
  my $nt = $t + $f->{int_t};
  return $nt > $f->{end_t} ? $f->{end_t} : $nt;
}

=head2 C<device_reader()>

This is the callback that processes output from the DMX transmitter.

=cut

sub device_reader {
  my ($self, $handler, $msg, $last) = @_;
  print 'received: ', $msg, "\n";
  $self->send_xpl_confirm($last->data) if (ref $last && ref $last->data);
  return 1;
}

=head2 C<send_xpl_confirm()>

This helper method sends a C<dmx.confirm> message corresponding to the
provided C<dmx.basic> message.

=cut

sub send_xpl_confirm {
  my $self = shift;
  my $msg = shift;
  my $xpl = $self->xpl;
  $xpl->send(message_type => 'xpl-trig',
             class => 'dmx.confirm',
             body =>
             [
              base => $msg->field('base'),
              type => $msg->field('type'),
              value => $msg->field('value'),
             ]);
}

=head2 C<read_rgb_txt( $file )>

This function reads the rgb.txt file to create a mapping of colour names
to rrggbb hex values.

=cut

sub read_rgb_txt {
  my $self = shift;
  my $file = $self->{_rgb_txt};
  my %rgb;
  my $rgb = FileHandle->new($file) or return $self->default_rgb();
  while (<$rgb>) {
    next unless (/^(\d+)\s+(\d+)\s+(\d+)\s+(.*)\s*$/);
    $rgb{lc $4} = sprintf "%02x%02x%02x", $1, $2, $3;
  }
  $rgb->close;
  return $self->{_rgb} = \%rgb;
}

=head2 C<default_rgb( )>

This function returns a default mapping of colour names to rrggbb hex
values.  It is used if an C<rgb.txt> file is not found.

=cut

sub default_rgb {
  return $_[0]->{_rgb} =
    {
     black   => '000000',
     red     => 'ff0000',
     green   => '00ff00',
     blue    => '0000ff',
     magenta => 'ff00ff',
     cyan    => '00ffff',
     yellow  => 'ffff00',
     white   => 'ffffff',
    };
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
