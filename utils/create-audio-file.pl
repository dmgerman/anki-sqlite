#!/usr/bin/perl

use Statistics::Basic qw(:all);

my $ANKIDIR = shift;

die "Not an anki directory [$ANKIDIR]" unless -f "$ANKIDIR/collection.anki2";

my @files ;
my @reps;

# how many times each file is played contiguously
my $REPS = 2;


my $AUDIO_IDX =2 ;
my $TYPE_IDX = 8;
my $LASTIVL_IDX= 5;
my $IVL_IDX = 4;
my $MODEL_IDX = 0;
my $TIME_IDX =7;

my $MAX_DAYS = 30;

my $DIVIDER= '0.25-44hz.mp3';


my $i = 0;


{
    # very parms
    my $l = <>;
    chomp $l;
    my @f = split('\t', $l);

    sub Verify_Field {
        my ($idx, $name) = @_;
        die "field [$idx] is not [$name] " unless  $f[$idx] eq $name;
    }

    Verify_Field($MODEL_IDX, 'modelname');
    Verify_Field($AUDIO_IDX, 'audio');
    Verify_Field($TYPE_IDX, 'type');
    Verify_Field($LASTIVL_IDX, 'lastivl');
    Verify_Field($IVL_IDX, 'ivl');
    Verify_Field($TIME_IDX, 'time');
#    die "field 10 is not lapses ($f[10])" unless  $f[10] eq 'lapses';

}

my @keep ;

my %modelCount;
my %modelCountKept;

while (<>) {
    chomp;
    next if $_ =~/^modelname\t/; #in case I concatenate several ones
    my @f = split('\t');
    my $audio = $f[$AUDIO_IDX];
    my $lastivl = $f[$LASTIVL_IDX];
    my $ivl = $f[$IVL_IDX];
    my $type = $f[$TYPE_IDX];
    my $model = $f[$MODEL_IDX];
    my $time = $f[$TIME_IDX];



    die "[$_]" if $model eq 'modelname';
    my $output =
            ($type eq "2") ||
            ($type eq "0") ||
            ($ivl < $MAX_DAYS) ||
            ($time/1000.0 > 30)
            ;

#    print STDERR "$output=>$model;$type:$lastivl;";

    if (not defined($modelCount{$model})) {
        $modelCount{$model}[0] = 0;
        $modelCount{$model}[1] = 0;
    }

    if ($output) {
        # clean field
        $audio =~ s/^\[sound://;
        $audio =~ s/\].*$//;
        push(@keep, $audio);
        $modelCount{$model}[1] ++;
    }
    $i++;
    $modelCount{$model}[0] ++;
}

fisher_yates_shuffle( \@keep ) if scalar (@keep) > 0;

foreach my $f (@keep) {
    for $i (1..$REPS) {
        if (-f $ANKIDIR.  "/collection.media/" . $f) {
            print "file '$DIVIDER'\n";
            print "file '$f'\n";
        } else {
            print STDERR "File does not exist\n";
        }
    }
}

my $toUse = scalar(@keep);

print STDERR "Read $i records. Keep $toUse\n";


foreach my $k (sort keys %modelCount) {
    printf STDERR "%-20s %d %d\n", $k, $modelCount{$k}[0], $modelCount{$k}[1];
}

exit 0;

#print "Median reps ", median(@reps), "\n";

#print join(":", @reps), "\n";
#print "Median lapses ", median(@lapses), "\n";
#print join(":", @lapses), "\n";

# from perlCookbook

sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}
