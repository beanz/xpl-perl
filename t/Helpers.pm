package t::Helpers;

=head1 NAME

t::Helpers - Perl extension for Helper functions for tests.

=head1 SYNOPSIS

  use Test::More tests => 2;
  use t::Helpers qw/:all/;
  is(test_error(sub { die 'argh' }),
     'argh',
     'died horribly');

  is(test_warn(sub { warn 'danger will robinson' }),
     'danger will robinson',
     'warned nicely');

=head1 DESCRIPTION

Common functions to make test scripts a bit easier to read.  There are
CPAN modules to do this sort of thing, but most people wont have them
installed and they are pretty trivial functions so to encourage
testing they are included here.

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use File::Temp qw/tempfile/;
use Test::More;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use constant {
  DEBUG => $ENV{DEVICE_XPL_TEST_HELPERS_DEBUG}
};

use Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
                                   test_error
                                   test_warn
                                   test_output
                                   wait_for_callback
                                   wait_for_variable
                                   test_server
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

# Preloaded methods go here.

=head2 C<test_error($code_ref)>

This method runs the code with eval and returns the error.  It strips
off some common strings from the end of the message including any "at
<file> line <number>" strings and any "(@INC contains: .*)".

=cut

sub test_error {
  my $sub = shift;
  eval { $sub->() };
  my $error = $EVAL_ERROR;
  if ($error) {
    $error =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $error =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $error =~ s/ \(\@INC contains:.*?\)$//;
  }
  return $error;
}

=head2 C<test_warn($code_ref)>

This method runs the code with eval and returns the warning.  It strips
off any "at <file> line <number>" specific part(s) from the end.

=cut

sub test_warn {
  my $sub = shift;
  my $warn;
  local $SIG{__WARN__} = sub { $warn .= $_[0]; };
  eval { $sub->(); };
  die $EVAL_ERROR if ($EVAL_ERROR);
  if ($warn) {
    $warn =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $warn =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $warn =~ s/ \(\@INC contains:.*?\)$//;
  }
  return $warn;
}

sub test_output {
  my ($sub, $fh) = @_;
  my ($tmpfh, $tmpfile) = tempfile();
  open my $oldfh, ">&", $fh     or die "Can't dup \$fh: $!";
  open $fh, ">&", $tmpfh or die "Can't dup \$tmpfh: $!";
  $sub->();
  open $fh, ">&", $oldfh or die "Can't dup \$oldfh: $!";
  $tmpfh->flush;
  open my $rfh, '<', $tmpfile;
  local $/;
  undef $/;
  my $c = <$rfh>;
  close $rfh;
  unlink $tmpfile;
  $tmpfh->close;
  return $c;
}

sub wait_for_callback {
  my ($xpl, $type, $id, $count) = @_;
  my $method = $type.'_callback_count';
  $count = $xpl->$method($id)+1 unless (defined $count);
  while ($xpl->$method($id) < $count) {
    #print STDERR "Waiting for $type => $id to reach $count\n";
    $xpl->main_loop(1);
  }
}

sub wait_for_variable {
  my ($xpl, $var_ref) = @_;
  my $count = ($$var_ref || 0)+1;
  while (($$var_ref || 0) < $count) {
    #print STDERR "Waiting for read_count to reach $count\n";
    $xpl->main_loop(1);
  }
}

sub test_server {
  my ($cv, @connections) = @_;
  my $server;
  $server = tcp_server '127.0.0.1', undef, sub {
    my ($fh, $host, $port) = @_;
    print STDERR "In server\n" if DEBUG;
    my $handle;
    $handle = AnyEvent::Handle->new(fh => $fh,
                                    on_error => sub {
                                      warn "error $_[2]\n";
                                      $_[0]->destroy;
                                    },
                                    on_eof => sub {
                                      $handle->destroy; # destroy handle
                                      warn "done.\n";
                                    },
                                    timeout => 1,
                                    on_timeout => sub {
                                      die "server timeout\n";
                                    }
                                   );
    my @actions = @{shift @connections || []}; # intentional copy
    unless (@actions) {
      die "Server received unexpected connection\n";
    }
    handle_connection($handle, \@actions);
  }, sub {
    my ($fh, $host, $port) = @_;
    die "tcp_server setup failed: $!\n" unless ($fh);
    $cv->send([$host, $port]);
  };
  return $server;
}

sub handle_connection {
  my ($handle, $actions) = @_;
  print STDERR "In handle connection ", scalar @$actions, "\n" if DEBUG;
  my $rec = shift @$actions;
  unless ($rec) {
    print STDERR "closing connection\n" if DEBUG;
    return $handle->push_shutdown;
  }
  if ($rec->{sleep}) {
    # pause to permit read to happen
    my $w; $w = AnyEvent->timer(after => $rec->{sleep}, cb => sub {
                                  handle_connection($handle, $actions);
                                  undef $w;
                                });
    return;
  }
  my ($desc, $recv, $send) = @{$rec}{qw/desc recv send/};
  $send =~ s/\s+//g if (defined $send);
  unless (defined $recv) {
    print STDERR "Sending: ", $send if DEBUG;
    $send = pack "H*", $send;
    print STDERR "Sending ", length $send, " bytes\n" if DEBUG;
    $handle->push_write($send);
    handle_connection($handle, $actions);
    return;
  }
  $recv =~ s/\s+//g;
  my $expect = $recv;
  print STDERR "Waiting for ", $recv, "\n" if DEBUG;
  my $len = .5*length $recv;
  print STDERR "Waiting for ", $len, " bytes\n" if DEBUG;
  $handle->push_read(chunk => $len,
                     sub {
                       print STDERR "In receive handler\n" if DEBUG;
                       my $got = uc unpack 'H*', $_[1];
                       is($got, $expect,
                          '... correct message received by server - '.$desc);
                       print STDERR "Sending: ", $send, "\n" if DEBUG;
                       $send = pack "H*", $send;
                       print STDERR "Sending ", length $send, " bytes\n"
                         if DEBUG;
                       $handle->push_write($send);
                       handle_connection($handle, $actions);
                       1;
                     });
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

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
