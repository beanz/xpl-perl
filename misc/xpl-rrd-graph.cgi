#!/usr/bin/perl -w

=head1 NAME

xpl-rrd-graph.cgi - Perl CGI script for graphing an xpl-rrd directory.

=head1 SYNOPSIS

  http://localhost/cgi-bin/xpl-rrd-graph.cgi

=head1 DESCRIPTION

This script is produces image files containing graphs of data stored
in RRD database files.

=cut

use strict;
use IO::Handle;
use RRDs;
use POSIX qw/strftime/;
use File::Temp qw/tempfile/;

$| = 1;

my $data_dir = $ENV{'RRD_DIR'} || '/var/lib/rrd';
$data_dir = '/var/lib/zenah/rrd' unless (-d $data_dir);

my @spans = ('1h', '6h', '1d', '7d', '14d', '1mon', '3mon', '6mon', '1y', '2y');

my $path = '';
my $span;
my $var;
my $append = '';
if ($ENV{QUERY_STRING} && $ENV{QUERY_STRING} =~ /^span=(\w+)$/) {
  $span = $1;
  $append = '?'.$ENV{QUERY_STRING};
}
if ($ENV{PATH_INFO}) {
  $path = $ENV{PATH_INFO};

  unless ($path !~ /\.\./ &&
          $path =~ m!^/?([-A-Za-z0-9_/\.]*)?$!) {
    error("Invalid path: $path\n");
  }
  $path = $1;
  $path =~ s!index.cgi$!!;
  if ($path =~ s!\.rrd\K/(\w+)$!!) {
    $var = $1;
  }
}

my $time = time;
my $full_path = $data_dir.($path ? '/'.$path : '');
my $cgi_path = $ENV{SCRIPT_NAME}.($path ? '/'.$path : '');
if (-f $full_path && $path =~ /\.rrd$/) {
  my $rrd = $full_path;
  $span = '6h' unless ($span);
  unless ($var) {
    my $sources = rrd_data_sources($full_path);
    error("Couldn't guess ds from $path\n") unless ($sources);
    $var = $sources->[0];
  }
  my ($fh, $tmpfile) = tempfile();
  my $start = '-'.$span;
  my $end = 'now';
  RRDs::graph($tmpfile,
              "--title" => "Graph $path ($var) for ".span_name($span),
              "--start" => $start, "--end"   => $end,
              "--width" => 600,  "--height" => 200,
              "--imgformat" => "PNG", "--interlaced",
              "DEF:avg=$rrd:$var:AVERAGE", "DEF:min=$rrd:$var:MIN",
              "DEF:max=$rrd:$var:MAX",
              "LINE1:min#0EEFD2:C Min",
              "LINE1:avg#EFD80E:C Avg",
              "LINE1:max#EF500E:C Max",
              "GPRINT:min:MIN:Min %7.2lf",
              "VDEF:gavg=avg,AVERAGE", "GPRINT:gavg:Avg %7.2lf",
              "GPRINT:max:MAX:Max %7.2lf\\l",
              "COMMENT:".strftime('%Y-%m-%d %H\:%m\r',
                                  localtime(time)),
             );
  my $err = RRDs::error;
  if ($err) {
    close $fh;
    unlink $tmpfile;
    error("ERROR creating image for $rrd [: $err\n");
  }
  print "Content-Type: image/png\n\n";
  {
    local $/ = \4096;
    while (<$fh>) {
      print;
    }
  }
  close $fh;
  unlink $tmpfile;
} elsif (-d $full_path) {
  print "Content-Type: text/html\n\n";
  opendir my $dh, $data_dir.'/'.$path or error("Failed to open $path: $!");
  foreach my $f (sort grep !/^\./, readdir $dh) {
    my $fp = $full_path.'/'.$f;
    if (-d $fp) {
      print "<p>$f\n";
      foreach my $s ($span ? $span : @spans) {
        print
          "  [<a href=\"$cgi_path/$f?span=$s\">".span_name($s)."</a>]&nbsp;\n";
      }
      print "</p>\n";
    } elsif (-f $fp && $f =~ /\.rrd$/) {
      my $sources = rrd_data_sources($fp);
      foreach my $var (@$sources) {
        print "<img src=\"$cgi_path/$f/$var$append\" />\n";
      }
    }
  }
  closedir $dh;
} else {
  error("Invalid path: $path <!-- 2 -->\n");
}

sub error {
  print "Content-Type: text/plain\n\n", @_, "\n";
  print STDERR @_, "\n";
  exit;
}

sub rrd_data_sources {
  my $rrd = shift;

  my $hash = RRDs::info $rrd;
  return undef unless ($hash);
  my %ds;
  foreach my $key (keys %$hash){
    $ds{$1}++ if ($key =~ /^ds\[([^]]+)\]/);
  }
  return [keys %ds];
}

sub span_name {
  my %n =
    (
     '14d' => 'a Fortnight',
     '7d' => 'a Week',
     '1h' => 'an Hour',
     'y' => 'Year',
     'mon' => 'Month',
     'd' => 'Day',
     'h' => 'Hour'
    );
  $n{$_[0]}
    || ($_[0] =~ /^1(d|mon|y)$/ && 'a '.$n{$1})
      || ($_[0] =~ /^(\d+)(h|d|mon|y)$/ && $1.' '.$n{$2}.'s')
        || $_[0]
}
