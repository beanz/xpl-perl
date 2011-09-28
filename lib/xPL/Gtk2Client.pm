package xPL::Gtk2Client;

=head1 NAME

xPL::Gtk2Client - Perl extension for a graphical xPL Client

=head1 SYNOPSIS

  use Gtk2 -init;
  use Gtk2::SimpleList;
  use xPL::Gtk2Client;

  my $xpl = xPL::Gtk2Client->new(vendor_id => 'acme', device_id => 'monitor',
                                 @ARGV);
  $xpl->add_xpl_callback(id => "logger", self_skip => 0, targeted => 0,
                         callback => \&log);
  my %seen;
  my $win = Gtk2::Window->new('toplevel');
  my $vbox = Gtk2::VBox->new(0,0);
  $win->add($vbox);
  my $slist = Gtk2::SimpleList->new('Id' => 'text',
                                    'Last Message' => 'text',
                                    'Last Time' => 'text');
  $vbox->add($slist);
  foreach (['Send Request' => sub { $xpl->send(schema=>'hbeat.request') }],
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

if (defined $AnyEvent::VERBOSE) {
  # using AnyEvent so xPL::Listener should work without changes
} else {
  # not using AnyEvent so we need to override some methods to make
  # xPL::Listener's own event loop work
  no strict qw/refs/; ## no critic
  *{__PACKAGE__."::add_timer"} = *{__PACKAGE__."::_gtk2_add_timer"};
  *{__PACKAGE__."::add_input"} = *{__PACKAGE__."::_gtk2_add_input"};
  *{__PACKAGE__."::remove_input"} = *{__PACKAGE__."::_gtk2_remove_input"};
  use strict qw/refs/;
}

=head2 C<_gtk2_add_timer(...)>

Wrap L<xPL::Client::add_timer> method to add timer to Gtk2 main loop.
This should not be called directly but is used when L<AnyEvent> is not
being used by L<xPL::Listener>.

=cut

sub _gtk2_add_timer {
  my $self = shift;
  $self->SUPER::add_timer(@_);
  return $self->_add_timeout();
}

=head2 C<add_input_gtk2(...)>

Wrap L<xPL::Client::add_input> method to add input to Gtk2 main loop.
This should not be called directly but is used when AnyEvent is not
being used by L<xPL::Listener>.

=cut

sub _gtk2_add_input {
  my $self = shift;
  my %p = @_;
  $self->SUPER::add_input(@_);
  $self->{_handle_map}->{$p{handle}} =
    Glib::IO->add_watch($p{handle}->fileno, ['G_IO_IN', 'G_IO_HUP'],
                        \&_gtk2_input_wrapper,
                        [$self, $p{handle}] );
  return 1;
}

=head2 C<_gtk2_remove_input(...)>

Wrap L<xPL::Client::remove_input> method to remove input from Gtk2 main loop.
This should not be called directly but is used when AnyEvent is not
being used by L<xPL::Listener>.

=cut

sub _gtk2_remove_input {
  my $self = shift;
  my $handle = shift;
  $self->SUPER::remove_input($handle);
  my $id = $self->{_handle_map}->{$handle};
  return unless defined $id;
  return Glib::Source->remove($id);
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
  my $timeout = $self->timer_minimum_timeout()*1000;
  $timeout = 0 if ($timeout < 0);
  $self->{_timeout_handle} =
    Glib::Timeout->add($timeout, \&_gtk2_timeout_callback, $self);
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

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
