#!/usr/bin/perl -w
use strict;
use POSIX qw/log10 ceil floor strftime/;
use RRDs;

print "Content-Type: text/html\n\n";

my $data_dir = $ENV{'RRD_DIR'} || '/var/lib/rrd';
$data_dir = '/var/lib/zenah/rrd' unless (-d $data_dir);

my $q = $ENV{QUERY_STRING} || '';
if ($q =~ /\.\./ && $q =~ /[^-A-Za-z0-9\.=_]/) {
  error("Invalid query");
}
my %q;
foreach my $p (split /\&/, $q) {
  my ($k, $v) = split /=/, $p, 2;
  if (exists $q{$k}) {
    push @{$q{$k}}, $v;
  } else {
    $q{$k} = [ $v ];
  }
}
my $verbose = $q{verbose}->[0];
my $rrd = $data_dir.'/'.($q{rrd}->[0] || 's_mains/current.rrd');
my $temp_rrd = $data_dir.'/'.$q{temp}->[0] if (exists $q{temp});
my $num_days = $q{days}->[0] || 14;
my @neg = map { $data_dir.'/'.$_ } @{$q{neg} || []};
my @add = map { $data_dir.'/'.$_ } @{$q{add} || []};

my $six_hours = 3600 * 6;

my $now = time;
my ($sec, $minute, $hour) = localtime $now;
my $hours_so_far = $hour + ($minute + ($sec/60))/60;
my $midnight = $now - ( $sec + ( 60 * ($minute + 60*$hour) ) );

my $hist_kwh = [];
my $min = 0;
my $max = 0;
my $tmin = 0;
my $tmax = 0;
my @t = ();
my @label = ();
foreach my $days (reverse 0..$num_days) {
  my $midnight_minus_days = $midnight - 86400*$days;
  push @label, substr((strftime '%A', localtime $midnight_minus_days), 0, 1);
  my $total = 0;
  my @v = ();
  foreach my $i (0..3) {
    my $offset = $i * $six_hours;
    my $start = $midnight_minus_days + $offset;
    my $end = $start + $six_hours;
    #print scalar localtime $start, " ", scalar localtime $end, "\n";
    my $kwh = get_average_kwh($rrd, $start, $end, $now);
    $kwh -= get_average_kwh($_, $start, $end, $now) foreach (@neg);
    $kwh += get_average_kwh($_, $start, $end, $now) foreach (@add);
    push @{$hist_kwh->[$i]}, $kwh;
    #print "kwh = $kwh\n";
    $total += $kwh;
    push @v, $kwh;
  }
  print scalar localtime $midnight_minus_days,
        " ", (join ' + ', @v), " = $total\n" if ($verbose);
  $min = $total if ($total < $min);
  $max = $total if ($total > $max);

  if ($temp_rrd) {
    my $temp = get_average($temp_rrd, 'temp',
                           $midnight_minus_days, $midnight_minus_days+86400);
    push @t, $temp;
    $tmin = $temp if ($temp < $tmin);
    $tmax = $temp if ($temp > $tmax);
  }
}

my $g = loose_label($min, $max);
my $gt = loose_label($tmin, $tmax) if ($temp_rrd);

print scalar localtime $midnight, " ", scalar localtime $now, "\n"
  if ($verbose);
print $hours_so_far, "\n" if ($verbose);

my $so_far_today = get_average($rrd, 'current', 'midnight', 'now');
my $kwh = $hours_so_far * .240 * $so_far_today;
print "kwh = $kwh\n" if ($verbose);

my @data;
_encode($g->{gmin}, $g->{gmax}, $hist_kwh, \@data);
my $e = $temp_rrd ? 'e'.(scalar @data) : 'e';
_encode($gt->{gmin}, $gt->{gmax}, [\@t], \@data) if ($temp_rrd);

