package xPL::Dock::XOSD;

=head1 NAME

xPL::Dock::XOSD - xPL::Dock plugin for an X OSD C<osd.basic> client.

=head1 SYNOPSIS

  use xPL::Dock qw/XOSD/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds an X OSD C<osd.basic> client.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use X::Osd;

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
  $self->{_max_delay} = 10;
  $self->{_rows} = 4;
  $self->{_font} = '-adobe-courier-bold-r-normal--72-0-0-0-p-0-iso8859-1';
  $self->{_indent} = 0;
  $self->{_offset} = 0;
  return
    (
     'xosd-verbose+' => \$self->{_verbose},
     'xosd-max-delay=i' => \$self->{_max_delay},
     'xosd-rows=i' => \$self->{_rows},
     'xosd-font=s' => \$self->{_font},
     'xosd-indent=i' => \$self->{_indent},
     'xosd-offset=i' => \$self->{_offset},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  my $xosd = $self->{_xosd} = X::Osd->new($self->{_rows});
  $xosd->set_font($self->{_font});
  $xosd->set_horizontal_offset($self->{_indent});
  $xosd->set_vertical_offset($self->{_offset});

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

  my $row = $msg->field('row');
  unless ($row && $row >= 1 && $row <= $self->{_rows}) {
    $row = 1;
  }
  if ((lc $msg->field('command')) eq 'clear') {
    $self->clear_screen();
  }
  unless ($msg->field('text')) {
    return;
  }

  my $delay = $msg->field('delay');
  $delay = $self->{_max_delay} if (!defined $delay ||
                                   $delay > $self->{_max_delay});
  $self->{_xosd}->set_timeout($delay);
  $self->{_xosd}->string($row-1, $msg->field('text'));
  return 1;
}

=head2 C<clear_screen()>

Clear the screen by removing all text from every line of the OSD.

=cut

sub clear_screen {
  my $self = shift;
  $self->{_xosd}->set_timeout(0);
  foreach my $r (0..$self->{_rows}-1) {
    $self->{_xosd}->string($r, q{});
  }
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

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
