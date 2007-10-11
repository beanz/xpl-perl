package xPL::Gtk2Client;

# $Id$

=head1 NAME

xPL::Gtk2Client - Perl extension for a graphical xPL Client

=head1 SYNOPSIS

  use Gtk2 -init;
  use Gtk2::SimpleList;
  use xPL::Gtk2Client;

  my $xpl = xPL::Gtk2Client->new(vendor_id => 'acme', device_id => 'monitor',
                                 @ARGV);
  $xpl->add_xpl_callback(id => "logger", self_skip => 0, targetted => 0,
                         callback => \&log);
  my %seen;
  my $win = Gtk2::Window->new('toplevel');
  my $vbox = Gtk2::VBox->new(0,0);
  $win->add($vbox);
  my $slist = Gtk2::SimpleList->new('Id' => 'text',
                                    'Last Message' => 'text',
                                    'Last Time' => 'text');
  $vbox->add($slist);
  foreach (['Send Request' => sub { $xpl->send(class=>'hbeat.request') }],
           ['Quit' => sub { Gtk2->main_quit }]) {
    my $button = Gtk2::Button->new($_->[0]);
    $button->signal_connect(clicked => $_->[1]);
    $vbox->add($button);
  }
  $win->show_all;
  Gtk2->main;

  sub log {
    my %p = @_;
    my $msg = $p{message};
    $seen{$msg->source} = [ $msg->summary, scalar localtime(time) ];
    @{$slist->{data}} = map { [$_ => @{$seen{$_}}] } sort keys %seen;
    return 1;
  }

=head1 DESCRIPTION

This module creates a graphical xPL client.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use Gtk2;
use xPL::Client;

require Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Client);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

# Preloaded methods go here.

sub add_timer {
  my $self = shift;
  $self->SUPER::add_timer(@_) or return;
  return $self->_add_timeout();
}

sub add_input {
  my $self = shift;
  my %p = @_;
  $self->SUPER::add_input(@_) or return;
  $self->{_handle_map}->{$p{handle}} =
    Glib::IO->add_watch($p{handle}->fileno, ['G_IO_IN', 'G_IO_HUP'],
                        \&_gtk2_input_wrapper,
                        [$self, $p{handle}] );
  return 1;
}

sub remove_input {
  my $self = shift;
  my $handle = shift;
  $self->SUPER::remove_input($handle) or return;
  my $id = $self->{_handle_map}->{handle};
  return defined $id && Glib::Source->remove($id);
}

sub _gtk2_input_wrapper {
  my ($fileno, $cond, $data) = @_;
  my ($self, $handle) = @$data;
  $self->dispatch_input($handle);
  return 1;
}

sub _add_timeout {
  my $self = shift;
  Glib::Source->remove($self->{_timeout_handle})
      if (defined $self->{_timeout_handle});
  $self->{_timeout_handle} =
    Glib::Timeout->add($self->timer_minimum_timeout()*1000,
                       \&_gtk2_timeout_callback, $self);
  return 1;
}

sub _gtk2_timeout_callback {
  my $self = shift;
  $self->dispatch_timers();
  undef $self->{_timeout_handle};
  $self->_add_timeout();
  return 0;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
