#!/usr/bin/perl
# sansay graphing!
use strict;
use warnings;
no warnings 'uninitialized';
no warnings 'experimental';
use Cwd;
use JSON;
use Data::Dumper;
use XML::Simple;
use LWP::UserAgent;
use InfluxDB::LineProtocol qw(data2line precision=s);
use POSIX 'strftime';

my $debug = 0;

my $endPoint = "http://influxdb.hostname.com:8086/write?db=dbname";

my ($resourcesFile) = @ARGV;

unless (defined $resourcesFile) {
	die "no source file ./greenParse.pl filename.xml";
}

my $grn = parseUsage($resourcesFile);

foreach my $time (keys %{ $grn->{'usage'} }) {
  # influx posting
  my $nanoTime = $time * 10**9;
  my $data = ();
  $data->{'therm'} = sprintf("%.3f", $grn->{'usage'}->{$time});
  my $nodeLine = data2line('natural_gas_usage', $data, $nanoTime);
  my $newTime = strftime '%Y/%m/%d %H:%M:%S', localtime $time;
  print "posting $nanoTime - $newTime | $data->{'therm'}\n";
  postInflux($nodeLine);
}



sub parseUsage {
  my $fileName = shift;
  my $grn = ();
  my $simple = XML::Simple->new( );             # initialize the object
  my $resourceTree = $simple->XMLin( $fileName, forcearray => 1 );   # read, store document
  my $resources = $resourceTree->{ entry };
  my $count = 0;
  foreach my $resource (keys @{ $resources }) {

    my $title = $resources->[$resource]->{'title'}->[0];

    # print "title: $resources->[$resource]->{'title'}->[0] | $resource\n";
    # print Dumper($resources->[$resource]);

    # Energy Delivered
    if ($title eq 'Energy Delivered' && defined $resources->[$resource]->{'content'}->{'ReadingType'}) {
      my $readVars = $resources->[$resource]->{'content'}->{'ReadingType'}->[0];
      $grn->{'powerOfTenMultiplier'}  = $readVars->{'powerOfTenMultiplier'}->[0];
      $grn->{'commodity'}  = $readVars->{'commodity'}->[0];
      $grn->{'accumulationBehaviour'}  = $readVars->{'accumulationBehaviour'}->[0];
      $grn->{'uom'}  = $readVars->{'uom'}->[0];
      # print Dumper($grn);
    }

    # per hour for a specific day
    if ($title eq 'Energy Usage' && defined $resources->[$resource]->{'content'}->{'IntervalBlock'}) {
      my $intBlock = $resources->[$resource]->{'content'}->{'IntervalBlock'}->[0]->{'IntervalReading'};
      foreach my $int (keys @{ $intBlock }) {
        my $value = $intBlock->[$int]->{'value'}->[0];
        my $start = $intBlock->[$int]->{'timePeriod'}->[0]->{'start'}->[0];
        my $duration = $intBlock->[$int]->{'timePeriod'}->[0]->{'duration'}->[0];
        my $finish = $start + $duration;
        # $start = strftime '%Y/%m/%d %H:%M:%S', localtime $start;
        # $finish = strftime '%Y/%m/%d %H:%M:%S', localtime $finish;
        my $newValue = $value*10**$grn->{'powerOfTenMultiplier'};
        # print "$start to $finish | $value = $newValue\n";

        $grn->{'usage'}->{$start} = $newValue;
      }
    }
  }

  return $grn;
}


sub postInflux {
  my $data = shift;
  # setup the useragent
  my $ua = LWP::UserAgent->new;
  # set custom HTTP request header fields
  my $req = HTTP::Request->new(POST => $endPoint);
  $req->content($data);
  my $resp = $ua->request($req);
  my $status = 0;
  if ($resp->is_success) {
    $status = 1;
    if ($debug) {
      my $message = $resp->decoded_content;
      print "Received reply: $message\n";
    }
  } else {
    $status = 0;
    if ($debug) {
      print "HTTP POST error code: ", $resp->code, "\n";
      print "HTTP POST error message: ", $resp->message, "\n";
    }
  }
  return $status;
}