my $chart = 'http://chart.apis.google.com/chart?cht=bvs&chs=600x400&'.
  'chtt=Energy+Usage+(kwh)&'.
  'chco=ff0000,00ff00,0000ff,ffff00,00ffff&'.
  'chxt=x,y'.($temp_rrd ? ',r' : '').'&'.
  'chxl=0:|'.join('|', @label).'|'.
       '1:|'.join('|', map { sprintf $g->{stepfmt}, $_ } @{$g->{ticks}}).
  ($temp_rrd ? '|2:|'.join('|', map { sprintf $gt->{stepfmt}, $_
                                    } @{$gt->{ticks}}) : '').'&'.
  'chds='.$g->{gmin}.','.$g->{gmax}.'&'.
  'chdl=night|morning|afternoon|evening'.($temp_rrd?'|temp':'').'&'.
  'chg=100,'.(100/(@{$g->{ticks}}-1)).'&'.
  'chd='.$e.':'.(join ',', @data);
if ($temp_rrd) {
  $chart .= '&chm=D,00ffff,'.(@data-1).',0,1,1';
}
#  'chd=t:'.(join '|', (map { join ',', @{$hist_kwh->[$_]} } 0..3));
print <<"EOF";
<html>
<head><title>Energy Usage</title></head>
<body>
<img width="600" height="400" src="$chart" />
</body>
</html>
EOF

sub _encode {
  my ($min, $max, $data_sets, $results) = @_;
  my @enc = ('A'..'Z', 'a' .. 'z', '0'..'9', '-', '.');
  my $num_enc = scalar @enc;
  my $scale = ($max-$min)/4095;
  $results = [] unless ($results);
  foreach my $values (@$data_sets) {
    push @$results, join '', map {
      defined $_ ?
        do { my $v = int(($_-$min)/$scale);
        $enc[int($v/$num_enc)].$enc[int($v%$num_enc)]
        }
        : '__'
    } @$values;
  }
  return $results;
}

# Reference: Paul Heckbert, "Nice Numbers for Graph Labels",
#            Graphics Gems, pp 61-63.
#            http://tog.acm.org/GraphicsGems/gems/Label.c
#
# Finds a "nice" number approximately equal to x.
#
# Args:
#       x -- target number
#   round -- If non-zero, round. Otherwise take ceiling of value.

sub nice_number {
  my $x = shift;
  my $round = shift;

  my $e = floor(log10($x));
  my $f = $x / 10**$e;
  my $n = 10;
  if ($round) {
    $n = ($f < 1.5 ? 1.0 : ($f < 3 ? 2 : ($f < 7 ? 5 : 10)));
  } else {
    $n = ($f <= 1 ? 1.0 : ($f <= 2 ? 2 : ($f <= 5 ? 5 : 10)));
  }
  return $n * 10**$e;
}

sub loose_label {
  my ($min, $max, $steps) = @_;
  $steps = 8 if (!defined $steps);
  $steps = 2 if ($steps < 2);

  my $range = nice_number($max - $min);
  my $delta = nice_number($range/($steps - 1), 1);
  my $gmin = $delta * floor($min/$delta);
  my $gmax = $delta * ceil($max/$delta);
  my $nfx = -floor(log10($delta));
  my $nfrac = ($nfx > 0) ? $nfx : 0;
  my $fmt = sprintf("%%.%df", $nfrac);
  my @tick = ();
  for (my $x=$gmin; $x < $gmax + 0.5*$delta; $x+=$delta) {
    push @tick, $x;
  }
  return { gmin => $gmin, gmax => $gmax,
           delta => $delta, stepfmt => $fmt,
           ticks => \@tick };
}

sub get_average_kwh {
  my ($rrd, $start, $end, $now) = @_;
  return ( ($now < $end) ? ($now-$start)/3600 : 6 ) * .240 *
    get_average($rrd, 'current', $start, $end);
}

sub get_average {
  my ($rrd, $type, $start, $end) = @_;
  unless (-r $rrd) {
    warn "File not found: $rrd\n";
    return 0;
  }
  my $avg =
    RRDs::graphv("",
                 '--start' => $start, '--end' => $end,
                 "DEF:a=$rrd:$type:AVERAGE",
                 "VDEF:ga=a,AVERAGE",
                 "PRINT:ga:%7.2lf");
  my $val = $avg->{'print[0]'};
  $val =~ s/^\s+//;
  if ($val eq 'nan') {
    return 0;
  }
  return $val;
}

sub error {
  print "<h1>Error: ", @_, "</h1>\n";
  print STDERR @_, "\n";
  exit;
}
